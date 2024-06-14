local MOD_UUID = "0fd00c41-58c8-4fe2-97cb-dc87a810ad94"
Ext.IMGUI.EnableDemo(true)
local window_size = {493, 225}
local _prev_rcvd_msg = ""

local chat = Ext.IMGUI.NewWindow("Chat Box")
chat.NoTitleBar = true
chat.NoScrollbar = true
chat:SetPos({1415, 375}) -- Needs string as 2nd param
chat:SetBgAlpha(0.2)
chat:SetStyle("Alpha", 0.2)
chat.NoFocusOnAppearing = true
--chat:SetSize(window_size) -- Needs string as 2nd param
--chat.NoInputs = true
--chat.NoBackground = true
--chat.AlwaysAutoResize = true

local text_parent = chat:AddChildWindow("Text Holder")
text_parent.NoTitleBar = true
text_parent.Size = {window_size[1] - 10, window_size[2] - 30}
--text_parent.NoInputs = true
--text_parent.NoBringToFrontOnFocus = true
text_parent.NoBackground = true
text_parent.NoDecoration = true

local text = text_parent:AddText(_prev_rcvd_msg)
text.SameLine = false
text:SetStyle("Alpha", 1)

local text_input = chat:AddInputText("")
text_input.AllowTabInput = true
text_input.EscapeClearsAll = true
text_input.ItemWidth = window_size[1] - 10
text_input:SetStyle("Alpha", 0.7)
text_input.OnDeactivate = function() TC_SendMessage(text_input.Text) text_input.Text = "" chat:SetStyle("Alpha", 0.2) end
text_input.OnActivate = function() chat:SetStyle("Alpha", 0.9) end

function TC_UpdateChat(new_message) text.Label = text.Label .. '\n' .. new_message end

-- TODO:
--     - Button to collapse and open chat window
--     - Settings button which will enable moving and manually entering the dimenstions
--       to store as mod variables or something. Persistent to save dimensions?
--     - Make text scroll always to the bottom upon new text message
--     - Make text messages wrap based on width
--     - Somehow hide chat completely when not in gameplay?
--     - Change alpha settings to auto-adjust based on focus?
--     - MAYBE configure text size to user's configured text size in the settings?
