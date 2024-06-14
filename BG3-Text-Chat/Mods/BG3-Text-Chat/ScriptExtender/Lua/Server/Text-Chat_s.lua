local MOD_UUID = "0fd00c41-58c8-4fe2-97cb-dc87a810ad94"
local CHANNEL = "Text-Chat"

local function on_user_connected(userID, userName, userSomethingElse)
    Ext.Net.BroadcastMessage(CHANNEL, userName .. " has connected!")
    _P("USER CONNECTED")
    _P(userID .. " " .. userName .. " " .. userSomethingElse)
end

local function received_message(event)
    if event.Channel == CHANNEL then
        _D(event.UserID)
        _D(event.Payload)
        local display_name = Ext.Entity.Get(Osi.GetCurrentCharacter(event.UserID + 1)).ServerDisplayNameList.Names[1].Name ~= "" and Ext.Entity.Get(Osi.GetCurrentCharacter(event.UserID + 1)).ServerDisplayNameList.Names[1].Name or Ext.Entity.Get(Osi.GetCurrentCharacter(event.UserID + 1)).ServerDisplayNameList.Names[2].Name
        local formatted_msg = "<" .. display_name .. ">: " .. event.Payload
        Ext.Net.BroadcastMessage(CHANNEL, formatted_msg)
    end
end

Ext.Osiris.RegisterListener("UserConnected", 3, "after", on_user_connected)
Ext.Events.NetMessage:Subscribe(received_message)