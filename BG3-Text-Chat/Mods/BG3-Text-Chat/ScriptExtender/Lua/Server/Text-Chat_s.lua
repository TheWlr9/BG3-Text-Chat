CHANNEL = "Text-Chat"
local MSG_RECEIVED_EVENT = "TC_MessageReceived"

local CFG = Ext.Require("Shared/Text-Chat_Config.lua")

local connected_users = {}

local last_message_by_user = {}

local next_message_id = 1
local function _next_id()
    local id = next_message_id
    next_message_id = next_message_id + 1
    return id
end

local function _post(tbl)
    local ok, encoded = pcall(function() return Ext.Json.Stringify(tbl) end)
    if not ok or not encoded then return nil end
    return encoded
end

local function _broadcast(tbl)
    local encoded = _post(tbl)
    if encoded then Ext.Net.BroadcastMessage(CHANNEL, encoded) end
end

local function _unicast(userID, tbl)
    local encoded = _post(tbl)
    if encoded then Ext.Net.PostMessageToUser(userID, CHANNEL, encoded) end
end

local function _broadcast_except(senderUserID, tbl)
    local encoded = _post(tbl)
    if not encoded then return end
    for uid, _ in pairs(connected_users) do
        if uid ~= senderUserID then
            Ext.Net.PostMessageToUser(uid, CHANNEL, encoded)
        end
    end
end

local function resolve_display_name_and_character(userID)
    local talking_character
    local ok = pcall(function() talking_character = Osi.GetCurrentCharacter(userID + 1) end)
    if not ok or not talking_character then
        return GetUserName(userID + 1), nil
    end

    local display_name = nil
    local ok2 = pcall(function()
        local entity = Ext.Entity.Get(talking_character)
        local names = entity and entity.ServerDisplayNameList and entity.ServerDisplayNameList.Names

        if names and #names >= 2 and names[2].Name then
            display_name = names[2].Name
        elseif names and #names >= 1 and names[1].NameKey then
            local translated = Ext.Loca.GetTranslatedString(names[1].NameKey.Handle.Handle)
            if translated ~= "" and translated ~= "Player" and translated ~= "Dummy" then
                display_name = translated
            end
        end
    end)

    if not ok2 or not display_name or display_name == "" then
        display_name = GetUserName(userID + 1)
    end

    return display_name, talking_character
end

local function on_user_connected(userID, userName, userSomethingElse)
    connected_users[userID - 1] = true

    _broadcast({ t = "system", key = "chat.joined", name = tostring(userName) })
end

local function on_user_disconnected(userID, userName, userSomethingElse)
    connected_users[userID - 1] = nil
    _broadcast({ t = "system", key = "chat.left", name = tostring(userName) })
end

local function _apply_overhead_text(character, body, roll)
    if not character then return end
    _broadcast({ t = "oht", body = tostring(body or ""), roll = roll })
    Ext.Timer.WaitForRealtime(200, function()
        local ok = pcall(function() Osi.ApplyStatus(character, "TEXT_MESSAGE", 0) end)
    end)
end

local function _handle_new_message(event, data)
    local body = data.body
    if type(body) ~= "string" or body == "" then return end

    local display_name, character = resolve_display_name_and_character(event.UserID)
    local id = _next_id()

    _broadcast({ t = "msg", id = id, name = display_name, body = body })
    _unicast(event.UserID, { t = "ack", id = id, body = body })

    last_message_by_user[event.UserID] = { id = id, body = body, name = display_name }

    _apply_overhead_text(character, body)

    IteratePlayerCharacters(MSG_RECEIVED_EVENT, "")
end

local function _handle_edit_message(event, data)
    local id = tonumber(data.id)
    local body = data.body
    if not id or type(body) ~= "string" or body == "" then return end

    local last = last_message_by_user[event.UserID]

    if not last or last.id ~= id then return end

    last.body = body
    _broadcast({ t = "edit", id = id, body = body })
end

local function _handle_typing(event, data)
    local display_name = resolve_display_name_and_character(event.UserID)
    _broadcast_except(event.UserID, { t = "typing", name = display_name, on = data.on and true or false })
end

local ROLL_EVENT_PREFIX = "TC_DiceRoll_"
local pending_rolls = {}
local next_roll_id = 1

