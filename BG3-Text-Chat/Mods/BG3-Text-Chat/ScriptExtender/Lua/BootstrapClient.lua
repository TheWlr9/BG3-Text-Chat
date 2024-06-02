local MOD_UUID = "0fd00c41-58c8-4fe2-97cb-dc87a810ad94"

Ext.IO.AddPathOverride("Public/Game/GUI/Widgets/CombatLog.xaml", "Public/BG3-Text-Chat/GUI/Widgets/CombatLog.xaml")

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

Ext.Require("Client/Text-Chat_c.lua")