if not Ext.IsClient() then
    return
end

if _G.__DEVCHAT_WINDOW_LOADED then
    return
end

local ok_init, err = pcall(function()
    local CFG = Ext.Require("Shared/Text-Chat_Config.lua")
    local Lang = Ext.Require("Shared/Text-Chat_Lang.lua")
    local T = Lang.T

    local CONFIG = {
        MinChatW = 360,
        MinChatH = 140,

        ButtonYOffset = 0,

        TopBarPad = 7,

        ClampMargin = 5,

        RefFrameH = 32,
    }

    local settings_loaded = false
    local initial_hint_shown = false
    local chat_enabled = true
    local settings_visible = false
    local dice_visible = false

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
    local current_input_h = CFG.InputFirstLineHeightPx + 24

    local metrics = {
        text_h = CFG.InputExtraLineHeightPx,
        frame_h = CFG.InputFirstLineHeightPx,
        edit_w = 46,
        topbar_w = 280,
        topbar_h = CFG.InputFirstLineHeightPx + (2 * CONFIG.TopBarPad),
    }

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

    local session_log = {}

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
    local _toggle_dice
    local _apply_language

    local i18n_bound = {}

    local function _label_of(spec)
        if type(spec) == "function" then return spec() end
        return T(spec)
    end

    local function _bind(widget, spec)
        table.insert(i18n_bound, { widget = widget, spec = spec })
        return widget
    end

    local function _apply_bound_labels()
        for _, b in ipairs(i18n_bound) do
            pcall(function() b.widget.Label = _label_of(b.spec) end)
        end
    end

    local function _add_text(parent, spec)
        local w = parent:AddText(_label_of(spec))
        pcall(function() w.TextWrapPos = 0 end)
        return _bind(w, spec)
    end

    local function _add_separator_text(parent, spec)
        return _bind(parent:AddSeparatorText(_label_of(spec)), spec)
    end

    local panel_full_width = {}
    local function _full_width(widget, is_button)
        table.insert(panel_full_width, { widget = widget, button = is_button and true or false })
        return widget
    end

    local function _system_text(rec)
        if rec.roll then return TC_FormatRoll(rec.roll) end
        if rec.key then
            if rec.arg ~= nil then return T(rec.key, rec.arg) end
            return T(rec.key)
        end
        return rec.raw or ""
    end

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

        local min_y = CONFIG.ClampMargin + metrics.topbar_h
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

    local EDIT_BUTTON_GAP = 12

    local function _edit_button_label()
        return T(editing_message_id ~= nil and "input.cancel" or "input.edit")
    end

    local edit_button = input_parent:AddButton(_edit_button_label())
    edit_button.SameLine = true
    _bind(edit_button, _edit_button_label)

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
    settings_button_window.NoInputs = false

    settings_button_window.AlwaysAutoResize = true
    settings_button_window:SetStyle("WindowMinSize", 1, 1)

    local function _new_probe(name)
        local w = Ext.IMGUI.NewWindow(name)
        w.NoTitleBar = true
        w.NoMove = true
        w.NoResize = true
        w.NoScrollbar = true
        w.NoNav = true
        w.NoInputs = true
        w.NoFocusOnAppearing = true
        w.NoBackground = true
        w.AlwaysAutoResize = true
        pcall(function() w.NoMouseInputs = true end)
        pcall(function() w.NoBringToFrontOnFocus = true end)
        w:SetStyle("WindowPadding", 0, 0)
        w:SetStyle("WindowMinSize", 1, 1)
        w:SetStyle("Alpha", 0.01)
        w:SetPos({0, 0})
        return w
    end

    local probe_text = _new_probe("Text-Chat_ProbeText")
    probe_text:AddText("Ag")
    local probe_frame = _new_probe("Text-Chat_ProbeFrame")
    probe_frame:AddButton("Ag")
    local probe_edit = _new_probe("Text-Chat_ProbeEdit")
    local probe_edit_button = _bind(probe_edit:AddButton(_edit_button_label()), _edit_button_label)

    local function _set_editing(id)
        editing_message_id = id
        local label = _edit_button_label()
        edit_button.Label = label
        probe_edit_button.Label = label
    end

    local MENU_BUTTON_COLOR_CLOSED = {0.3, 0.18, 0.09, 1.0}

    local MENU_BUTTON_COLOR_OPEN = {0.42, 0.28, 0.18, 1.0}

    local settings_button = _bind(settings_button_window:AddButton(T("top.menu")), "top.menu")
    pcall(function() settings_button:SetColor("Button", MENU_BUTTON_COLOR_CLOSED) end)
    local dice_button = _bind(settings_button_window:AddButton(T("top.dice")), "top.dice")
    dice_button.SameLine = true
    pcall(function() dice_button:SetColor("Button", MENU_BUTTON_COLOR_CLOSED) end)
    local clear_button_top = _bind(settings_button_window:AddButton(T("top.clear")), "top.clear")
    clear_button_top.SameLine = true

    local close_button_top = _bind(settings_button_window:AddButton(T("top.close")), "top.close")
    close_button_top.SameLine = true

    local SETTINGS_PANEL_W = 340
    local SETTINGS_PANEL_H = 520
    local PANEL_PAD_X = 14
    local SETTINGS_SCROLLBAR_MARGIN = 16

    local function _panel_w()
        return math.floor((SETTINGS_PANEL_W * math.max(metrics.frame_h / CONFIG.RefFrameH, 1.0)) + 0.5)
    end

    local function _panel_widget_w()
        return _panel_w() - (2 * PANEL_PAD_X) - SETTINGS_SCROLLBAR_MARGIN
    end

    local function _apply_panel_widths()
        local w = _panel_widget_w()
        for _, e in ipairs(panel_full_width) do
            e.widget.ItemWidth = w
            if e.button then
                pcall(function() e.widget.Size = {w, 0} end)
            end
        end
    end

    local function _new_side_panel(name)
        local p = Ext.IMGUI.NewWindow(name)
        p.NoTitleBar = true
        p.NoMove = true
        p.NoResize = true
        p.NoNav = true
        p.Visible = false
        p:SetSize({SETTINGS_PANEL_W, SETTINGS_PANEL_H})
        p:SetStyle("WindowPadding", PANEL_PAD_X, 12)
        p.NoScrollbar = false
        return p
    end

    local settings_panel = _new_side_panel("Text-Chat_Settings")
    local dice_panel = _new_side_panel("Text-Chat_Dice")

    local function _open_key_label()
        if listening_for_open_key then return T("settings.keyPress") end
        return T("settings.keyCurrent", open_key)
    end

    _add_separator_text(settings_panel, "settings.display")

    local move_mode_checkbox = _bind(settings_panel:AddCheckbox(T("settings.moveMode"), move_mode), "settings.moveMode")
    move_mode_checkbox.OnChange = function()
        move_mode = move_mode_checkbox.Checked
        _apply_move_mode()
        _apply_visibility()
    end

    local timestamps_checkbox = _bind(settings_panel:AddCheckbox(T("settings.timestamps"), show_timestamps), "settings.timestamps")

    local hint_message_checkbox = _bind(settings_panel:AddCheckbox(T("settings.hint"), show_hint_message), "settings.hint")

    local overhead_text_checkbox = _bind(settings_panel:AddCheckbox(T("settings.overhead"), overhead_text_enabled), "settings.overhead")
    overhead_text_checkbox.OnChange = function()
        overhead_text_enabled = overhead_text_checkbox.Checked
        _save_window_settings()
    end

    _add_text(settings_panel, "settings.opacityActive")
    local active_alpha_slider = settings_panel:AddSlider("##active_alpha", active_alpha, 0.1, 1.0)
    _full_width(active_alpha_slider)
    active_alpha_slider.OnChange = function()
        local ok, v = pcall(function() return active_alpha_slider.Value[1] end)
        if ok and v then active_alpha = v end
        _update_windows()
        _save_window_settings()
    end

    _add_text(settings_panel, "settings.opacityIdle")
    local inactive_alpha_slider = settings_panel:AddSlider("##inactive_alpha", inactive_alpha, 0.1, 1.0)
    _full_width(inactive_alpha_slider)
    inactive_alpha_slider.OnChange = function()
        local ok, v = pcall(function() return inactive_alpha_slider.Value[1] end)
        if ok and v then inactive_alpha = v end
        _update_windows()
        _save_window_settings()
    end

    _add_text(settings_panel, "settings.chatFormat")
    local chat_format_combo = settings_panel:AddCombo("##chat_format")
    _full_width(chat_format_combo)
    local function _fill_chat_format_options()
        chat_format_combo.Options = { T("format.classic"), T("format.modern"), T("format.discord"), T("format.roleplayer") }
    end
    _fill_chat_format_options()
    chat_format_combo.SelectedIndex = _chat_format_to_index(chat_format)

    _add_text(settings_panel, "settings.language")
    local language_combo = settings_panel:AddCombo("##language")
    _full_width(language_combo)
    local language_names = {}
    for _, l in ipairs(Lang.Languages) do table.insert(language_names, l.name) end
    language_combo.Options = language_names
    language_combo.SelectedIndex = (Lang.IndexOf(Lang.Current) or 1) - 1

    _add_separator_text(settings_panel, "settings.behavior")

    _add_text(settings_panel, "settings.openKey")
    local open_key_button = settings_panel:AddButton(_open_key_label())
    _bind(open_key_button, _open_key_label)
    _full_width(open_key_button, true)

    local typing_notif_checkbox = _bind(settings_panel:AddCheckbox(T("settings.typing"), typing_notifications_enabled), "settings.typing")
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

    local auto_hide_checkbox = _bind(settings_panel:AddCheckbox(T("settings.autoHide"), auto_hide_enabled), "settings.autoHide")
    auto_hide_checkbox.OnChange = function()
        auto_hide_enabled = auto_hide_checkbox.Checked
        if not auto_hide_enabled then _touch_activity() end
        _save_window_settings()
    end

    _add_text(settings_panel, "settings.autoHideDelay")
    local auto_hide_delay_slider = settings_panel:AddSliderInt("##auto_hide_delay", auto_hide_delay, 1, 60)
    _full_width(auto_hide_delay_slider)
    auto_hide_delay_slider.OnChange = function()
        local ok, v = pcall(function() return auto_hide_delay_slider.Value[1] end)
        if ok and v then auto_hide_delay = v end
        _save_window_settings()
    end

    _add_separator_text(settings_panel, "settings.tools")
    local generate_log_button = _bind(settings_panel:AddButton(T("settings.generateLog")), "settings.generateLog")
    _full_width(generate_log_button, true)

    local dice_character_name = ""
    local dice_last_who_ms = -999999
    local dice_skill_order = {}

    local function _dice_character_label()
        return T("dice.character", dice_character_name ~= "" and dice_character_name or "-")
    end

    local dice_character_text = _add_text(dice_panel, _dice_character_label)

    _add_text(dice_panel, "dice.rollType")
    local dice_type_combo = dice_panel:AddCombo("##dice_type")
    dice_type_combo.SelectedIndex = 0
    _full_width(dice_type_combo)

    local dice_adv_checkbox = _bind(dice_panel:AddCheckbox(T("dice.advantageOption"), false), "dice.advantageOption")

    _add_text(dice_panel, "dice.dc")
    local dice_dc_combo = dice_panel:AddCombo("##dice_dc")
    dice_dc_combo.SelectedIndex = CFG.DiceDefaultTierIndex - 1
    _full_width(dice_dc_combo)

    _add_separator_text(dice_panel, "dice.abilities")
    local dice_ability_combo = dice_panel:AddCombo("##dice_ability")
    dice_ability_combo.SelectedIndex = 0
    _full_width(dice_ability_combo)
    local dice_ability_button = _bind(dice_panel:AddButton(T("dice.rollAbility")), "dice.rollAbility")
    _full_width(dice_ability_button, true)

    _add_separator_text(dice_panel, "dice.skills")
    local dice_skill_combo = dice_panel:AddCombo("##dice_skill")
    dice_skill_combo.SelectedIndex = 0
    _full_width(dice_skill_combo)
    local dice_skill_button = _bind(dice_panel:AddButton(T("dice.rollSkill")), "dice.rollSkill")
    _full_width(dice_skill_button, true)

    local function _fill_dice_options()
        local type_index = dice_type_combo.SelectedIndex
        local dc_index = dice_dc_combo.SelectedIndex

        local type_options = {}
        for _, t in ipairs(CFG.DiceRollTypes) do table.insert(type_options, T("dice.type." .. t)) end
        dice_type_combo.Options = type_options

        local dc_options = {}
        for _, tier in ipairs(CFG.DiceDifficultyTiers) do
            table.insert(dc_options, T("dice.tierLabel", T("dice.tier." .. tier.id), tier.dc))
        end
        dice_dc_combo.Options = dc_options
        dice_type_combo.SelectedIndex = type_index
        dice_dc_combo.SelectedIndex = dc_index

        local ability_options = {}
        for _, a in ipairs(CFG.DiceAbilities) do table.insert(ability_options, T("ability." .. a.id)) end
        dice_ability_combo.Options = ability_options

        local selected = dice_skill_order[dice_skill_combo.SelectedIndex + 1]
        local selected_id = selected and selected.id or nil

        dice_skill_order = TC_GetSortedSkills()
        local skill_options, new_index = {}, 0
        for i, s in ipairs(dice_skill_order) do
            table.insert(skill_options, T("skill." .. s.id))
            if s.id == selected_id then new_index = i - 1 end
        end
        dice_skill_combo.Options = skill_options
        dice_skill_combo.SelectedIndex = new_index
    end
    _fill_dice_options()

    local INPUT_PAD = 12

    input_parent:SetStyle("WindowPadding", INPUT_PAD, INPUT_PAD)
    input_parent:SetStyle("ItemSpacing", EDIT_BUTTON_GAP, 4)

    local function _count_input_lines(text)
        local n = 1
        for _ in text:gmatch("\n") do n = n + 1 end
        return n
    end

    local function _first_line_h() return math.ceil(metrics.frame_h) + 1 end
    local function _extra_line_h() return math.max(math.ceil(metrics.text_h), 1) end
    local function _base_input_h() return _first_line_h() + (2 * INPUT_PAD) end
    local function _typing_h() return math.max(34, math.ceil(metrics.frame_h) + 2) end

    _update_dynamic_input_size = function(_)
        local field_w = math.max(chat_size[1] - (2 * INPUT_PAD) - math.ceil(metrics.edit_w) - EDIT_BUTTON_GAP, 80)

        local base_input_h = _base_input_h()
        local min_allowed_chat_h = math.max(CONFIG.MinChatH, chat_size[2] / 2)
        local max_extra_h = math.max(chat_size[2] - min_allowed_chat_h, 0)
        local max_extra_lines = math.floor(max_extra_h / _extra_line_h())
        local dynamicMaxLines = 1 + max_extra_lines

        local lineCount = math.min(_count_input_lines(input.Text or ""), dynamicMaxLines)
        local content_h = _first_line_h() + (lineCount - 1) * _extra_line_h()
        current_input_h = content_h + (2 * INPUT_PAD)

        pcall(function() input.SizeHint = {field_w, content_h} end)
        input.ItemWidth = field_w

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
            status_text.Label = T("status.typing", names[1])
        else

            status_text.Label = T("status.several")
        end

        current_status_h = _typing_h()
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

    local function _cancel_edit(refocus)
        if editing_message_id == nil then return end
        _set_editing(nil)

        local restored = cached_draft_text or ""
        cached_draft_text = nil

        suppress_next_change = true
        input.Text = restored
        last_seen_input_text = restored
        Ext.Timer.WaitFor(1, function() suppress_next_change = false end)
        _update_dynamic_input_size(restored)

        if last_typing_state_sent then
            TC_SendTyping(false)
            last_typing_state_sent = false
        end
        _update_status_line()
        _touch_activity()

        if refocus then _grant_real_focus() end
    end

    _submit_input = function()
        local text = input.Text or ""
        if text == "" then
            _cancel_edit(false)
            return
        end

        local wasEditing = (editing_message_id ~= nil)

        local sendText = text:gsub("%s*\n%s*", " ")

        sendText = sendText:gsub("^%s+", ""):gsub("%s+$", "")
        if sendText == "" then return end

        if editing_message_id ~= nil and my_last_message and sendText == my_last_message.text then
            _cancel_edit(false)
            return
        end

        if editing_message_id ~= nil then
            TC_SendEdit(editing_message_id, sendText)
            _set_editing(nil)
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

        _set_editing(my_last_message.id)
        local targetText = my_last_message.text

        suppress_next_change = true
        input.Text = targetText
        last_seen_input_text = targetText
        Ext.Timer.WaitFor(1, function() suppress_next_change = false end)
        _update_dynamic_input_size(targetText)
        _update_status_line()
        _touch_activity()

        if force then
            _grant_real_focus()
        end
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
            local text = _system_text(rec)
            local w = text_parent:AddText(text)
            pcall(function() w.TextWrapPos = 0 end)
            w:SetStyle("Alpha", 1)
            return { w }, text
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
            _addLine(T("chat.edited"), CFG.EditedColor, false)
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
                if rec.kind == "system" and rec.key == "chat.hint" then
                    return
                end
            end
            table.insert(chat_messages, 1, { id = nil, name = nil, key = "chat.hint", kind = "system", edited = false })
            _rebuild_chat_display()
        else
            local changed = false
            for i = #chat_messages, 1, -1 do
                local rec = chat_messages[i]
                if rec.kind == "system" and rec.key == "chat.hint" then
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

    _apply_language = function()
        _apply_bound_labels()
        _fill_chat_format_options()
        chat_format_combo.SelectedIndex = _chat_format_to_index(chat_format)
        _fill_dice_options()
        _apply_move_mode()
        _update_status_line()
        _rebuild_chat_display()
        _update_windows()
    end

    language_combo.OnChange = function()
        local l = Lang.Languages[language_combo.SelectedIndex + 1]
        if l and Lang.Set(l.code) then
            _apply_language()
            _save_window_settings()
        end
    end

    local function _trim_old_messages()
        local overflow = #chat_messages - CFG.MaxKeptMessages
        if overflow <= 0 then return end

        for i = 1, overflow do
            local rec = table.remove(chat_messages, 1)
            if rec and rec.id ~= nil then chat_messages_by_id[rec.id] = nil end
        end
    end

    _add_chat_entry = function(id, name, rawBody, kind, extra)
        local rec = {
            id = id, name = name, raw = rawBody, kind = kind, edited = false,
            addedAtMs = Ext.Utils.MonotonicTime(),

            timestampText = TC_FormatClockTimestamp(),
        }
        if extra then
            for k, v in pairs(extra) do rec[k] = v end
        end
        table.insert(chat_messages, rec)
        if not rec.nolog then table.insert(session_log, rec) end
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
            _add_chat_entry(nil, nil, nil, "system", { key = "chat.hint", nolog = true })
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
        if dice_visible then _toggle_dice() end
        _apply_visibility()
        _apply_clickthrough()
    end)

    settings_button.OnClick = _with_send_suppressed(function() _toggle_settings() end)
    dice_button.OnClick = _with_send_suppressed(function() _toggle_dice() end)

    local function _send_dice_roll(kind, def)
        if not def then return end
        _touch_activity()
        local tier = CFG.DiceDifficultyTiers[dice_dc_combo.SelectedIndex + 1]
        if not tier then return end
        TC_SendRoll(kind, def.id, CFG.DiceRollTypes[dice_type_combo.SelectedIndex + 1], tier.id, dice_adv_checkbox.Checked)
    end

    dice_ability_button.OnClick = _with_send_suppressed(function()
        _send_dice_roll("ability", CFG.DiceAbilities[dice_ability_combo.SelectedIndex + 1])
    end)

    dice_skill_button.OnClick = _with_send_suppressed(function()
        _send_dice_roll("skill", dice_skill_order[dice_skill_combo.SelectedIndex + 1])
    end)

    local function _on_dice_widget_change() _touch_activity() end
    dice_type_combo.OnChange = _on_dice_widget_change
    dice_adv_checkbox.OnChange = _on_dice_widget_change
    dice_dc_combo.OnChange = _on_dice_widget_change
    dice_ability_combo.OnChange = _on_dice_widget_change
    dice_skill_combo.OnChange = _on_dice_widget_change

    generate_log_button.OnClick = _with_send_suppressed(function()
        local lines = {}
        for _, rec in ipairs(session_log) do
            local text
            if rec.kind == "system" then
                text = _system_text(rec)
            else
                text = tostring(rec.name or "") .. ": " .. tostring(rec.raw or "")
                if rec.edited then text = text .. " " .. T("chat.edited") end
            end
            local ts = rec.timestampText
            if ts and ts ~= "" then text = "[" .. ts .. "] " .. text end
            table.insert(lines, text)
        end

        local path = TC_GenerateLogFile(lines)
        if path then
            _add_chat_entry(nil, nil, nil, "system", { key = "chat.logSaved", arg = path, nolog = true })
        else
            _add_chat_entry(nil, nil, nil, "system", { key = "chat.logFailed", nolog = true })
        end
    end)

    edit_button.OnClick = _with_send_suppressed(function()
        if editing_message_id ~= nil then
            _cancel_edit(true)
        else
            _begin_edit_last_message(true)
        end
    end)
    open_key_button.OnClick = _with_send_suppressed(function()
        listening_for_open_key = true
        open_key_button.Label = _open_key_label()
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
        dice_panel.Visible = in_game and dice_visible and (not game_ui_hidden)

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

            Language = Lang.Current,
        })
    end

    _update_windows = function()
        _clamp_to_screen()

        settings_button_window:SetPos({
            chat_position[1] + chat_size[1] - metrics.topbar_w - TOP_BAR_RIGHT_EXTRA,
            (chat_position[2] - metrics.topbar_h) + CONFIG.ButtonYOffset
        })

        local panelW = _panel_w()
        _apply_panel_widths()

        local screenW = select(1, _get_root_size()) or cached_game_window_width
        local chatCenterX = chat_position[1] + (chat_size[1] / 2)
        local dockOnLeft = chatCenterX > (screenW / 2)

        local settingsPanelX
        if dockOnLeft then
            settingsPanelX = chat_position[1] - panelW
        else
            settingsPanelX = chat_position[1] + chat_size[1]
        end

        settingsPanelX = math.max(settingsPanelX, CONFIG.ClampMargin)
        settingsPanelX = math.min(settingsPanelX, screenW - panelW - CONFIG.ClampMargin)

        local settingsPanelH = chat_size[2] + _typing_h() + _base_input_h()

        settings_panel:SetPos({settingsPanelX, chat_position[2]})
        settings_panel:SetSize({panelW, settingsPanelH})
        dice_panel:SetPos({settingsPanelX, chat_position[2]})
        dice_panel:SetSize({panelW, settingsPanelH})

        move_mode_frame:SetPos(chat_position)
        move_mode_frame:SetSize({chat_size[1], settingsPanelH})

        _update_dynamic_input_size(input.Text or "")

        local a = _current_alpha()
        text_parent:SetStyle("Alpha", a)
        input_parent:SetStyle("Alpha", a)
        status_window:SetStyle("Alpha", a)
        settings_button_window:SetStyle("Alpha", a)
    end

    local function _refresh_menu_button_colors()
        pcall(function() settings_button:SetColor("Button", settings_visible and MENU_BUTTON_COLOR_OPEN or MENU_BUTTON_COLOR_CLOSED) end)
        pcall(function() dice_button:SetColor("Button", dice_visible and MENU_BUTTON_COLOR_OPEN or MENU_BUTTON_COLOR_CLOSED) end)
    end

    _toggle_dice = function()
        dice_visible = not dice_visible

        if dice_visible then
            settings_visible = false
            listening_for_open_key = false
            open_key_button.Label = _open_key_label()
            dice_last_who_ms = -999999
            _update_windows()
        else
            _touch_activity()
        end

        _refresh_menu_button_colors()
        _apply_visibility()
    end

    _toggle_settings = function()
        settings_visible = not settings_visible
        listening_for_open_key = false
        if settings_visible then dice_visible = false end

        _refresh_menu_button_colors()

        if settings_visible then
            timestamps_checkbox.Checked = show_timestamps
            hint_message_checkbox.Checked = show_hint_message
            chat_format_combo.SelectedIndex = _chat_format_to_index(chat_format)
            overhead_text_checkbox.Checked = overhead_text_enabled
            auto_hide_checkbox.Checked = auto_hide_enabled
            typing_notif_checkbox.Checked = typing_notifications_enabled
            move_mode_checkbox.Checked = move_mode
            open_key_button.Label = _open_key_label()
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
            pcall(function() move_mode_frame.Label = T("move.title") end)
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

        local newChatW = newFrameW
        local newChatH = newFrameH - _typing_h() - _base_input_h()

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

    local function _read_size(w)
        local ok, size = pcall(function() return w.LastSize end)
        if not ok or not size then return nil, nil end
        local x, y = tonumber(size[1]), tonumber(size[2])
        if not x or not y or x <= 0 or y <= 0 then return nil, nil end
        return x, y
    end

    local function _poll_metrics()
        local changed = false
        local function update(key, value)
            if value and math.abs(value - metrics[key]) > 0.5 then
                metrics[key] = value
                changed = true
            end
        end

        local _, text_h = _read_size(probe_text)
        update("text_h", text_h)
        local _, frame_h = _read_size(probe_frame)
        update("frame_h", frame_h)
        local edit_w = _read_size(probe_edit)
        update("edit_w", edit_w)

        if settings_button_window.Visible then
            local bar_w, bar_h = _read_size(settings_button_window)
            update("topbar_w", bar_w)
            update("topbar_h", bar_h)
        end

        if changed then _update_windows() end
    end

    Ext.Events.Tick:Subscribe(function(_)
        _poll_metrics()

        _sync_ui_hidden_from_root()

        if in_game and dice_visible and (not game_ui_hidden) then
            local now_ms = Ext.Utils.MonotonicTime()
            if (now_ms - dice_last_who_ms) >= CFG.DiceWhoPollMs then
                dice_last_who_ms = now_ms
                TC_SendWho()
            end
        end

        if move_mode then
            _sync_from_native_drag()
        end

        if _prune_typing_users() then
            _update_status_line()
        end

        local someoneElseTyping = next(typing_users) ~= nil
        if in_game and chat_enabled and not game_ui_hidden and not settings_visible and not dice_visible and not someoneElseTyping and auto_hide_enabled then
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
            open_key_button.Label = _open_key_label()
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
            if data.key then
                _add_chat_entry(nil, nil, nil, "system", { key = data.key, arg = data.name })
            else
                _add_chat_entry(nil, nil, data.body, "system")
            end
        elseif data.t == "roll" then
            _add_chat_entry(nil, nil, nil, "system", { roll = data })
        elseif data.t == "who" then
            dice_character_name = (type(data.name) == "string") and data.name or ""
            dice_character_text.Label = _dice_character_label()
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
            local body = data.body or ""
            if type(data.roll) == "table" then body = TC_FormatRollOverhead(data.roll) end
            local text = overhead_text_enabled and body or " "
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

        Lang.Set(settings.Language)
        language_combo.SelectedIndex = (Lang.IndexOf(Lang.Current) or 1) - 1

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
        open_key_button.Label = _open_key_label()

        _apply_language()

        last_root_visible = nil
        _sync_ui_hidden_from_root()

        settings_loaded = true
        _touch_activity()

        if not initial_hint_shown then
            initial_hint_shown = true
            if show_hint_message then
                _add_chat_entry(nil, nil, nil, "system", { key = "chat.hint", nolog = true })
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
            dice_visible = false
            _refresh_menu_button_colors()
            listening_for_open_key = false
            input_active = false
            game_ui_hidden = true
            _set_editing(nil)
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
