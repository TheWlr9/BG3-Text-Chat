if not Ext.IsClient() then
    return
end

if _G.__DEVCHAT_WINDOW_LOADED then
    return
end

local ok_init, err = pcall(function()
    local CFG = Ext.Require("Shared/Text-Chat_Config.lua")

    local CONFIG = {
        MinChatW = 360,
        MinChatH = 140,

        BaseInputH = 34,

        ButtonW = 52,
        ButtonH = 32,
        ButtonYOffset = 0,

        TopBarPad = 7,

        ClampMargin = 5,

        DefaultGreeting = "~ Tip: Ctrl+Enter for a new line, Up Arrow to edit your last message ~",
    }

    local settings_loaded = false
    local initial_hint_shown = false
    local chat_enabled = true
    local settings_visible = false

    local listening_for_open_key = false
    local in_game = false

    local active_alpha = CFG.DefaultActiveAlpha
    local inactive_alpha = CFG.DefaultInactiveAlpha
    local move_mode = false

    local show_timestamps = CFG.DefaultShowTimestamps
    local show_hint_message = CFG.DefaultShowHintMessage
    local chat_format = CFG.DefaultChatFormat

    local CHAT_FORMAT_ORDER = {"classic", "modern", "discord", "roleplayer"}
    local function _chat_format_to_index(fmt)
        for i, f in ipairs(CHAT_FORMAT_ORDER) do
            if f == fmt then return i - 1 end
        end
        return 3
    end
    local function _index_to_chat_format(idx)
        return CHAT_FORMAT_ORDER[idx + 1] or "roleplayer"
    end
    local open_key = CFG.DefaultOpenKey

    local auto_hide_enabled = CFG.DefaultAutoHideEnabled
    local auto_hide_delay = CFG.AutoHideDelaySeconds
    local typing_notifications_enabled = CFG.DefaultTypingNotificationsEnabled
    local overhead_text_enabled = CFG.DefaultOverheadTextEnabled

    local game_ui_hidden = false
    local last_root_visible = nil

    local chat_size = {CFG.DefaultWindowWidth, CFG.DefaultWindowHeight}
    local chat_position = {CFG.DefaultWindowXPos, CFG.DefaultWindowYPos}
    local cached_game_window_width = 1920
    local current_input_h = CONFIG.BaseInputH

    local current_status_h = 0

    local input_active = false
    local last_seen_input_text = ""

    local last_activity_ms = 0
    local chat_hidden_by_idle = false

    local last_mouse_press_ms = -999999
    local activated_at_ms = -999999

    local suppress_send_on_deactivate = false

    local suppress_next_change = false

    local typing_users = {}
    local last_typing_sent_ms = -999999
    local last_typing_state_sent = false

    local chat_messages = {}
    local chat_messages_by_id = {}

    local editing_message_id = nil

    local my_last_message = nil

    local cached_draft_text = nil

    local _apply_visibility
    local _apply_clickthrough
    local _update_windows
    local _save_window_settings
    local _sync_ui_hidden_from_root
    local _get_root_visible
    local _get_root_size
    local _clamp_to_screen
    local _apply_minimums
    local _current_alpha
    local _focus_input
    local _touch_activity
    local _update_dynamic_input_size
    local _submit_input
    local _add_chat_entry
    local _edit_chat_entry
    local _clear_chat_local
    local _update_status_line
    local _prune_typing_users
    local _apply_move_mode
    local _toggle_settings

    _get_root_visible = function()
        local gotRootObject, rootObject = pcall(function()
            return Ext.UI.GetRoot and Ext.UI.GetRoot() or nil
        end)
        if not gotRootObject or not rootObject then return nil end

        local gotIsVisibleProp, isVisible = pcall(function() return rootObject:GetProperty("IsVisible") end)
        if gotIsVisibleProp and isVisible ~= nil then return isVisible end

        local gotVisibilityProp, visibility = pcall(function() return rootObject:GetProperty("Visibility") end)
        if gotVisibilityProp and visibility ~= nil then return (tostring(visibility) == "Visible") end

        local gotOpacityProp, opacity = pcall(function() return rootObject:GetProperty(".VisualOpacity") end)
        if gotOpacityProp and opacity ~= nil then return (tonumber(opacity) or 1.0) > 0.01 end

        return nil
    end

    _sync_ui_hidden_from_root = function()
        local vis = _get_root_visible()
        if vis == nil then return end

        if last_root_visible == nil or vis ~= last_root_visible then
            last_root_visible = vis
            game_ui_hidden = (not vis)
            _apply_visibility()
        end
    end

    _get_root_size = function()
        local gotRootObject, rootObject = pcall(function()
            return Ext.UI.GetRoot and Ext.UI.GetRoot() or nil
        end)
        if not gotRootObject or not rootObject then return nil, nil end

        local gotProps, props = pcall(function() return rootObject:GetAllProperties(rootObject) end)
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
        if not w or not h or w <= 0 or h <= 0 then return end
        cached_game_window_width = w

        local total_h = chat_size[2] + current_status_h + current_input_h
        local total_w = chat_size[1]

        chat_position[1] = math.max(CONFIG.ClampMargin, math.min(chat_position[1], w - total_w - CONFIG.ClampMargin))

        local min_y = CONFIG.ClampMargin + CONFIG.ButtonH + (2 * CONFIG.TopBarPad)
        local max_y = h - total_h - CONFIG.ClampMargin
        chat_position[2] = math.max(min_y, math.min(chat_position[2], max_y))
    end

    _current_alpha = function()
        return input_active and active_alpha or inactive_alpha
    end

    _touch_activity = function()
        last_activity_ms = Ext.Utils.MonotonicTime()
        if chat_hidden_by_idle then
            chat_hidden_by_idle = false
            _apply_visibility()
        end
    end

    local move_mode_frame = Ext.IMGUI.NewWindow("Text-Chat_MoveFrame")
    move_mode_frame.NoTitleBar = true
    move_mode_frame.NoMove = true
    move_mode_frame.NoResize = true
    move_mode_frame.NoCollapse = true
    move_mode_frame.NoFocusOnAppearing = true
    move_mode_frame.NoScrollbar = true
    move_mode_frame.NoNav = true
    move_mode_frame.NoInputs = true
    move_mode_frame.Visible = false

    move_mode_frame:SetStyle("Alpha", 1.0)

    local text_parent = Ext.IMGUI.NewWindow("Text-Chat_Text")
    text_parent.NoTitleBar = true
    text_parent.NoFocusOnAppearing = true
    text_parent.NoNav = true
    text_parent.NoMove = true
    text_parent.NoResize = true

    text_parent.NoScrollbar = false
    text_parent.Visible = false

    local TEXT_PAD_X = 12
    local TEXT_SCROLLBAR_W = 16
    text_parent:SetStyle("WindowPadding", TEXT_PAD_X, 8)
    text_parent:SetStyle("ScrollbarSize", TEXT_SCROLLBAR_W)

    text_parent:SetStyle("ItemSpacing", 0, 3)

    local TYPING_STATUS_H = 34
    local status_window = Ext.IMGUI.NewWindow("Text-Chat_Status")
    status_window.NoTitleBar = true
    status_window.NoFocusOnAppearing = true
    status_window.NoNav = true
    status_window.NoMove = true
    status_window.NoResize = true
    status_window.NoScrollbar = true
    status_window.NoInputs = true
    status_window.Visible = false
    status_window:SetStyle("WindowPadding", TEXT_PAD_X, 4)
    local status_text = status_window:AddText("")
    status_text:SetStyle("Alpha", 1)
    pcall(function() status_text:SetColor("Text", CFG.TypingIndicatorColor) end)

    local input_parent = Ext.IMGUI.NewWindow("Text-Chat_Input")
    input_parent.NoTitleBar = true

    input_parent.NoMove = true
    input_parent.NoResize = true
    input_parent.NoScrollbar = true
    input_parent.Visible = false

    local input = input_parent:AddInputText("")
    input.AllowTabInput = true
    input.EscapeClearsAll = true
    input.Multiline = true
    input.CtrlEnterForNewLine = true

    local EDIT_BUTTON_W = 46

    local EDIT_BUTTON_GAP = 12

    local edit_button = input_parent:AddButton("Edit")
    edit_button.SameLine = true
    edit_button.ItemWidth = EDIT_BUTTON_W

    local function _grant_real_focus()
        input.Label = "###Input" .. tostring(Ext.Utils.MonotonicTime())
        Ext.Timer.WaitFor(1, function()
            if input.Activate then input:Activate() end
        end)
    end

    _focus_input = function()
        chat_hidden_by_idle = false
        _touch_activity()
        _grant_real_focus()
        _apply_clickthrough()
        _apply_visibility()
    end

    local TOP_BAR_PAD = CONFIG.TopBarPad
    local TOP_BAR_GAP = 7
    local TOP_BAR_RIGHT_EXTRA = 8
    local TOP_BAR_W = (CONFIG.ButtonW * 3) + (2 * TOP_BAR_GAP) + (2 * TOP_BAR_PAD) + TOP_BAR_RIGHT_EXTRA

    local TOP_BAR_TOTAL_H = CONFIG.ButtonH + (2 * TOP_BAR_PAD)

    local settings_button_window = Ext.IMGUI.NewWindow("Text-Chat_TopBar")
    settings_button_window.NoTitleBar = true
    settings_button_window.NoMove = true
    settings_button_window.NoResize = true
    settings_button_window.NoScrollbar = true
    settings_button_window.NoNav = true
    settings_button_window.NoFocusOnAppearing = true
    settings_button_window.Visible = false
    settings_button_window:SetStyle("WindowPadding", TOP_BAR_PAD, TOP_BAR_PAD)
    settings_button_window:SetStyle("ItemSpacing", TOP_BAR_GAP, 4)
    settings_button_window:SetSize({TOP_BAR_W, TOP_BAR_TOTAL_H})
    settings_button_window.NoInputs = false

    local MENU_BUTTON_COLOR_CLOSED = {0.3, 0.18, 0.09, 1.0}

    local MENU_BUTTON_COLOR_OPEN = {0.42, 0.28, 0.18, 1.0}

    local settings_button = settings_button_window:AddButton("Menu")
    settings_button.ItemWidth = CONFIG.ButtonW
    pcall(function() settings_button:SetColor("Button", MENU_BUTTON_COLOR_CLOSED) end)

    local clear_button_top = settings_button_window:AddButton("Clear")
    clear_button_top.SameLine = true
    clear_button_top.ItemWidth = CONFIG.ButtonW

    local close_button_top = settings_button_window:AddButton("Close")
    close_button_top.SameLine = true
    close_button_top.ItemWidth = CONFIG.ButtonW

    local SETTINGS_PANEL_W = 340
    local SETTINGS_PANEL_H = 520

    local settings_panel = Ext.IMGUI.NewWindow("Text-Chat_Settings")
    settings_panel.NoTitleBar = true
    settings_panel.NoMove = true
    settings_panel.NoResize = true
    settings_panel.NoNav = true
    settings_panel.Visible = false
    settings_panel:SetSize({SETTINGS_PANEL_W, SETTINGS_PANEL_H})
    settings_panel:SetStyle("WindowPadding", 14, 12)
    settings_panel.NoScrollbar = false

    local SETTINGS_SCROLLBAR_MARGIN = 16
    local SETTINGS_WIDGET_W = SETTINGS_PANEL_W - 28 - SETTINGS_SCROLLBAR_MARGIN

    settings_panel:AddSeparatorText("Display")

    local move_mode_checkbox = settings_panel:AddCheckbox("Move Mode", move_mode)
    move_mode_checkbox.OnChange = function()
        move_mode = move_mode_checkbox.Checked
        _apply_move_mode()
        _apply_visibility()
    end

    local timestamps_checkbox = settings_panel:AddCheckbox("Timestamps", show_timestamps)

    local hint_message_checkbox = settings_panel:AddCheckbox("Show shortcuts hint", show_hint_message)

    local overhead_text_checkbox = settings_panel:AddCheckbox("Text above character", overhead_text_enabled)
    overhead_text_checkbox.OnChange = function()
        overhead_text_enabled = overhead_text_checkbox.Checked
        _save_window_settings()
    end

    settings_panel:AddText("Opacity (input focused)")
    local active_alpha_slider = settings_panel:AddSlider("##active_alpha", active_alpha, 0.1, 1.0)
    active_alpha_slider.ItemWidth = SETTINGS_WIDGET_W
    active_alpha_slider.OnChange = function()
        local ok, v = pcall(function() return active_alpha_slider.Value[1] end)
        if ok and v then active_alpha = v end
        _update_windows()
        _save_window_settings()
    end

    settings_panel:AddText("Opacity (idle)")
    local inactive_alpha_slider = settings_panel:AddSlider("##inactive_alpha", inactive_alpha, 0.1, 1.0)
    inactive_alpha_slider.ItemWidth = SETTINGS_WIDGET_W
    inactive_alpha_slider.OnChange = function()
        local ok, v = pcall(function() return inactive_alpha_slider.Value[1] end)
        if ok and v then inactive_alpha = v end
        _update_windows()
        _save_window_settings()
    end

    settings_panel:AddText("Chat format")
    local chat_format_combo = settings_panel:AddCombo("##chat_format")
    chat_format_combo.ItemWidth = SETTINGS_WIDGET_W
    chat_format_combo.Options = {"Classic", "Modern", "Discord", "Roleplayer"}
    chat_format_combo.SelectedIndex = _chat_format_to_index(chat_format)

    settings_panel:AddSeparatorText("Behavior")

    settings_panel:AddText("Open key")
    local open_key_button = settings_panel:AddButton("Current: " .. open_key)
    open_key_button.ItemWidth = SETTINGS_WIDGET_W

    local typing_notif_checkbox = settings_panel:AddCheckbox("Typing notifications", typing_notifications_enabled)
    typing_notif_checkbox.OnChange = function()
        typing_notifications_enabled = typing_notif_checkbox.Checked
        if not typing_notifications_enabled then

            if next(typing_users) ~= nil then
                typing_users = {}
                _update_status_line()
                _touch_activity()
            end
        end
        _save_window_settings()
    end

    local auto_hide_checkbox = settings_panel:AddCheckbox("Auto-hide", auto_hide_enabled)
    auto_hide_checkbox.OnChange = function()
        auto_hide_enabled = auto_hide_checkbox.Checked
        if not auto_hide_enabled then _touch_activity() end
        _save_window_settings()
    end

    settings_panel:AddText("Auto-hide delay (seconds)")
    local auto_hide_delay_slider = settings_panel:AddSliderInt("##auto_hide_delay", auto_hide_delay, 1, 60)
    auto_hide_delay_slider.ItemWidth = SETTINGS_WIDGET_W
    auto_hide_delay_slider.OnChange = function()
        local ok, v = pcall(function() return auto_hide_delay_slider.Value[1] end)
        if ok and v then auto_hide_delay = v end
        _save_window_settings()
    end

    local INPUT_PAD = 12

    input_parent:SetStyle("WindowPadding", INPUT_PAD, INPUT_PAD)
    input_parent:SetStyle("ItemSpacing", EDIT_BUTTON_GAP, 4)

    local function _count_input_lines(text)
        local n = 1
        for _ in text:gmatch("\n") do n = n + 1 end
        return n
    end

    _update_dynamic_input_size = function(_)
        local field_w = math.max(chat_size[1] - (2 * INPUT_PAD) - EDIT_BUTTON_W - EDIT_BUTTON_GAP, 80)

        local base_input_h = CFG.InputFirstLineHeightPx + (2 * INPUT_PAD)
        local min_allowed_chat_h = math.max(CONFIG.MinChatH, chat_size[2] / 2)
        local max_extra_h = math.max(chat_size[2] - min_allowed_chat_h, 0)
        local max_extra_lines = math.floor(max_extra_h / CFG.InputExtraLineHeightPx)
        local dynamicMaxLines = 1 + max_extra_lines

        local lineCount = math.min(_count_input_lines(input.Text or ""), dynamicMaxLines)
        local content_h = CFG.InputFirstLineHeightPx + (lineCount - 1) * CFG.InputExtraLineHeightPx
        current_input_h = content_h + (2 * INPUT_PAD)

        pcall(function() input.SizeHint = {field_w, content_h} end)
        input.ItemWidth = field_w
        edit_button.ItemWidth = EDIT_BUTTON_W

        local extra_h = math.max(current_input_h - base_input_h, 0)
        local effective_chat_h = math.max(chat_size[2] - extra_h, CONFIG.MinChatH)

        text_parent:SetPos(chat_position)
        text_parent:SetSize({chat_size[1], effective_chat_h})

        local chat_bottom_y = chat_position[2] + effective_chat_h

        status_window:SetPos({chat_position[1], chat_bottom_y})
        status_window:SetSize({chat_size[1], current_status_h})

        input_parent:SetPos({chat_position[1], chat_bottom_y + current_status_h})
        input_parent:SetSize({chat_size[1], current_input_h})
    end

    _update_status_line = function()
        _prune_typing_users()

        local names = {}
        for name, _ in pairs(typing_users) do table.insert(names, name) end
        table.sort(names)

        if #names == 0 then
            status_text.Label = ""
        elseif #names == 1 then
            status_text.Label = names[1] .. " is typing..."
        else

            status_text.Label = "Several people are typing..."
        end

        current_status_h = TYPING_STATUS_H
        status_window.Visible = (in_game and chat_enabled and not game_ui_hidden and not chat_hidden_by_idle)

        _update_dynamic_input_size()
    end

    _prune_typing_users = function()
        local now = Ext.Utils.MonotonicTime()
        local changed = false
        for name, expiry in pairs(typing_users) do
            if now > expiry then
                typing_users[name] = nil
                changed = true
            end
        end
        if changed and next(typing_users) == nil then

            _touch_activity()
        end
        return changed
    end

    _submit_input = function()
        local text = input.Text or ""
        if text == "" then return end

        local wasEditing = (editing_message_id ~= nil)

        local sendText = text:gsub("%s*\n%s*", " ")

        sendText = sendText:gsub("^%s+", ""):gsub("%s+$", "")
        if sendText == "" then return end

        if editing_message_id ~= nil then
            TC_SendEdit(editing_message_id, sendText)
            editing_message_id = nil
        else
            TC_SendMessage(sendText)
        end

        if wasEditing and cached_draft_text then
            local restored = cached_draft_text
            cached_draft_text = nil

            suppress_next_change = true
            input.Text = restored
            last_seen_input_text = restored
            Ext.Timer.WaitFor(1, function() suppress_next_change = false end)
            _update_dynamic_input_size(restored)
            _grant_real_focus()
        else
            input.Text = ""
            last_seen_input_text = ""
            _update_dynamic_input_size("")
        end

        if last_typing_state_sent then
            TC_SendTyping(false)
            last_typing_state_sent = false
        end
        _update_status_line()
        _touch_activity()
    end

    local function _begin_edit_last_message(force)
        if not (my_last_message and my_last_message.id) then return end

        local currentText = input.Text or ""

        if not force then
            if currentText ~= "" then return end
        elseif editing_message_id == nil and currentText ~= "" then
            cached_draft_text = currentText
        end

        editing_message_id = my_last_message.id
        local targetText = my_last_message.text

        suppress_next_change = true
        input.Text = targetText
        last_seen_input_text = targetText
        Ext.Timer.WaitFor(1, function() suppress_next_change = false end)

        _update_dynamic_input_size(targetText)
        _update_status_line()
        _touch_activity()
        _grant_real_focus()
    end

    local function _load_last_message_for_edit()
        _begin_edit_last_message(false)
    end

    local function _on_input_text_changed(text)
        _touch_activity()

        if text ~= "" then
            local now = Ext.Utils.MonotonicTime()
            if (now - last_typing_sent_ms) > (CFG.TypingBroadcastThrottleSeconds * 1000) or not last_typing_state_sent
            then
                TC_SendTyping(true)
                last_typing_sent_ms = now
                last_typing_state_sent = true
            end
        else
            if last_typing_state_sent then
                TC_SendTyping(false)
                last_typing_state_sent = false
            end

        end

        _update_dynamic_input_size(text)
    end

    input.OnChange = function()
        if suppress_next_change then return end

        local now_text = input.Text or ""
        last_seen_input_text = now_text
        _on_input_text_changed(now_text)
    end

    input.OnActivate = function()
        input_active = true
        activated_at_ms = Ext.Utils.MonotonicTime()
        _touch_activity()
        local a = _current_alpha()
        text_parent:SetStyle("Alpha", a)
        input_parent:SetStyle("Alpha", a)
        status_window:SetStyle("Alpha", a)
        settings_button_window:SetStyle("Alpha", a)
        _apply_clickthrough()
    end

    input.OnDeactivate = function()
        input_active = false

        _touch_activity()

        local myActivatedAt = activated_at_ms

        Ext.Timer.WaitForRealtime(200, function()
            local clickDuringThisFocus = last_mouse_press_ms > myActivatedAt
            local causedByClick = clickDuringThisFocus and (Ext.Utils.MonotonicTime() - last_mouse_press_ms) < 500

            if not causedByClick and not suppress_send_on_deactivate then

                _submit_input()
            end
        end)

        if last_typing_state_sent then
            TC_SendTyping(false)
            last_typing_state_sent = false
        end

        local a = _current_alpha()
        text_parent:SetStyle("Alpha", a)
        input_parent:SetStyle("Alpha", a)
        status_window:SetStyle("Alpha", a)
        settings_button_window:SetStyle("Alpha", a)
        _apply_clickthrough()
    end

    local current_widgets = {}

    local function _destroy_current_widgets()
        for _, w in ipairs(current_widgets) do
            pcall(function() w:Destroy() end)
        end
        current_widgets = {}
    end

    local CHAT_FORMAT_BUILDERS = {

        classic = function(name, ts, showTs)
            if showTs then
                return { { text = "[" .. ts .. "] <" .. name .. ">" } }
            end
            return { { text = "<" .. name .. ">" } }
        end,

        modern = function(name, ts, showTs)
            if showTs then
                return { { text = "[" .. ts .. "] - " .. name } }
            end
            return { { text = "- " .. name } }
        end,

        discord = function(name, ts, showTs)
            if showTs then
                return {
                    { text = name },
                    { text = " " .. ts, color = CFG.EditedColor },
                }
            end
            return { { text = name } }
        end,

        roleplayer = function(name, ts, showTs)
            local nameTag = "___ " .. name .. " ___"
            if showTs then
                return {
                    { text = nameTag },
                    { text = " " .. ts, color = CFG.EditedColor },
                }
            end
            return { { text = nameTag } }
        end,
    }

    local function _render_message(rec, showName)
        if rec.kind == "system" then
            local w = text_parent:AddText(rec.raw)
            pcall(function() w.TextWrapPos = 0 end)
            w:SetStyle("Alpha", 1)
            return { w }, rec.raw
        end

        local body = rec.raw or ""

        local widgets = {}

        local function _addLine(text, color, isEmote)
            local w = text_parent:AddText(text)
            pcall(function() w.TextWrapPos = 0 end)
            w:SetStyle("Alpha", 1)
            if color then
                pcall(function() w:SetColor("Text", color) end)
            end
            if isEmote and CFG.EmoteFontName ~= "" then
                pcall(function() w.Font = CFG.EmoteFontName end)
            end
            table.insert(widgets, w)
        end

        local function _addHeaderParts(parts)
            for i, part in ipairs(parts) do
                local w = text_parent:AddText(part.text)
                pcall(function() w.TextWrapPos = 0 end)
                w:SetStyle("Alpha", 1)
                pcall(function() w:SetColor("Text", part.color or CFG.NameColor) end)
                if i > 1 then
                    pcall(function() w.SameLine = true end)
                end
                table.insert(widgets, w)
            end
        end

        if showName then
            local builder = CHAT_FORMAT_BUILDERS[chat_format] or CHAT_FORMAT_BUILDERS.roleplayer
            _addHeaderParts(builder(tostring(rec.name), rec.timestampText, show_timestamps))
        end

        local hasEmote = body:find("%*[^*]+%*") ~= nil

        if not hasEmote then
            _addLine(body, nil, false)
        else

            for _, seg in ipairs(TC_ParseEmoteSegments(body)) do
                if seg.emote or seg.text:match("%S") then
                    _addLine(seg.text, seg.emote and CFG.EmoteColor or nil, seg.emote)
                end
            end
        end

        if rec.edited then
            _addLine(CFG.EditedSuffix, CFG.EditedColor, false)
        end

        return widgets
    end

    local function _rebuild_chat_display()
        _destroy_current_widgets()

        local prevName = nil
        local prevTimestampMs = nil

        for _, rec in ipairs(chat_messages) do
            local showName
            if rec.kind == "system" then
                showName = false
                prevName = nil
                prevTimestampMs = nil
            else
                local tooLongSince = prevTimestampMs ~= nil
                    and (rec.addedAtMs - prevTimestampMs) > (CFG.NameRepeatDelaySeconds * 1000)
                showName = (rec.name ~= prevName) or tooLongSince
                prevName = rec.name
                prevTimestampMs = rec.addedAtMs
            end

            local widgets = _render_message(rec, showName)
            for _, w in ipairs(widgets) do table.insert(current_widgets, w) end
        end

        Ext.Timer.WaitFor(1, function()
            pcall(function() text_parent:SetScroll({0.0, 99999999.0}) end)
        end)
    end

    local function _sync_hint_message_in_chat()
        if show_hint_message then
            for _, rec in ipairs(chat_messages) do
                if rec.kind == "system" and rec.raw == CONFIG.DefaultGreeting then
                    return
                end
            end
            table.insert(chat_messages, 1, { id = nil, name = nil, raw = CONFIG.DefaultGreeting, kind = "system", edited = false })
            _rebuild_chat_display()
        else
            local changed = false
            for i = #chat_messages, 1, -1 do
                local rec = chat_messages[i]
                if rec.kind == "system" and rec.raw == CONFIG.DefaultGreeting then
                    table.remove(chat_messages, i)
                    changed = true
                end
            end
            if changed then _rebuild_chat_display() end
        end
    end

    hint_message_checkbox.OnChange = function()
        show_hint_message = hint_message_checkbox.Checked
        _sync_hint_message_in_chat()
        _save_window_settings()
    end

    chat_format_combo.OnChange = function()
        chat_format = _index_to_chat_format(chat_format_combo.SelectedIndex)
        _rebuild_chat_display()
        _save_window_settings()
    end

    timestamps_checkbox.OnChange = function()
        show_timestamps = timestamps_checkbox.Checked
        _rebuild_chat_display()
        _save_window_settings()
    end

    local function _trim_old_messages()
        local overflow = #chat_messages - CFG.MaxKeptMessages
        if overflow <= 0 then return end

        for i = 1, overflow do
            local rec = table.remove(chat_messages, 1)
            if rec and rec.id ~= nil then chat_messages_by_id[rec.id] = nil end
        end
    end

    _add_chat_entry = function(id, name, rawBody, kind)
        local rec = {
            id = id, name = name, raw = rawBody, kind = kind, edited = false,
            addedAtMs = Ext.Utils.MonotonicTime(),

            timestampText = TC_FormatClockTimestamp(),
        }
        table.insert(chat_messages, rec)
        if id ~= nil then chat_messages_by_id[id] = rec end

        _trim_old_messages()
        _rebuild_chat_display()
        _touch_activity()
        return rec
    end

    _edit_chat_entry = function(id, newBody)
        local rec = chat_messages_by_id[id]
        if not rec then return end

        rec.raw = newBody
        rec.edited = true

        _rebuild_chat_display()
        _touch_activity()
    end

    _clear_chat_local = function()
        chat_messages = {}
        chat_messages_by_id = {}
        if show_hint_message then

            _add_chat_entry(nil, nil, CONFIG.DefaultGreeting, "system")
        else

            _rebuild_chat_display()
        end
    end

    local function _with_send_suppressed(fn)
        return function()
            suppress_send_on_deactivate = true
            fn()

            Ext.Timer.WaitForRealtime(500, function()
                suppress_send_on_deactivate = false
            end)
        end
    end

    clear_button_top.OnClick = _with_send_suppressed(_clear_chat_local)

    close_button_top.OnClick = _with_send_suppressed(function()
        chat_enabled = false
        input_active = false

        if settings_visible then _toggle_settings() end
        _apply_visibility()
        _apply_clickthrough()
    end)

    settings_button.OnClick = _with_send_suppressed(function() _toggle_settings() end)

    edit_button.OnClick = _with_send_suppressed(function() _begin_edit_last_message(true) end)

    open_key_button.OnClick = _with_send_suppressed(function()
        listening_for_open_key = true
        open_key_button.Label = "Press a key..."
    end)

    _apply_clickthrough = function()
        local show_chat = in_game and chat_enabled and (not game_ui_hidden) and (not chat_hidden_by_idle)

        if not show_chat then
            text_parent.NoInputs = true
            input_parent.NoInputs = true
            status_window.NoInputs = true
            settings_button_window.NoInputs = true
            return
        end

        text_parent.NoInputs = false
        input_parent.NoInputs = false
        status_window.NoInputs = false
        settings_button_window.NoInputs = false
    end

    _apply_visibility = function()
        local show_chat = in_game and chat_enabled and (not game_ui_hidden) and (not chat_hidden_by_idle)

        text_parent.Visible = show_chat
        input_parent.Visible = show_chat
        settings_button_window.Visible = show_chat
        move_mode_frame.Visible = show_chat and move_mode

        settings_panel.Visible = in_game and settings_visible and (not game_ui_hidden)

        _update_status_line()
        _apply_clickthrough()
    end

    _save_window_settings = function()
        if not settings_loaded then return end

        _clamp_to_screen()
        TC_SaveWindowSettings({
            WindowXPos = tonumber(chat_position[1]) or 0,
            WindowYPos = tonumber(chat_position[2]) or 0,
            WindowWidth = tonumber(chat_size[1]) or CONFIG.MinChatW,
            WindowHeight = tonumber(chat_size[2]) or CONFIG.MinChatH,
            GameWindowWidth = tonumber(cached_game_window_width) or 0,

            ActiveAlpha = active_alpha,
            InactiveAlpha = inactive_alpha,
            ShowTimestamps = show_timestamps,
            ShowHintMessage = show_hint_message,
            ChatFormat = chat_format,
            OpenKey = open_key,

            AutoHideEnabled = auto_hide_enabled,
            AutoHideDelaySeconds = auto_hide_delay,
            TypingNotificationsEnabled = typing_notifications_enabled,
            OverheadTextEnabled = overhead_text_enabled,
        })
    end

    _update_windows = function()
        _clamp_to_screen()

        settings_button_window:SetPos({
            chat_position[1] + chat_size[1] - TOP_BAR_W,
            (chat_position[2] - TOP_BAR_TOTAL_H) + CONFIG.ButtonYOffset
        })
        settings_button_window:SetSize({TOP_BAR_W, TOP_BAR_TOTAL_H})

        local screenW = select(1, _get_root_size()) or cached_game_window_width
        local chatCenterX = chat_position[1] + (chat_size[1] / 2)
        local dockOnLeft = chatCenterX > (screenW / 2)

        local settingsPanelX
        if dockOnLeft then
            settingsPanelX = chat_position[1] - SETTINGS_PANEL_W
        else
            settingsPanelX = chat_position[1] + chat_size[1]
        end

        settingsPanelX = math.max(settingsPanelX, CONFIG.ClampMargin)
        settingsPanelX = math.min(settingsPanelX, screenW - SETTINGS_PANEL_W - CONFIG.ClampMargin)

        local baseInputH = CFG.InputFirstLineHeightPx + (2 * INPUT_PAD)
        local settingsPanelH = chat_size[2] + TYPING_STATUS_H + baseInputH

        settings_panel:SetPos({settingsPanelX, chat_position[2]})
        settings_panel:SetSize({SETTINGS_PANEL_W, settingsPanelH})

        move_mode_frame:SetPos(chat_position)
        move_mode_frame:SetSize({chat_size[1], settingsPanelH})

        _update_dynamic_input_size(input.Text or "")

        local a = _current_alpha()
        text_parent:SetStyle("Alpha", a)
        input_parent:SetStyle("Alpha", a)
        status_window:SetStyle("Alpha", a)
        settings_button_window:SetStyle("Alpha", a)
    end

    _toggle_settings = function()
        settings_visible = not settings_visible
        listening_for_open_key = false

        pcall(function() settings_button:SetColor("Button", settings_visible and MENU_BUTTON_COLOR_OPEN or MENU_BUTTON_COLOR_CLOSED) end)

        if settings_visible then
            timestamps_checkbox.Checked = show_timestamps
            hint_message_checkbox.Checked = show_hint_message
            chat_format_combo.SelectedIndex = _chat_format_to_index(chat_format)
            overhead_text_checkbox.Checked = overhead_text_enabled
            auto_hide_checkbox.Checked = auto_hide_enabled
            typing_notif_checkbox.Checked = typing_notifications_enabled
            move_mode_checkbox.Checked = move_mode
            open_key_button.Label = "Current: " .. open_key
            pcall(function() active_alpha_slider.Value = {active_alpha, 0, 0, 0} end)
            pcall(function() inactive_alpha_slider.Value = {inactive_alpha, 0, 0, 0} end)
            pcall(function() auto_hide_delay_slider.Value = {auto_hide_delay, 0, 0, 0} end)

            _update_windows()
        else

            _touch_activity()
        end

        _apply_visibility()
    end

    _apply_move_mode = function()
        move_mode_frame.NoTitleBar = not move_mode
        move_mode_frame.NoMove = not move_mode
        move_mode_frame.NoResize = not move_mode

        move_mode_frame.NoInputs = not move_mode
        if move_mode then
            pcall(function() move_mode_frame.Label = "Text-Chat (drag to move/resize)" end)
        end
    end

    local function _sync_from_native_drag()
        if not move_mode then return end

        local ok, pos = pcall(function() return move_mode_frame.LastPosition end)
        local ok2, size = pcall(function() return move_mode_frame.LastSize end)
        if not ok or not ok2 or not pos or not size then return end

        local newX, newY = tonumber(pos[1]), tonumber(pos[2])
        local newFrameW, newFrameH = tonumber(size[1]), tonumber(size[2])
        if not newX or not newY or not newFrameW or not newFrameH then return end
        if newFrameW <= 0 or newFrameH <= 0 then return end

        local baseInputH = CFG.InputFirstLineHeightPx + (2 * INPUT_PAD)
        local newChatW = newFrameW
        local newChatH = newFrameH - TYPING_STATUS_H - baseInputH

        local changed = (newX ~= chat_position[1]) or (newY ~= chat_position[2])
            or (newChatW ~= chat_size[1]) or (newChatH ~= chat_size[2])
        if not changed then return end

        chat_position[1] = newX
        chat_position[2] = newY
        chat_size[1] = newChatW
        chat_size[2] = newChatH

        _apply_minimums()
        _update_windows()
        _save_window_settings()
    end

    Ext.Events.MouseButtonInput:Subscribe(function(event)
        if event.Pressed then
            last_mouse_press_ms = Ext.Utils.MonotonicTime()
        end
    end)

    Ext.Events.Tick:Subscribe(function(_)
        _sync_ui_hidden_from_root()

        if move_mode then
            _sync_from_native_drag()
        end

        if _prune_typing_users() then
            _update_status_line()
        end

        local someoneElseTyping = next(typing_users) ~= nil
        if in_game and chat_enabled and not game_ui_hidden and not settings_visible and not someoneElseTyping and auto_hide_enabled then
            local idle_seconds = (Ext.Utils.MonotonicTime() - last_activity_ms) / 1000.0
            local input_empty = (input.Text == nil or input.Text == "")
            local should_hide = (not input_active) and input_empty and (idle_seconds > auto_hide_delay)

            if should_hide ~= chat_hidden_by_idle then
                chat_hidden_by_idle = should_hide
                _apply_visibility()
            end
        end
    end)

    Ext.Events.KeyInput:Subscribe(function(event)
        if not in_game or game_ui_hidden then return end
        if not event.Pressed or event.Repeat then return end

        local keyName = tostring(event.Key)

        if listening_for_open_key then
            listening_for_open_key = false
            open_key = keyName
            open_key_button.Label = "Current: " .. open_key
            _save_window_settings()
            return
        end

        if keyName == open_key and not settings_visible and not input_active then
            chat_enabled = true
            _focus_input()
            return
        end

        if not chat_enabled or chat_hidden_by_idle then return end

        if keyName == "UP" and not input_active then
            _load_last_message_for_edit()
        end
    end)

    Ext.Events.NetMessage:Subscribe(function(event)
        if event.Channel ~= CHANNEL then return end

        local ok, data = pcall(function() return Ext.Json.Parse(event.Payload) end)
        if not ok or type(data) ~= "table" then return end

        if data.t == "msg" then
            _add_chat_entry(data.id, data.name, data.body, "msg")
        elseif data.t == "edit" then
            _edit_chat_entry(data.id, data.body)
            if my_last_message and my_last_message.id == data.id then
                my_last_message = { id = data.id, text = data.body }
            end
        elseif data.t == "system" then
            _add_chat_entry(nil, nil, data.body, "system")
        elseif data.t == "ack" then

            my_last_message = { id = data.id, text = data.body }
        elseif data.t == "typing" then

            if typing_notifications_enabled and data.name and data.name ~= "" then
                if data.on then
                    if typing_users[data.name] == nil then

                        chat_enabled = true
                        _touch_activity()
                        _apply_visibility()
                    end
                    typing_users[data.name] = Ext.Utils.MonotonicTime() + (CFG.TypingIndicatorTimeoutSeconds * 1000)
                else
                    typing_users[data.name] = nil
                    if next(typing_users) == nil then

                        _touch_activity()
                    end
                end
                _update_status_line()
            end
        elseif data.t == "oht" then

            local text = overhead_text_enabled and (data.body or "") or " "
            if text == "" then text = " " end
            pcall(function() Ext.Loca.UpdateTranslatedString(MSG_BUFFER_HANDLE, text) end)
        end
    end)

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

        active_alpha = tonumber(settings.ActiveAlpha) or CFG.DefaultActiveAlpha
        inactive_alpha = tonumber(settings.InactiveAlpha) or CFG.DefaultInactiveAlpha
        show_timestamps = settings.ShowTimestamps
        if settings.ShowHintMessage ~= nil then show_hint_message = settings.ShowHintMessage end
        if CHAT_FORMAT_BUILDERS[settings.ChatFormat] then chat_format = settings.ChatFormat end
        open_key = tostring(settings.OpenKey or CFG.DefaultOpenKey):upper()

        if settings.AutoHideEnabled ~= nil then auto_hide_enabled = settings.AutoHideEnabled end
        auto_hide_delay = tonumber(settings.AutoHideDelaySeconds) or auto_hide_delay
        if settings.TypingNotificationsEnabled ~= nil then typing_notifications_enabled = settings.TypingNotificationsEnabled end
        if settings.OverheadTextEnabled ~= nil then overhead_text_enabled = settings.OverheadTextEnabled end

        pcall(function() active_alpha_slider.Value = {active_alpha, 0, 0, 0} end)
        pcall(function() inactive_alpha_slider.Value = {inactive_alpha, 0, 0, 0} end)
        pcall(function() auto_hide_delay_slider.Value = {auto_hide_delay, 0, 0, 0} end)
        timestamps_checkbox.Checked = show_timestamps
        hint_message_checkbox.Checked = show_hint_message
        chat_format_combo.SelectedIndex = _chat_format_to_index(chat_format)
        overhead_text_checkbox.Checked = overhead_text_enabled
        auto_hide_checkbox.Checked = auto_hide_enabled
        typing_notif_checkbox.Checked = typing_notifications_enabled
        open_key_button.Label = "Current: " .. open_key

        _apply_move_mode()

        last_root_visible = nil
        _sync_ui_hidden_from_root()

        settings_loaded = true
        _touch_activity()

        if not initial_hint_shown then
            initial_hint_shown = true
            if show_hint_message then
                _add_chat_entry(nil, nil, CONFIG.DefaultGreeting, "system")
            end
        end

        _update_windows()
        _apply_visibility()
    end

    Ext.Events.GameStateChanged:Subscribe(function(event)
        if event.ToState == "PrepareRunning" then
            in_game = true
            _init_window_settings()
        elseif event.ToState == "UnloadLevel" then
            in_game = false
            if settings_loaded then _save_window_settings() end

            settings_visible = false
            pcall(function() settings_button:SetColor("Button", MENU_BUTTON_COLOR_CLOSED) end)
            listening_for_open_key = false
            input_active = false
            game_ui_hidden = true
            editing_message_id = nil
            cached_draft_text = nil
            typing_users = {}
            _apply_visibility()
        end
    end)
end)

if not ok_init then
    Ext.Utils.Print("[Text-Chat] Window init failed: " .. tostring(err))
    return
end

_G.__DEVCHAT_WINDOW_LOADED = true
