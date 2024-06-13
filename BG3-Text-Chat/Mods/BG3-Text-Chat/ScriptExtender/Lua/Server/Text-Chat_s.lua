local MOD_UUID = "0fd00c41-58c8-4fe2-97cb-dc87a810ad94"
local CHANNEL = "Text-Chat"
local HANDSHAKE = "{'Command':'Handshake'}"

local function on_user_connected(userID, userName, _)
    Ext.Net.PostMessageToUser(userID, CHANNEL, HANDSHAKE)
    Ext.Vars.GetModVariables(MOD_UUID).ChatLog = userName .. " has connected!\n"
end

Ext.Osiris.RegisterListener("UserConnected", 3, "after", on_user_connected)