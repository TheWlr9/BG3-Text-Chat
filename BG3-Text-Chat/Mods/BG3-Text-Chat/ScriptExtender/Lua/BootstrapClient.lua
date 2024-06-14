local MOD_UUID = "0fd00c41-58c8-4fe2-97cb-dc87a810ad94"

Ext.Vars.RegisterModVariable(MOD_UUID, "InBuf", {
    Server = false,
    Client = true,
    WriteableOnServer = false,
    WriteableOnClient = true,
    Persistent = false,
    SyncToClient = false,
    SyncToServer = false,
})
Ext.Vars.RegisterModVariable(MOD_UUID, "OutBuf", {
    Server = false,
    Client = true,
    WriteableOnServer = false,
    WriteableOnClient = true,
    Persistent = false,
    SyncToClient = false,
    SyncToServer = false
})

Ext.Require("Client/Text-Chat_c.lua")
Ext.Require("Client/Text-Chat_Window.lua")