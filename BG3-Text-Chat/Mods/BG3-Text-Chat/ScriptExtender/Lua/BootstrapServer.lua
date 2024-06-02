local MOD_UUID = "0fd00c41-58c8-4fe2-97cb-dc87a810ad94"

Ext.Vars.RegisterModVariable(MOD_UUID, "MessageBuffer", {
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

Ext.Require("Server/Text-Chat_s.lua")