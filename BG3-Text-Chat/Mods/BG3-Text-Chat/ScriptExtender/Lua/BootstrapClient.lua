local MOD_UUID = "0fd00c41-58c8-4fe2-97cb-dc87a810ad94"

Ext.Vars.RegisterModVariable(MOD_UUID, "ChatLog", {
    Server = true,
    Client = true,
    WriteableOnServer = true,
    WriteableOnClient = true,
    Persistent = false,
    SyncToClient = true,
    SyncToServer = true,
    SyncOnTick = true,
    SyncOnWrite = false
})
Ext.Vars.RegisterModVariable(MOD_UUID, "LocalMessageBuffer", {
    Server = false,
    Client = true,
    WriteableOnServer = false,
    WriteableOnClient = true,
    Persistent = false,
    SyncToClient = false,
    SyncToServer = false
})

local TC_Logic = Ext.Require("Client/Text-Chat_c.lua")
local TC_GUI = Ext.Require("Client/Text-Chat_Window.lua")