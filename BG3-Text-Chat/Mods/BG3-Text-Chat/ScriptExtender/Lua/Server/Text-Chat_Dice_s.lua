local Data = Ext.Require("Shared/Text-Chat_Dice_Data.lua")

TC_Dice = {}

pcall(function() math.randomseed(Ext.Utils.MonotonicTime()) end)
local function _d20()
    return math.random(1, 20)
end

local function _bare_guid(guid)
    return string.sub(guid, -36)
end

local function _detect_offset(stats)
    for _, off in ipairs({ 1, 0 }) do
        local consistent = true
        for _, a in ipairs(Data.Abilities) do
            local score = stats.Abilities[a.enum + off]
            local mod = stats.AbilityModifiers[a.enum + off]
            if type(score) ~= "number" or type(mod) ~= "number" or mod ~= math.floor((score - 10) / 2) then
                consistent = false
                break
            end
        end
        if consistent then return off end
    end
    return 1, false
end

local function _get_bonus(character, kind, def)
    local ok, result = pcall(function()
        local stats = Ext.Entity.Get(_bare_guid(character)).Stats
        local off, verified = _detect_offset(stats)
        if verified == false then
            Ext.Utils.PrintWarning("[Text-Chat] Dice: stats index offset could not be verified, assuming 1-based.")
        end

        local value
        if kind == "skill" then
            value = stats.Skills[def.enum + off]
        else
            value = stats.AbilityModifiers[def.enum + off]
        end
        if type(value) ~= "number" then
            error("non numeric value for " .. def.id)
        end
        return value
    end)
    if ok then return result end
    return nil, tostring(result)
end

function TC_Dice.Roll(character, req)
    if type(req) ~= "table" or type(character) ~= "string" or character == "" then return nil end

    local def
    if req.kind == "skill" then
        def = Data.SkillById[req.id]
    elseif req.kind == "ability" then
        def = Data.AbilityById[req.id]
    end
    if not def or not Data.ModeSet[req.mode] then return nil end

    local dc = tonumber(req.dc)
    if dc and (dc < 1 or dc > 40) then dc = nil end

    local bonus, err = _get_bonus(character, req.kind, def)
    if not bonus then
        Ext.Utils.PrintWarning("[Text-Chat] Dice: could not read the bonus: " .. tostring(err))
    end

    local dice = { _d20() }
    local kept = dice[1]
    if req.mode == "adv" or req.mode == "dis" then
        table.insert(dice, _d20())
        kept = (req.mode == "adv") and math.max(dice[1], dice[2]) or math.min(dice[1], dice[2])
    end

    return {
        kind = req.kind,
        id = req.id,
        mode = req.mode,
        dice = dice,
        kept = kept,
        bonus = bonus or 0,
        bad = (bonus == nil),
        dc = dc,
    }
end

Ext.RegisterConsoleCommand("textchat_dice_dump", function()
    local character = Osi.GetHostCharacter()
    Ext.Utils.Print("[Text-Chat] Dice dump for " .. tostring(character))
    for _, a in ipairs(Data.Abilities) do
        Ext.Utils.Print(string.format("  %-15s %s", a.id, tostring((_get_bonus(character, "ability", a)))))
    end
    for _, s in ipairs(Data.Skills) do
        Ext.Utils.Print(string.format("  %-15s %s", s.id, tostring((_get_bonus(character, "skill", s)))))
    end
end)
