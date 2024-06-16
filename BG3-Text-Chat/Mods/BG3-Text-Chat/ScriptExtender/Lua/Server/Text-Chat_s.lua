local CHANNEL = "Text-Chat"
local MSG_RECEIVED_EVENT = "TC_MessageReceived"

local function on_user_connected(userID, userName, userSomethingElse)
    Ext.Net.BroadcastMessage(CHANNEL, "~ " .. userName .. " has connected ~")
end

local function on_user_disconnected(userID, userName, userSomethingElse)
    Ext.Net.BroadcastMessage(CHANNEL, "~ " .. userName .. " has disconnected ~")
end

local function received_message(event)
    if event.Channel == CHANNEL then
        local display_name = (Ext.Entity.Get(Osi.GetCurrentCharacter(event.UserID + 1)).ServerDisplayNameList.Names[1].Name ~= "" and Ext.Entity.Get(Osi.GetCurrentCharacter(event.UserID + 1)).ServerDisplayNameList.Names[1].Name) or (#Ext.Entity.Get(Osi.GetCurrentCharacter(event.UserID + 1)).ServerDisplayNameList.Names >= 2 and Ext.Entity.Get(Osi.GetCurrentCharacter(event.UserID + 1)).ServerDisplayNameList.Names[2].Name) or GetUserName(event.UserID + 1)
        local formatted_msg = "<" .. display_name .. ">: " .. event.Payload
        Ext.Net.BroadcastMessage(CHANNEL, formatted_msg)

        IteratePlayerCharacters(MSG_RECEIVED_EVENT, "")
    end
end

local function _entity_event_handler(object, event)
    if event == MSG_RECEIVED_EVENT and IsCharacter(object) ~= 0 then PlayHUDSound(object, "UI_HUD_SplitItem_Cancel_Press") end
end

Ext.Osiris.RegisterListener("EntityEvent", 2, "after", _entity_event_handler)
Ext.Osiris.RegisterListener("UserConnected", 3, "after", on_user_connected)
Ext.Osiris.RegisterListener("UserDisconnected", 3, "after", on_user_disconnected)
Ext.Events.NetMessage:Subscribe(received_message)