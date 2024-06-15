PersistentVars = {}

local ACTIVE_ALPHA = 0.9
local INACTIVE_ALPHA = 0.5
local INPUT_HEIGHT = 35 -- px
local DEFAULT_SETTINGS_TEXT = "Click and drag me to move me around!\nTo resize me, click and drag on any of my edges!\nClick the \"Save\" when done!"
Ext.IMGUI.EnableDemo(true) -- Remove before release

local chat_size = {493, 225}
local chat_position = {1415, 375}
local settings_visible = false

-- Vars for window repositioning and resizing
local EDGE_SIZE = 2 -- px

local is_moving = false
local is_left_resizing = false
local is_top_resizing = false
local is_right_resizing = false
local is_bottom_resizing = false

local pressed_coords

function TC_LenStringDisplay(str)
    local count = 0

    for character in str:gmatch('.') do count = count + (character == '\t' and 4 or 1) end
    return count
end

local text_parent = Ext.IMGUI.NewWindow("Text Holder")
text_parent.NoTitleBar = true
text_parent:SetPos(chat_position)
text_parent:SetSize(chat_size)
text_parent:SetStyle("Alpha", INACTIVE_ALPHA)
text_parent.NoFocusOnAppearing = true
text_parent.NoNav = true
text_parent.NoMove = true
text_parent.NoResize = true
text_parent.NoInputs = true
text_parent.Visible = false

local text = text_parent:AddText("~ Welcome to the chat ~")
text:SetStyle("Alpha", 1)

local input_parent = Ext.IMGUI.NewWindow("Input Holder")
input_parent.NoTitleBar = true
input_parent:SetPos({chat_position[1], chat_position[2] + chat_size[2]})
input_parent:SetSize({chat_size[1], INPUT_HEIGHT})
input_parent:SetStyle("Alpha", INACTIVE_ALPHA)
input_parent.NoMove = true
input_parent.NoResize = true
input_parent.Visible = false

local input = input_parent:AddInputText("")
input.AllowTabInput = true
input.EscapeClearsAll = true
input.ItemWidth = chat_size[1] - 73
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

local settings_parent = Ext.IMGUI.NewWindow("Settings")
settings_parent:SetPos(chat_position)
settings_parent:SetSize({chat_size[1], chat_size[2] + INPUT_HEIGHT})
settings_parent.Visible = false
settings_parent.NoTitleBar = true
settings_parent.NoCollapse = true
settings_parent.NoInputs = true
settings_parent.NoNav = true

local log = settings_parent:AddText(DEFAULT_SETTINGS_TEXT)

local settings_button_toggled_holder = Ext.IMGUI.NewWindow("Settings Button Holder")
settings_button_toggled_holder.SameLine = false
settings_button_toggled_holder:SetPos({500, 500})
settings_button_toggled_holder.ItemWidth = 58
settings_button_toggled_holder:SetSize({70, INPUT_HEIGHT})
settings_button_toggled_holder.NoTitleBar = true
settings_button_toggled_holder.Visible = false
settings_button_toggled_holder.NoMove = true
settings_button_toggled_holder.NoResize = true
settings_button_toggled_holder.NoScrollbar = true

local function _toggle_settings()
    if settings_visible then
        text_parent.Visible = true
        input_parent.Visible = true

        settings_parent.Visible = false
        settings_button_toggled_holder.Visible = false

        settings_visible = false

        _P("Updating persistents")
        PersistentVars["WindowXPos"] = chat_position[1]
        PersistentVars["WindowYPos"] = chat_position[2]
        PersistentVars["WindowWidth"] = chat_size[1]
        PersistentVars["WindowHeight"] = chat_size[2]
    else
        text_parent.Visible = false
        input_parent.Visible = false

        settings_parent.Visible = true
        settings_button_toggled_holder.Visible = true

        settings_visible = true
    end
end

local settings_button_toggled = settings_button_toggled_holder:AddButton("Save")
settings_button_toggled.SameLine = false
settings_button_toggled.PositionOffset = {0, 0}
settings_button_toggled.ItemWidth = 58
settings_button_toggled.Size = {58, 25.3}
settings_button_toggled.OnClick = _toggle_settings

local settings_button_untoggled = input_parent:AddButton("Settings")
settings_button_untoggled.SameLine = false
settings_button_untoggled.PositionOffset = {chat_size[1] - 70, -27}
settings_button_untoggled.ItemWidth = 58
settings_button_untoggled.Size = {58, 25.3}
settings_button_untoggled.OnClick = _toggle_settings

local function _update_windows()
    _P("Updating window dimensions")
    text_parent.NoMove = false
    text_parent.NoResize = false
    text_parent:SetPos(chat_position)
    text_parent:SetSize(chat_size)
    text_parent.NoMove = true
    text_parent.NoResize = true
    input_parent.NoMove = false
    input_parent.NoResize = false
    input_parent:SetPos({chat_position[1], chat_position[2] + chat_size[2]})
    input_parent:SetSize({chat_size[1], INPUT_HEIGHT})
    input_parent.NoMove = true
    input_parent.NoResize = true
    input.ItemWidth = chat_size[1] - 73
    settings_parent:SetPos(chat_position)
    settings_parent:SetSize({chat_size[1], chat_size[2] + INPUT_HEIGHT})
    settings_button_untoggled.PositionOffset = {chat_size[1] - 70, -27}
    log.Label = DEFAULT_SETTINGS_TEXT
