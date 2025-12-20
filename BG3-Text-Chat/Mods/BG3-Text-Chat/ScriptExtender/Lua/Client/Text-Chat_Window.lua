-- Ensure this file only runs on the client
if not Ext.IsClient() then
    return
end

-- Prevent double-loading the chat window (hot reload safety)
if _G.__TEXTCHAT_WINDOW_LOADED then
    return
end

-- Wrap the entire UI initialization in pcall so that any IMGUI or
-- UI root access failures do not break the mod loader.
-- Errors are logged and the chat window is skipped gracefully.
local ok_init, err = pcall(function()
    local CONFIG = {
        MinChatW = 360,
        MinChatH = 140,
        InputH = 45,

        ButtonW = 48,
        ButtonH = 48,
        ButtonYOffset = 0, -- flush (0px gap)

        EdgeSize = 10,
        ClampMargin = 5,

        DefaultActiveAlpha = 0.9,
        DefaultInactiveAlpha = 0.5,

        DefaultGreeting = "~ Welcome to the chat ~",
        DefaultSettingsText =
            "\n" ..
            "Move/Resize:\n" ..
            "- Enable Move Mode\n" ..
            "- Use Drag Button (MMB recommended)\n" ..
            "- Drag edges to resize, center to move\n" ..
            "Click Save when done.",

        DefaultShowTimestamps = false,
        DefaultFontScale = 1.0,

        DefaultEnterOpensChat = true,
        DefaultFocusKey = "RETURN",

        DefaultDebugKeys = false,
    }

    local settings_loaded = false
    local chat_enabled = true
    local settings_visible = false
    local move_mode = true
    local in_game = false

    local active_alpha = CONFIG.DefaultActiveAlpha
    local inactive_alpha = CONFIG.DefaultInactiveAlpha
    local drag_button = 2

    local show_timestamps = CONFIG.DefaultShowTimestamps
    local font_scale = CONFIG.DefaultFontScale

    local enter_opens_chat = CONFIG.DefaultEnterOpensChat
    local focus_key = CONFIG.DefaultFocusKey

    local debug_keys = CONFIG.DefaultDebugKeys

    local game_ui_hidden = false
    local last_root_visible = nil

    local chat_size = {493, 225}
    local chat_position = {1415, 375}
    local cached_game_window_width = 1920

    local input_active = false

    local is_moving, is_left_resizing, is_top_resizing, is_right_resizing, is_bottom_resizing =
        false, false, false, false, false
    local drag_active = false
    local drag_start_mouse = {0, 0}
    local drag_start_pos = {0, 0}
    local drag_start_size = {0, 0}

    local _apply_visibility
    local _apply_clickthrough
    local _update_windows
    local _save_window_settings
    local _toggle_settings
    local _sync_ui_hidden_from_root
    local _get_root_visible
    local _get_root_size
    local _clamp_to_screen
    local _apply_drag
    local _begin_drag
    local _end_drag
    local _clear_drag_flags
    local _recompute_drag_mode
    local _poll_mouse_pos
    local _apply_minimums
    local _update_edge_indicator
    local _current_alpha
    local _center_settings_panel

    -- Attempts to determine whether the game UI root is visible.
    -- Uses multiple fallbacks because different game states expose
    -- different properties.
    _get_root_visible = function()
        local gotRootObject, rootObject = pcall(function()
            return Ext.UI.GetRoot and Ext.UI.GetRoot() or nil
        end)
        if not gotRootObject or not rootObject then return nil end

        local gotIsVisibleProp, isVisible = pcall(function() return rootObject:GetProperty("IsVisible") end)
        if gotIsVisibleProp and isVisible ~= nil then
            return isVisible
        end

        local gotVisibilityProp, visibility = pcall(function() return rootObject:GetProperty("Visibility") end)
        if gotVisibilityProp and visibility ~= nil then
            return (tostring(visibility) == "Visible")
        end

        local gotOpacityProp, opacity = pcall(function() return rootObject:GetProperty(".VisualOpacity") end)
        if gotOpacityProp and opacity ~= nil then
            return (tonumber(opacity) or 1.0) > 0.01
        end

        return nil
    end

    -- Keeps our chat visibility in sync with the game's UI visibility
    -- (e.g. when the user hides the HUD).
    _sync_ui_hidden_from_root = function()
        local vis = _get_root_visible()
        if vis == nil then return end

        if last_root_visible == nil or vis ~= last_root_visible then
            last_root_visible = vis
            game_ui_hidden = (not vis)
            _apply_visibility()
        end
    end

    -- Gets the size of the game root window.
    _get_root_size = function()
        local gotRootObject, rootObject = pcall(function()
            return Ext.UI.GetRoot and Ext.UI.GetRoot() or nil
        end)
        if not gotRootObject or not rootObject then return nil, nil end

        local gotProps, props = pcall(function()
            return rootObject:GetAllProperties(rootObject)
        end)
        if not gotProps or not props then return nil, nil end

        return tonumber(props.ActualWidth), tonumber(props.ActualHeight)
    end

    _apply_minimums = function()
        chat_size[1] = math.max(chat_size[1], CONFIG.MinChatW)
        chat_size[2] = math.max(chat_size[2], CONFIG.MinChatH)
    end

    _clamp_to_screen = function()
        _apply_minimums()

        local w, h = _get_root_size()
        if not w or not h then return end
        cached_game_window_width = w

        local total_h = chat_size[2] + CONFIG.InputH
        local total_w = chat_size[1]

        chat_position[1] = math.max(CONFIG.ClampMargin, math.min(chat_position[1], w - total_w - CONFIG.ClampMargin))

        local min_y = CONFIG.ClampMargin + CONFIG.ButtonH
        local max_y = h - total_h - CONFIG.ClampMargin
        chat_position[2] = math.max(min_y, math.min(chat_position[2], max_y))
    end

    -- Polls the current mouse position in screen coordinates.
    _poll_mouse_pos = function()
        local gotPickingHelper, pickingHelper = pcall(function()
            return Ext.UI.GetPickingHelper(1)
        end)
        if not gotPickingHelper or not pickingHelper then return nil, nil end

        local gotCursorPos, cursorPos = pcall(function() return pickingHelper.WindowCursorPos end)
        if not gotCursorPos or type(cursorPos) ~= "table" then return nil, nil end

        local x, y = cursorPos[1], cursorPos[2]
        if type(x) == "number" and type(y) == "number" then
            return x, y
        end
        return nil, nil
    end

    _current_alpha = function()
        return input_active and active_alpha or inactive_alpha
    end

    _center_settings_panel = function(panel)
        local w, h = _get_root_size()
        if not w or not h then
            panel:SetPos({870, 650})
            return
        end

        local panelW, panelH = 360, 420
        panel:SetPos({
            math.floor((w - panelW) / 2),
            math.floor((h - panelH) / 2)
        })
    end

    local function _clamp_font_scale(v)
        v = tonumber(v)
        if not v then return font_scale end
        if v < 0.75 then v = 0.75 end
        if v > 2.0 then v = 2.0 end
        return v
    end

    -- IMGUI windows
    local text_parent = Ext.IMGUI.NewWindow("TextChat_Text")
    text_parent.NoTitleBar = true
    text_parent.NoFocusOnAppearing = true
    text_parent.NoNav = true
    text_parent.NoMove = true
    text_parent.NoResize = true
    text_parent.NoScrollbar = true
    text_parent.Visible = false

    local text = text_parent:AddText(CONFIG.DefaultGreeting)
    text:SetStyle("Alpha", 1)

    local input_parent = Ext.IMGUI.NewWindow("TextChat_Input")
    input_parent.NoTitleBar = true
    input_parent.NoFocusOnAppearing = true
    input_parent.NoNav = true
    input_parent.NoMove = true
    input_parent.NoResize = true
    input_parent.NoScrollbar = true
    input_parent.Visible = false

    local input = input_parent:AddInputText("")
    input.AllowTabInput = true
    input.EscapeClearsAll = true

    -- Focuses the input box for typing using a hack to reset its label and reactivate it.
    -- Required because IMGUI input widgets cannot be reliably re-focused once deactivated.
	local function _focus_input()
		input_active = true
		_apply_clickthrough() 

		input.Label = "###Input" .. tostring(Ext.Utils.MonotonicTime())

		Ext.Timer.WaitFor(1, function()
			if input.Activate then 
				input:Activate() 
			end
		end)
	end


    local full_overlay = Ext.IMGUI.NewWindow("TextChat_FullOverlay")
    full_overlay.NoTitleBar = true
    full_overlay.NoMove = true
    full_overlay.NoResize = true
    full_overlay.NoInputs = true
    full_overlay.NoNav = true
    full_overlay.NoScrollbar = true
    full_overlay.Visible = false
    full_overlay:SetStyle("Alpha", 0.88)

    local overlay_text = full_overlay:AddText(CONFIG.DefaultSettingsText)
    overlay_text:SetStyle("Alpha", 1)

    local drag_overlay = Ext.IMGUI.NewWindow("TextChat_DragOverlay")
    drag_overlay.NoTitleBar = true
    drag_overlay.NoMove = true
    drag_overlay.NoResize = true
    drag_overlay.NoInputs = true
    drag_overlay.NoNav = true
    drag_overlay.NoScrollbar = true
    drag_overlay.Visible = false
    drag_overlay:SetStyle("Alpha", 0.18)

    local edge_indicator = drag_overlay:AddText("")
    edge_indicator:SetStyle("Alpha", 1)

    local settings_button_window = Ext.IMGUI.NewWindow("TextChat_SettingsButtonTop")
    settings_button_window.NoTitleBar = true
    settings_button_window.NoMove = true
    settings_button_window.NoResize = true
    settings_button_window.NoScrollbar = true
    settings_button_window.NoNav = true
    settings_button_window.NoFocusOnAppearing = true
    settings_button_window.Visible = false
    settings_button_window:SetSize({CONFIG.ButtonW, CONFIG.ButtonH})
    settings_button_window.NoInputs = false

    local settings_button = settings_button_window:AddImageButton(
        "SettingsButton",
        "9735d896-1c99-412f-88ce-1bc3c129db18",
        {CONFIG.ButtonW * 0.6, CONFIG.ButtonH * 0.6}
    )
    settings_button.ItemWidth = CONFIG.ButtonW

    local settings_panel = Ext.IMGUI.NewWindow("TextChat_Settings")
    settings_panel.NoTitleBar = true
    settings_panel.NoMove = true
    settings_panel.NoResize = true
    settings_panel.NoNav = true
    settings_panel.Visible = false
    settings_panel:SetSize({600, 500})
    settings_panel.NoScrollbar = false -- allow scrolling if needed

    local clear_button = settings_panel:AddButton("Clear Chat")
    clear_button.ItemWidth = 280
    clear_button.Size = {280, 28}
    clear_button.OnClick = function() text.Label = CONFIG.DefaultGreeting end

    local move_mode_button = settings_panel:AddButton("Move Mode: ON")
    move_mode_button.ItemWidth = 280
    move_mode_button.Size = {280, 28}
    move_mode_button.OnClick = function()
        move_mode = not move_mode
        move_mode_button.Label = move_mode and "Move Mode: ON" or "Move Mode: OFF"
    end

    local timestamps_button = settings_panel:AddButton("Timestamps: OFF")
    timestamps_button.ItemWidth = 280
    timestamps_button.Size = {280, 28}
    timestamps_button.OnClick = function()
        show_timestamps = not show_timestamps
        timestamps_button.Label = show_timestamps and "Timestamps: ON" or "Timestamps: OFF"
    end

    settings_panel:AddText("Wrap Scale (0.75 - 2.0)")
    local font_scale_input = settings_panel:AddInputText(tostring(font_scale))

    local focus_toggle_button = settings_panel:AddButton("Focus Key Opens Chat: ON")
    focus_toggle_button.ItemWidth = 280
    focus_toggle_button.Size = {280, 28}
    focus_toggle_button.OnClick = function()
        enter_opens_chat = not enter_opens_chat
        focus_toggle_button.Label = enter_opens_chat and "Focus Key Opens Chat: ON" or "Focus Key Opens Chat: OFF"
    end

    settings_panel:AddText("Focus Key (KeyInput name, default RETURN)")
    local focus_key_input = settings_panel:AddInputText(tostring(focus_key))

    local reset_focus_key_button = settings_panel:AddButton("Reset Focus Key")
    reset_focus_key_button.ItemWidth = 280
    reset_focus_key_button.Size = {280, 28}
    reset_focus_key_button.OnClick = function()
        focus_key = CONFIG.DefaultFocusKey
        focus_key_input.Text = focus_key
    end

    local debug_keys_button = settings_panel:AddButton("Debug Key Presses: OFF")
    debug_keys_button.ItemWidth = 280
    debug_keys_button.Size = {280, 28}
    debug_keys_button.OnClick = function()
        debug_keys = not debug_keys
        debug_keys_button.Label = debug_keys and "Debug Key Presses: ON" or "Debug Key Presses: OFF"
    end

    settings_panel:AddText("Active Opacity (0.1 - 1.0)")
    local active_alpha_input = settings_panel:AddInputText(tostring(active_alpha))
    settings_panel:AddText("Inactive Opacity (0.1 - 1.0)")
    local inactive_alpha_input = settings_panel:AddInputText(tostring(inactive_alpha))

    local save_button = settings_panel:AddButton("Save")
    save_button.ItemWidth = 280
    save_button.Size = {280, 30}

    input.OnActivate = function()
        input_active = true
        local a = _current_alpha()
        text_parent:SetStyle("Alpha", a)
        input_parent:SetStyle("Alpha", a)
        settings_button_window:SetStyle("Alpha", a)
        _apply_clickthrough()
    end

    input.OnDeactivate = function()
        input_active = false
        TC_SendMessage(input.Text)
        input.Text = ""

        local a = _current_alpha()
        text_parent:SetStyle("Alpha", a)
        input_parent:SetStyle("Alpha", a)
        settings_button_window:SetStyle("Alpha", a)
        _apply_clickthrough()
    end

    -- Centralized input routing policy:
    --  - Chat ignores input when hidden or HUD is hidden
    --  - Settings panel blocks chat interaction
    --  - Input box only captures keys when active
    _apply_clickthrough = function()
        local show_chat = in_game and chat_enabled and (not game_ui_hidden)
        if not show_chat then
            text_parent.NoInputs = true
            input_parent.NoInputs = true
            settings_button_window.NoInputs = true
            return
        end

        if settings_visible then
            text_parent.NoInputs = true
            input_parent.NoInputs = true
            settings_button_window.NoInputs = false
            return
        end

        text_parent.NoInputs = (not input_active)
        input_parent.NoInputs = false
        settings_button_window.NoInputs = false
    end

    _apply_visibility = function()
        local show_chat = in_game and chat_enabled and (not game_ui_hidden)

        text_parent.Visible = show_chat
        input_parent.Visible = show_chat
        settings_button_window.Visible = show_chat

        full_overlay.Visible = in_game and settings_visible and (not game_ui_hidden)
        settings_panel.Visible = in_game and settings_visible and (not game_ui_hidden)

        if not drag_active then
            drag_overlay.Visible = false
        end

        _apply_clickthrough()
    end

    _save_window_settings = function()
        if not settings_loaded then
            return
        end

        _clamp_to_screen()
        TC_SaveWindowSettings({
            WindowXPos = tonumber(chat_position[1]) or 0,
            WindowYPos = tonumber(chat_position[2]) or 0,
            WindowWidth = tonumber(chat_size[1]) or CONFIG.MinChatW,
            WindowHeight = tonumber(chat_size[2]) or CONFIG.MinChatH,
            GameWindowWidth = tonumber(cached_game_window_width) or 0,

            ActiveAlpha = tonumber(active_alpha) or CONFIG.DefaultActiveAlpha,
            InactiveAlpha = tonumber(inactive_alpha) or CONFIG.DefaultInactiveAlpha,
            DragButton = tonumber(drag_button) or 2,

            ShowTimestamps = show_timestamps,
            FontScale = font_scale,
            EnterOpensChat = enter_opens_chat,
            FocusKey = focus_key,
        })
    end

    _update_windows = function()
        _clamp_to_screen()

        text_parent:SetPos(chat_position)
        text_parent:SetSize(chat_size)

        input_parent:SetPos({chat_position[1], chat_position[2] + chat_size[2]})
        input_parent:SetSize({chat_size[1], CONFIG.InputH})

        settings_button_window:SetPos({
            chat_position[1] + chat_size[1] - CONFIG.ButtonW,
            (chat_position[2] - CONFIG.ButtonH) + CONFIG.ButtonYOffset
        })
        settings_button_window:SetSize({CONFIG.ButtonW, CONFIG.ButtonH})

        full_overlay:SetPos(chat_position)
        full_overlay:SetSize({chat_size[1], chat_size[2] + CONFIG.InputH})
        overlay_text.Label = CONFIG.DefaultSettingsText

        drag_overlay:SetPos(chat_position)
        drag_overlay:SetSize({chat_size[1], chat_size[2] + CONFIG.InputH})

        input.ItemWidth = math.max(chat_size[1] - 20, 80)

        local a = _current_alpha()
        text_parent:SetStyle("Alpha", a)
        input_parent:SetStyle("Alpha", a)
        settings_button_window:SetStyle("Alpha", a)

        timestamps_button.Label = show_timestamps and "Timestamps: ON" or "Timestamps: OFF"
        focus_toggle_button.Label = enter_opens_chat and "Focus Key Opens Chat: ON" or "Focus Key Opens Chat: OFF"
        debug_keys_button.Label = debug_keys and "Debug Key Presses: ON" or "Debug Key Presses: OFF"
    end

    _toggle_settings = function()
        settings_visible = not settings_visible

        if settings_visible then
            active_alpha_input.Text = tostring(active_alpha)
            inactive_alpha_input.Text = tostring(inactive_alpha)
            font_scale_input.Text = tostring(font_scale)
            focus_key_input.Text = tostring(focus_key)

            timestamps_button.Label = show_timestamps and "Timestamps: ON" or "Timestamps: OFF"
            focus_toggle_button.Label = enter_opens_chat and "Focus Key Opens Chat: ON" or "Focus Key Opens Chat: OFF"
            debug_keys_button.Label = debug_keys and "Debug Key Presses: ON" or "Debug Key Presses: OFF"

            _center_settings_panel(settings_panel)
        else
            local activeAlpha = tonumber(active_alpha_input.Text)
            local inactiveAlpha = tonumber(inactive_alpha_input.Text)

            if activeAlpha then active_alpha = math.max(0.1, math.min(activeAlpha, 1.0)) end
            if inactiveAlpha then inactive_alpha = math.max(0.1, math.min(inactiveAlpha, 1.0)) end
            font_scale = _clamp_font_scale(font_scale_input.Text)

            local focusKey = tostring(focus_key_input.Text or ""):upper()
            if focusKey ~= "" then
                focus_key = focusKey
            end

            _save_window_settings()
            _update_windows()
        end

        _apply_visibility()
    end

    settings_button.OnClick = _toggle_settings
    save_button.OnClick = _toggle_settings

    _update_edge_indicator = function()
        if not drag_active then
            edge_indicator.Label = ""
            return
        end

        if is_left_resizing then
            edge_indicator.Label = "Resizing: LEFT"
        elseif is_right_resizing then
            edge_indicator.Label = "Resizing: RIGHT"
        elseif is_top_resizing then
            edge_indicator.Label = "Resizing: TOP"
        elseif is_bottom_resizing then
            edge_indicator.Label = "Resizing: BOTTOM"
        elseif is_moving then
            edge_indicator.Label = "Moving"
        else
            edge_indicator.Label = ""
        end
    end

    _clear_drag_flags = function()
        is_left_resizing, is_top_resizing, is_right_resizing, is_bottom_resizing, is_moving =
            false, false, false, false, false
    end

    -- Drag lifecycle:
    --  1) _begin_drag() determines mode and captures starting state
    --  2) _apply_drag() applies deltas every frame
    --  3) _end_drag() commits, clamps, and persists the result
    _begin_drag = function()
        if not (in_game and settings_visible and move_mode) then return end
        local mx, my = _poll_mouse_pos()
        if not mx or not my then return end
        if not _recompute_drag_mode(mx, my) then return end

        drag_active = true
        drag_start_mouse = {mx, my}
        drag_start_pos = {chat_position[1], chat_position[2]}
        drag_start_size = {chat_size[1], chat_size[2]}
        drag_overlay.Visible = true
        _update_edge_indicator()
    end

    _end_drag = function()
        if not drag_active then return end
        drag_active = false
        drag_overlay.Visible = false
        _clear_drag_flags()
        _update_edge_indicator()
        _update_windows()
        _save_window_settings()
    end

    -- Determines which drag mode should be active based on cursor position:
    --  - Move (center)
    --  - Resize (left / right / top / bottom edges)
    -- Returns true if a valid drag mode was detected.
    _recompute_drag_mode = function(mx, my)
        _clear_drag_flags()

        local top_y = chat_position[2] - CONFIG.ButtonH
        local bottom_y = chat_position[2] + chat_size[2] + CONFIG.InputH

        if mx >= chat_position[1] - CONFIG.EdgeSize and mx <= chat_position[1] + CONFIG.EdgeSize
            and my >= top_y - CONFIG.EdgeSize and my <= bottom_y + CONFIG.EdgeSize
        then
            is_left_resizing = true
        elseif mx >= chat_position[1] - CONFIG.EdgeSize and mx <= chat_position[1] + chat_size[1] + CONFIG.EdgeSize
            and my >= top_y - CONFIG.EdgeSize and my <= top_y + CONFIG.EdgeSize
        then
            is_top_resizing = true
        elseif mx >= chat_position[1] + chat_size[1] - CONFIG.EdgeSize and mx <= chat_position[1] + chat_size[1] + CONFIG.EdgeSize
            and my >= top_y - CONFIG.EdgeSize and my <= bottom_y + CONFIG.EdgeSize
        then
            is_right_resizing = true
        elseif mx >= chat_position[1] - CONFIG.EdgeSize and mx <= chat_position[1] + chat_size[1] + CONFIG.EdgeSize
            and my >= bottom_y - CONFIG.EdgeSize and my <= bottom_y + CONFIG.EdgeSize
        then
            is_bottom_resizing = true
        elseif mx > chat_position[1] + CONFIG.EdgeSize and mx < chat_position[1] + chat_size[1] - CONFIG.EdgeSize
            and my > top_y + CONFIG.EdgeSize and my < bottom_y - CONFIG.EdgeSize
        then
            is_moving = true
        end

        return is_left_resizing or is_top_resizing or is_right_resizing or is_bottom_resizing or is_moving
    end

    -- Applies movement or resizing based on the active drag mode.
    -- Mouse delta is calculated relative to drag start.
    _apply_drag = function(mx, my)
        if not drag_active then return end

        local dx = mx - drag_start_mouse[1]
        local dy = my - drag_start_mouse[2]

        if is_moving then
            chat_position[1] = drag_start_pos[1] + dx
            chat_position[2] = drag_start_pos[2] + dy
        elseif is_left_resizing then
            chat_position[1] = drag_start_pos[1] + dx
            chat_size[1] = drag_start_size[1] - dx
        elseif is_right_resizing then
            chat_size[1] = drag_start_size[1] + dx
        elseif is_top_resizing then
            chat_position[2] = drag_start_pos[2] + dy
            chat_size[2] = drag_start_size[2] - dy
        elseif is_bottom_resizing then
            chat_size[2] = drag_start_size[2] + dy
        end

        _apply_minimums()
        _clamp_to_screen()
        _update_windows()
    end

    Ext.Events.MouseButtonInput:Subscribe(function(event)
        if event.Button == drag_button then
            if event.Pressed then
                _begin_drag()
            else
                _end_drag()
            end
        end
    end)

    Ext.Events.Tick:Subscribe(function(_)
        _sync_ui_hidden_from_root()

        if drag_active then
            local mx, my = _poll_mouse_pos()
            if mx and my then
                _apply_drag(mx, my)
                _update_edge_indicator()
            end
        end
    end)

    Ext.Events.KeyInput:Subscribe(function(event)
        if debug_keys and event.Pressed and not event.Repeat then
            Ext.Utils.Print("[TextChat] KeyInput: " .. tostring(event.Key))
        end

        if not enter_opens_chat then return end
        if not in_game or not chat_enabled or game_ui_hidden then return end
        if settings_visible or drag_active then return end
        if event.Repeat then return end
        if not event.Pressed then return end
        if tostring(event.Key) ~= tostring(focus_key) then return end

        Ext.Utils.Print("[TextChat] Focus key pressed -> focusing input")
        _focus_input()
    end)

    function TC_UpdateChat(new_message)
        text.Label = text.Label .. "\n" .. new_message
        -- Needs to wait for 1 frame to properly get the updated content size
        Ext.Timer.WaitFor(1, function()
            text_parent:SetScroll({0.0, 99999999.0})
        end)
    end

    local function _init_window_settings()
        local settings = TC_LoadWindowSettings() or {}

        chat_position = {
            tonumber(settings.WindowXPos) or chat_position[1],
            tonumber(settings.WindowYPos) or chat_position[2]
        }

        chat_size = {
            tonumber(settings.WindowWidth) or chat_size[1],
            tonumber(settings.WindowHeight) or chat_size[2]
        }

        local rw = select(1, _get_root_size())
        cached_game_window_width = tonumber(rw) or tonumber(settings.GameWindowWidth) or cached_game_window_width

        active_alpha = tonumber(settings.ActiveAlpha) or CONFIG.DefaultActiveAlpha
        inactive_alpha = tonumber(settings.InactiveAlpha) or CONFIG.DefaultInactiveAlpha
        drag_button = tonumber(settings.DragButton) or drag_button

        show_timestamps = settings.ShowTimestamps
        font_scale = _clamp_font_scale(settings.FontScale)

        enter_opens_chat = not settings.EnterOpensChat
        focus_key = tostring(settings.FocusKey or CONFIG.DefaultFocusKey)

        active_alpha_input.Text = tostring(active_alpha)
        inactive_alpha_input.Text = tostring(inactive_alpha)

        last_root_visible = nil
        _sync_ui_hidden_from_root()

        settings_loaded = true

        timestamps_button.Label = show_timestamps and "Timestamps: ON" or "Timestamps: OFF"
        focus_toggle_button.Label = enter_opens_chat and "Focus Key Opens Chat: ON" or "Focus Key Opens Chat: OFF"
        font_scale_input.Text = tostring(font_scale)
        focus_key_input.Text = tostring(focus_key)
        debug_keys_button.Label = debug_keys and "Debug Key Presses: ON" or "Debug Key Presses: OFF"

        _update_windows()
        _apply_visibility()
    end

    -- Handles entering and leaving a game session.
    -- Resets transient UI state and persists window settings on unload.
    Ext.Events.GameStateChanged:Subscribe(function(event)
        if event.ToState == "PrepareRunning" then
            if TC_ResetSessionClock then
                TC_ResetSessionClock()
            end

            in_game = true
            _init_window_settings()
        elseif event.ToState == "UnloadLevel" then
            in_game = false
            if settings_loaded then
                _save_window_settings()
            end

            settings_visible = false
            drag_active = false
            input_active = false
            game_ui_hidden = true
            _apply_visibility()
        end
    end)
end)

if not ok_init then
    Ext.Utils.Print("[TextChat] Window init failed: " .. tostring(err))
    return
end

_G.__TEXTCHAT_WINDOW_LOADED = true