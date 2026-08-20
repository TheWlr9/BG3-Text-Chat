CHANNEL = "Text-Chat"
local MSG_RECEIVED_EVENT = "TC_MessageReceived"

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
    _broadcast({ t = "system", body = "~ " .. tostring(userName) .. " joined the chat ~" })
end

local function on_user_disconnected(userID, userName, userSomethingElse)
    connected_users[userID - 1] = nil
    _broadcast({ t = "system", body = "~ " .. tostring(userName) .. " left the chat ~" })
end

local function _apply_overhead_text(character, body)
    if not character then return end
    _broadcast({ t = "oht", body = tostring(body) })
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
    end
end

local function _entity_event_handler(object, event)
    if event == MSG_RECEIVED_EVENT and IsCharacter(object) ~= 0 then
        PlayHUDSound(object, "UI_HUD_SplitItem_Cancel_Press")
    end
end

Ext.Osiris.RegisterListener("EntityEvent", 2, "after", _entity_event_handler)
Ext.Osiris.RegisterListener("UserConnected", 3, "after", on_user_connected)
Ext.Osiris.RegisterListener("UserDisconnected", 3, "after", on_user_disconnected)
Ext.Events.NetMessage:Subscribe(received_message)