end

local function _handle_window_dragging(event)
    if event.Pressed then
        -- Left edge resize
        if event.X >= chat_position[1] - EDGE_SIZE and event.X <= chat_position[1] + EDGE_SIZE
        and event.Y >= chat_position[2] - EDGE_SIZE and event.Y <= chat_position[2] + chat_size[2] + INPUT_HEIGHT + EDGE_SIZE
        then is_left_resizing = true log.Label = DEFAULT_SETTINGS_TEXT .. "\n\nResizing left edge..."
        -- Top edge resize
        elseif event.X >= chat_position[1] - EDGE_SIZE and event.X <= chat_position[1] + chat_size[1] + EDGE_SIZE
        and event.Y >= chat_position[2] - EDGE_SIZE and event.Y <= chat_position[2] + EDGE_SIZE
        then is_top_resizing = true log.Label = DEFAULT_SETTINGS_TEXT .. "\n\nResizing top edge..."
        -- Right edge resize
        elseif event.X >= chat_position[1] + chat_size[1] - EDGE_SIZE and event.X <= chat_position[1] + chat_size[1] + EDGE_SIZE
        and event.Y >= chat_position[2] - EDGE_SIZE and event.Y <= chat_position[2] + chat_size[2] + INPUT_HEIGHT + EDGE_SIZE
        then is_right_resizing = true log.Label = DEFAULT_SETTINGS_TEXT .. "\n\nResizing right edge..."
        -- Bottom edge resize
        elseif event.X >= chat_position[1] - EDGE_SIZE and event.X <= chat_position[1] + chat_size[1] + EDGE_SIZE
        and event.Y >= chat_position[2] + chat_size[2] + INPUT_HEIGHT - EDGE_SIZE and event.Y <= chat_position[2] + INPUT_HEIGHT + chat_size[2] + EDGE_SIZE
        then is_bottom_resizing = true log.Label = DEFAULT_SETTINGS_TEXT .. "\n\nResizing bottom edge..."
        -- Move
        elseif event.X > chat_position[1] + EDGE_SIZE and event.X < chat_position[1] + chat_size[1] - EDGE_SIZE
        and event.Y > chat_position[2] + EDGE_SIZE and event.Y < chat_position[2] + chat_size[2] + INPUT_HEIGHT - EDGE_SIZE
        then is_moving = true log.Label = DEFAULT_SETTINGS_TEXT .. "\n\nMoving..."
        end

        if is_left_resizing or is_top_resizing or is_right_resizing or is_bottom_resizing or is_moving then pressed_coords = {event.X, event.Y} end
    else
        if is_left_resizing then
            chat_position[1] = event.X
            chat_size[1] = chat_size[1] + pressed_coords[1] - event.X
        elseif is_top_resizing then
            chat_position[2] = event.Y
            chat_size[2] = chat_size[2] + pressed_coords[2] - event.Y
        elseif is_right_resizing then chat_size[1] = chat_size[1] + event.X - pressed_coords[1]
        elseif is_bottom_resizing then chat_size[2] = chat_size[2] + event.Y - pressed_coords[2]
        elseif is_moving then
            chat_position[1] = chat_position[1] + event.X - pressed_coords[1]
            chat_position[2] = chat_position[2] + event.Y - pressed_coords[2]
        end

        if is_left_resizing or is_top_resizing or is_right_resizing or is_bottom_resizing or is_moving then
            is_left_resizing = false
            is_top_resizing = false
            is_right_resizing = false
            is_bottom_resizing = false
            is_moving = false

            _update_windows()
        end
    end
end

Ext.Events.MouseButtonInput:Subscribe(function (event) if settings_visible and event.Button == 1 then _handle_window_dragging(event) end end)

function TC_UpdateChat(new_message)
    text.Label = text.Label .. '\n' .. new_message
    -- Needs to wait for 1 frame to properly get the updated content size
    Ext.Timer.WaitFor(1, function() text_parent:SetScroll({0.0, 2000.0}) end)
end

local function _init_window_settings()
    _D(PersistentVars)
    if not PersistentVars["WindowXPos"] then
        _P("Initializing persistents to defaults")
        PersistentVars["WindowXPos"] = 1415
        PersistentVars["WindowYPos"] = 375
        PersistentVars["WindowWidth"] = 493
        PersistentVars["WindowHeight"] = 225
    end

    chat_position = {PersistentVars["WindowXPos"], PersistentVars["WindowYPos"]}
    chat_size = {PersistentVars["WindowWidth"], PersistentVars["WindowHeight"]}

    _update_windows()
    text_parent.Visible = true
    input_parent.Visible = true
end

local function handle_game_state_changed(event)
    if event.ToState == "Disconnect" then
        text_parent.Visible = false
        input_parent.Visible = false
        settings_parent.Visible = false
        settings_button_toggled_holder.Visible = false
    end
end

Ext.Events.SessionLoaded:Subscribe(function (event) _init_window_settings() end)
Ext.Events.GameStateChanged:Subscribe(handle_game_state_changed)

-- TODO:
--     - Persistent to save dimensions?
--     - Play sound effect upon new message?
--     - MAYBE configure text size to user's configured text size in the settings?
--     - Change "Settings" button to an image of a gear
