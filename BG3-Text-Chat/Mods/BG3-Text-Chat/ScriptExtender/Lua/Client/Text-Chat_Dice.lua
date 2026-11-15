local Lang = Ext.Require("Shared/Text-Chat_Lang.lua")
local Data = Ext.Require("Shared/Text-Chat_Dice_Data.lua")
local T = Lang.T

local M = {}

local WHO_POLL_MS = 1000

local UTF8_CHAR = "[\1-\127\194-\244][\128-\191]*"

local ACCENT_FOLD = {}
for base, accented in pairs({
    a = "àáâãäåā", c = "çćč", e = "èéêëēėę", i = "ìíîïī", n = "ñń", o = "òóôõöøō",
    u = "ùúûüū", y = "ýÿ", s = "śš", z = "źżž", l = "ł",
}) do
    for ch in accented:gmatch(UTF8_CHAR) do
        ACCENT_FOLD[ch] = base
    end
end

local function _sort_key(text)
    return (text:lower():gsub(UTF8_CHAR, function(ch) return ACCENT_FOLD[ch] or ch end))
end

function M.Build(ctx)
    local api = {}
    local panel = ctx.panel

    local character_name = ""
    local last_who_ms = -999999

    local function _character_label()
        return T("dice.character", character_name ~= "" and character_name or "-")
    end

    local character_text = ctx.add_text(panel, _character_label)

    ctx.add_text(panel, "dice.mode")
    local mode_combo = panel:AddCombo("##dice_mode")
    mode_combo.SelectedIndex = 0
    ctx.full_width(mode_combo)

    ctx.add_text(panel, "dice.dc")
    local dc_slider = panel:AddSliderInt("##dice_dc", 0, 0, 30)
    ctx.full_width(dc_slider)

    ctx.add_separator_text(panel, "dice.abilities")
    local ability_combo = panel:AddCombo("##dice_ability")
    ability_combo.SelectedIndex = 0
    ctx.full_width(ability_combo)
    local ability_button = panel:AddButton(T("dice.rollAbility"))
    ctx.bind(ability_button, "dice.rollAbility")
    ctx.full_width(ability_button, true)

    ctx.add_separator_text(panel, "dice.skills")
    local skill_combo = panel:AddCombo("##dice_skill")
    skill_combo.SelectedIndex = 0
    ctx.full_width(skill_combo)
    local skill_button = panel:AddButton(T("dice.rollSkill"))
    ctx.bind(skill_button, "dice.rollSkill")
    ctx.full_width(skill_button, true)

    local skill_order = {}

    local function _fill_lists()
        local mode_keys = { normal = "dice.modeNormal", adv = "dice.modeAdv", dis = "dice.modeDis" }
        local mode_options = {}
        for _, m in ipairs(Data.Modes) do table.insert(mode_options, T(mode_keys[m])) end
        mode_combo.Options = mode_options

        local ability_options = {}
        for _, a in ipairs(Data.Abilities) do table.insert(ability_options, T("ability." .. a.id)) end
        ability_combo.Options = ability_options

        local selected = skill_order[skill_combo.SelectedIndex + 1]
        local selected_id = selected and selected.id or nil

        skill_order = {}
        for _, s in ipairs(Data.Skills) do table.insert(skill_order, s) end
        table.sort(skill_order, function(a, b) return _sort_key(T("skill." .. a.id)) < _sort_key(T("skill." .. b.id)) end)
        local skill_options, new_index = {}, 0
        for i, s in ipairs(skill_order) do
            table.insert(skill_options, T("skill." .. s.id))
            if s.id == selected_id then new_index = i - 1 end
        end
        skill_combo.Options = skill_options
        skill_combo.SelectedIndex = new_index
    end
    _fill_lists()

    local function _send_roll(kind, def)
        if not def then return end
        ctx.touch()
        local dc = dc_slider.Value[1]
        TC_SendRoll(kind, def.id, Data.Modes[mode_combo.SelectedIndex + 1], (dc and dc > 0) and dc or nil)
    end

    ability_button.OnClick = ctx.wrap(function()
        _send_roll("ability", Data.Abilities[ability_combo.SelectedIndex + 1])
    end)

    skill_button.OnClick = ctx.wrap(function()
        _send_roll("skill", skill_order[skill_combo.SelectedIndex + 1])
    end)

    mode_combo.OnChange = ctx.touch
    ability_combo.OnChange = ctx.touch
    skill_combo.OnChange = ctx.touch
    dc_slider.OnChange = ctx.touch

    function api.set_character(name)
        character_name = (type(name) == "string") and name or ""
        character_text.Label = _character_label()
    end

    function api.tick(now_ms, visible)
        if visible and (now_ms - last_who_ms) >= WHO_POLL_MS then
            last_who_ms = now_ms
            TC_SendWho()
        end
    end

    function api.refresh_now()
        last_who_ms = -999999
    end

    function api.relanguage()
        _fill_lists()
        character_text.Label = _character_label()
    end

    function api.format_roll(r)
        if type(r) ~= "table" then return "" end

        local title
        if r.kind == "ability" then
            title = T("check." .. tostring(r.id))
        else
            title = T("skill." .. tostring(r.id))
        end
        if r.mode == "adv" then
            title = title .. " " .. T("dice.advantage")
        elseif r.mode == "dis" then
            title = title .. " " .. T("dice.disadvantage")
        end

        local detail = ""
        if type(r.dice) == "table" and #r.dice > 1 then
            detail = "[" .. table.concat(r.dice, ", ") .. "] -> "
        end

        local kept = math.floor(tonumber(r.kept) or 0)
        local bonus = math.floor(tonumber(r.bonus) or 0)
        local total = kept + bonus
        local sign = (bonus >= 0) and "+" or "-"

        local line = string.format("~ %s - %s : %s%d %s %d = %d",
            tostring(r.name), title, detail, kept, sign, math.abs(bonus), total)

        if kept == 20 then
            line = line .. " - " .. T("dice.nat20")
        elseif kept == 1 then
            line = line .. " - " .. T("dice.nat1")
        end

        local dc = tonumber(r.dc)
        if dc then
            line = line .. " - " .. T("dice.dcResult", math.floor(dc), T(total >= dc and "dice.success" or "dice.failure"))
        end
        if r.bad then
            line = line .. " " .. T("dice.noBonus")
        end
        return line .. " ~"
    end

    function api.format_overhead(r)
        if type(r) ~= "table" then return "" end

        local label = T((r.kind == "ability" and "ability." or "skill.") .. tostring(r.id))
        local kept = math.floor(tonumber(r.kept) or 0)
        local total = kept + math.floor(tonumber(r.bonus) or 0)

        local dc = tonumber(r.dc)
        local result
        if dc then
            result = T(total >= dc and "dice.success" or "dice.failure")
        else
            result = tostring(total)
        end
        if kept == 20 or kept == 1 then
            result = result .. " " .. T("dice.critical")
        end
        return T("dice.overhead", label, result)
    end

    return api
end

return M
