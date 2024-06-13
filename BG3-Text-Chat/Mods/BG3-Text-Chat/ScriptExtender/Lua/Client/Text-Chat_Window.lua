local MOD_UUID = "0fd00c41-58c8-4fe2-97cb-dc87a810ad94"
Ext.IMGUI.EnableDemo(true)
local window_size = {493, 225}

local chat = Ext.IMGUI.NewWindow("Chat Box")
chat.NoTitleBar = true
chat.NoScrollbar = true
chat:SetPos({1415, 375}) -- Needs string as 2nd param
chat:SetSize(window_size) -- Needs string as 2nd param

local text_parent = chat:AddChildWindow("Text Holder")
text_parent.Size = {window_size[1] - 10, window_size[2] - 35}
local text = text_parent:AddText("Text\nYo\nYo\nYo\nYo\nYo\nYo\nYo\nYo\nYo\nYo\nYo\nYo")

local text_input = chat:AddInputText("")
text_input.AllowTabInput = true
text_input.EscapeClearsAll = true
text_input.ItemWidth = window_size[1] - 10
text_input.OnChange = function() Ext.Vars.GetModVariables(MOD_UUID).LocalMessageBuffer = text_input.Text end