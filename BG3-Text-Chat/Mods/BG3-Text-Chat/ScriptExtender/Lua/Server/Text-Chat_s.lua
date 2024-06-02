local MOD_UUID = "0fd00c41-58c8-4fe2-97cb-dc87a810ad94"

local function on_user_connected(_, userName, _) Ext.Vars.GetModVariables(MOD_UUID).MessageBuffer = userName .. " has connected!\n" end

Ext.Osiris.RegisterListener("UserConnected", 3, "after", on_user_connected)