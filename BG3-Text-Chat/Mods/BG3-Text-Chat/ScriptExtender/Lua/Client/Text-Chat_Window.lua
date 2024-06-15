local ACTIVE_ALPHA = 0.9
local INACTIVE_ALPHA = 0.5
Ext.IMGUI.EnableDemo(true)

local chat_size = {493, 225}
local chat_position = {1415, 375}

function TC_LenStringDisplay(str)
    local count = 0

    for character in str:gmatch('.') do count = count + (character == '\t' and 4 or 1) end
    return count
end

local text_parent = Ext.IMGUI.NewWindow("Text Holder")
text_parent.NoTitleBar = true
text_parent:SetPos(chat_position) -- Needs string as 2nd param
text_parent:SetSize(chat_size) -- Needs string as 2nd param
--text_parent:SetBgAlpha(INACTIVE_ALPHA)
text_parent:SetStyle("Alpha", INACTIVE_ALPHA)
text_parent.NoFocusOnAppearing = true
text_parent.NoNav = true
--text_parent.NoBringToFrontOnFocus = true
text_parent.NoMove = true
text_parent.NoResize = true
text_parent.NoInputs = true
--text_parent.NoBackground = true
--text_parent.AlwaysAutoResize = true

local text = text_parent:AddText("~ Welcome to the chat ~")
text:SetStyle("Alpha", 1)

local input_parent = Ext.IMGUI.NewWindow("Input Holder")
input_parent.NoTitleBar = true
input_parent:SetPos({chat_position[1], chat_position[2] + chat_size[2]})
input_parent:SetSize({chat_size[1], 35})
input_parent:SetStyle("Alpha", INACTIVE_ALPHA)
input_parent.NoMove = true
--input_parent.NoScrollbar = false
input_parent.NoResize = true

local input = input_parent:AddInputText("")
--input.NoHorizontalScroll = true
input.AllowTabInput = true
input.EscapeClearsAll = true
input.ItemWidth = chat_size[1] - 10
input.OnDeactivate = function()
    TC_SendMessage(input.Text)
    input.Text = ""

    text_parent:SetStyle("Alpha", INACTIVE_ALPHA)
    text_parent.NoInputs = true

    input_parent:SetStyle("Alpha", INACTIVE_ALPHA)
end
input.OnActivate = function()
    text_parent:SetStyle("Alpha", ACTIVE_ALPHA)
    text_parent.NoInputs = false

    input_parent:SetStyle("Alpha", ACTIVE_ALPHA)
end

function TC_UpdateChat(new_message)
    text.Label = text.Label .. '\n' .. new_message
    -- Needs to wait for 1 frame to properly get the updated content size
    Ext.Timer.WaitFor(1, function() text_parent:SetScroll({0.0, 2000.0}) end)
end

-- TODO:
--     - Settings button which will enable moving and manually entering the dimenstions
--       to store as mod variables or something. Persistent to save dimensions?
--     - Somehow hide text_parent completely when not in gameplay?
--     - Play sound effect upon new message?
--     - MAYBE configure text size to user's configured text size in the settings?