local function _handle_roll(event, data)
    local display_name, character = resolve_display_name_and_character(event.UserID)
    if not character then return end

    local def
    if data.kind == "skill" then
        def = CFG.DiceSkillById[data.id]
    elseif data.kind == "ability" then
        def = CFG.DiceAbilityById[data.id]
    end
    local tier = CFG.DiceTierById[data.tier]
    local roll_type = CFG.DiceRollTypeSet[data.rollType] and data.rollType or "active"
    if not def or not tier then return end

    if not tier.guid then CFG.ResolveDiceDifficultyClasses() end
    if not tier.guid then
        Ext.Utils.PrintWarning("[Text-Chat] Dice: no DifficultyClass available for DC " .. tostring(tier.dc))
        _unicast(event.UserID, { t = "system", key = "dice.noDifficultyClass" })
        return
    end

    local event_name = ROLL_EVENT_PREFIX .. tostring(next_roll_id)
    next_roll_id = next_roll_id + 1

    local advantage = data.adv and 1 or 0
    local osi_roll_type = (data.kind == "skill") and "SkillCheck" or "RawAbility"

    pending_rolls[event_name] = {
        name = display_name,
        character = character,
        kind = data.kind,
        id = def.id,
        dc = tier.dc,
        adv = advantage == 1,
        active = roll_type == "active",
        hidden = data.hidden == true,
    }

    local ok, err = pcall(function()
        if roll_type == "active" then
            Osi.RequestActiveRoll(character, character, osi_roll_type, def.id, tier.guid, advantage, event_name)
        else
            Osi.RequestPassiveRoll(character, character, osi_roll_type, def.id, tier.guid, advantage, event_name)
        end
    end)
    if not ok then
        pending_rolls[event_name] = nil
        Ext.Utils.PrintWarning("[Text-Chat] Dice: roll request failed: " .. tostring(err))
        return
    end

    Ext.Timer.WaitForRealtime(CFG.DicePendingRollTimeoutMs, function()
        pending_rolls[event_name] = nil
    end)
end

local function _on_roll_result(event_name, roller, roll_subject, result_type, is_active_roll, criticality)
    local p = pending_rolls[event_name]
    if not p then return end
    pending_rolls[event_name] = nil

    if p.hidden then return end

    local msg = {
        t = "roll",
        name = p.name,
        kind = p.kind,
        id = p.id,
        dc = p.dc,
        adv = p.adv,
        active = p.active,
        result = tonumber(result_type) or 0,
        crit = tonumber(criticality) or 0,
    }
    _broadcast(msg)

    if p.active and msg.result ~= 2 then
        _apply_overhead_text(p.character, nil, msg)
    end
end

local function _handle_who(event)
    local display_name, character = resolve_display_name_and_character(event.UserID)
    _unicast(event.UserID, { t = "who", name = character and display_name or "" })
end

local function received_message(event)
    if event.Channel ~= CHANNEL then return end

    local ok, data = pcall(function() return Ext.Json.Parse(event.Payload) end)
    if not ok or type(data) ~= "table" then return end

    connected_users[event.UserID] = true

    if data.t == "msg" then
        _handle_new_message(event, data)
    elseif data.t == "edit" then
        _handle_edit_message(event, data)
    elseif data.t == "typing" then
        _handle_typing(event, data)
    elseif data.t == "roll" then
        _handle_roll(event, data)
    elseif data.t == "who" then
        _handle_who(event)
    end
end

local function _entity_event_handler(object, event)
    if event == MSG_RECEIVED_EVENT and IsCharacter(object) ~= 0 then
        PlayHUDSound(object, "UI_HUD_SplitItem_Cancel_Press")
    end
end

Ext.RegisterConsoleCommand("textchat_dice_dump", function()
    CFG.ResolveDiceDifficultyClasses()
    Ext.Utils.Print("[Text-Chat] Dice DC tiers:")
    for _, tier in ipairs(CFG.DiceDifficultyTiers) do
        local values = "-"
        pcall(function()
            local res = Ext.StaticData.Get(tier.guid, "DifficultyClass")
            local list = {}
            for _, v in ipairs(res.Difficulties) do table.insert(list, tostring(v)) end
            values = table.concat(list, ",") .. " (" .. tostring(res.Name) .. ")"
        end)
        Ext.Utils.Print(string.format("  %-16s DC %-2d %s %s", tier.id, tier.dc, tostring(tier.guid), values))
    end
end)

Ext.Events.SessionLoaded:Subscribe(function() CFG.ResolveDiceDifficultyClasses() end)

Ext.Osiris.RegisterListener("RollResult", 6, "after", _on_roll_result)
Ext.Osiris.RegisterListener("EntityEvent", 2, "after", _entity_event_handler)
Ext.Osiris.RegisterListener("UserConnected", 3, "after", on_user_connected)
Ext.Osiris.RegisterListener("UserDisconnected", 3, "after", on_user_disconnected)
Ext.Events.NetMessage:Subscribe(received_message)
