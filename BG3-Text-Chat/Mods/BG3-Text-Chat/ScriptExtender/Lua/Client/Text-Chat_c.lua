CHANNEL = "Text-Chat"
local WINDOW_SETTINGS_PATH = "Data/Text-Chat_Window-Settings.json"
local MSG_BUFFER_HANDLE = "h7961f8f8g2753g4885gb843gbad96a0098d7"

local cached_window_width = 0
local cached_game_window_width = 1920

local cached_show_timestamps = false
local cached_font_scale = 1.0

local session_start_ms = nil

function TC_DebugPrint(text) if TC_Debug then Ext.Utils.Print(text) end end
function TC_SetDebug(value) TC_Debug = value end

function TC_LenStringDisplay(str)
    local count = 0
    for character in str:gmatch('.') do
        count = count + (character == '\t' and 4 or 1)
    end
    return count
end

function TC_ResetSessionClock()
    session_start_ms = Ext.Utils.MonotonicTime()
end

local function _safe_number(v, default)
    v = tonumber(v)
    if v == nil then return default end
    return v
end

local function _safe_bool(v, default)
    if type(v) == "boolean" then return v end
    if type(v) == "number" then return v ~= 0 end
    if type(v) == "string" then
        v = v:lower()
        if v == "true" or v == "1" then return true end
        if v == "false" or v == "0" then return false end
    end
    return default
end

local function _safe_string(v, default)
    if type(v) == "string" and v ~= "" then return v end
    return default
end

local function _get_root_width_fallback()
    if Ext.UI and Ext.UI.GetRoot then
        local gotUiRootObject, uiRootObject = pcall(function() return Ext.UI.GetRoot() end)
        if gotUiRootObject and uiRootObject then
            local gotProps, props = pcall(function() return uiRootObject:GetAllProperties(uiRootObject) end)
            if gotProps and props and props.ActualWidth then
                return tonumber(props.ActualWidth)
            end
        end
    end
    return nil
end

local function _now_ms()
    if Ext and Ext.Utils and Ext.Utils.MonotonicTime then
        return tonumber(Ext.Utils.MonotonicTime()) or 0
    end
    if Ext and Ext.Utils and Ext.Utils.GetTime then
        return tonumber(Ext.Utils.GetTime()) or 0
    end
    return 0
end

-- Formats a session-relative timestamp (T+MM:SS or T+H:MM:SS)
-- based on the time since the current game session started.
local function _format_session_timestamp()
    local ms = _now_ms()
    if session_start_ms == nil then
        session_start_ms = ms
    end
    local delta = math.max(0, ms - session_start_ms)

    local total_s = math.floor(delta / 1000)
    local h = math.floor(total_s / 3600)
    local m = math.floor((total_s % 3600) / 60)
    local s = total_s % 60

    if h > 0 then
        return string.format("[T+%d:%02d:%02d] ", h, m, s)
    else
        return string.format("[T+%02d:%02d] ", m, s)
    end
end

function TC_SaveWindowSettings(save_data)
    local cached_settings = {
        WindowXPos = _safe_number(save_data.WindowXPos, 0),
        WindowYPos = _safe_number(save_data.WindowYPos, 0),
        WindowWidth = _safe_number(save_data.WindowWidth, 493),
        WindowHeight = _safe_number(save_data.WindowHeight, 225),
        GameWindowWidth = _safe_number(save_data.GameWindowWidth, _get_root_width_fallback() or 1920),

        ActiveAlpha = _safe_number(save_data.ActiveAlpha, 0.9),
        InactiveAlpha = _safe_number(save_data.InactiveAlpha, 0.5),
        DragButton = _safe_number(save_data.DragButton, 2),

        ShowTimestamps = _safe_bool(save_data.ShowTimestamps, false),
        FontScale = _safe_number(save_data.FontScale, 1.0),

        EnterOpensChat = _safe_bool(save_data.EnterOpensChat, true),
        FocusKey = _safe_string(save_data.FocusKey, "RETURN"),
    }

    Ext.IO.SaveFile(WINDOW_SETTINGS_PATH, Ext.Json.Stringify(cached_settings))

    cached_window_width = cached_settings.WindowWidth
    cached_game_window_width = cached_settings.GameWindowWidth
    cached_show_timestamps = cached_settings.ShowTimestamps
    cached_font_scale = cached_settings.FontScale
end

function TC_LoadWindowSettings()
    local raw = Ext.IO.LoadFile(WINDOW_SETTINGS_PATH)
    local save_data = Ext.Json.Parse(raw or "{}")
    if type(save_data) ~= "table" then
        save_data = {}
    end

    local rootW = _get_root_width_fallback()

    cached_window_width = _safe_number(save_data.WindowWidth, 493) 
    cached_game_window_width = _safe_number(save_data.GameWindowWidth, rootW or 1920) -- Don't default to 0 because we might get a DBZ error later.

    cached_show_timestamps = _safe_bool(save_data.ShowTimestamps, false)
    cached_font_scale = _safe_number(save_data.FontScale, 1.0)

    save_data.WindowWidth = cached_window_width
    save_data.GameWindowWidth = cached_game_window_width
    save_data.ShowTimestamps = cached_show_timestamps
    save_data.FontScale = cached_font_scale

    save_data.EnterOpensChat = _safe_bool(save_data.EnterOpensChat, true)
    save_data.FocusKey = _safe_string(save_data.FocusKey, "RETURN")

    return save_data
end

function TC_SendMessage(message)
    if message ~= "" then
        Ext.Net.PostMessageToServer(CHANNEL, message)
    end
end

-- Wraps a chat message based on:
--  - Current chat window width
--  - Game window width (for DPI scaling)
--  - Font scale
--
-- Attempts to wrap at word boundaries and falls back to
-- forced hyphenation for very long words.
local function _wrap_message(msg)
    local w = _safe_number(cached_window_width, 493)
    local gw = _safe_number(cached_game_window_width, _get_root_width_fallback() or 1920)
    local fontScale = _safe_number(cached_font_scale, 1.0)
    if fontScale < 0.75 then fontScale = 0.75 end
    if fontScale > 2.0 then fontScale = 2.0 end

    local pretty_msg = ""
    local max_characters_per_line = (w / (7 * (gw / 1920))) / fontScale
    if max_characters_per_line < 10 then
        max_characters_per_line = 10
    end

    local characters_in_current_line = 0
    for character in msg:gmatch('.') do
        characters_in_current_line = characters_in_current_line + TC_LenStringDisplay(character)

        if characters_in_current_line >= max_characters_per_line then
            local curr_character_line_index = pretty_msg:len()
            local prefix, suffix

            while curr_character_line_index > 0
                and pretty_msg:sub(curr_character_line_index, curr_character_line_index) ~= ' '
                and pretty_msg:sub(curr_character_line_index, curr_character_line_index) ~= '\t'
            do
                curr_character_line_index = curr_character_line_index - 1
            end

            local i = curr_character_line_index - 1
            while i > 0 and pretty_msg:sub(i, i) ~= ' ' do
                i = i - 1
            end

            if i > 0 then
                prefix = pretty_msg:sub(0, curr_character_line_index)
                suffix = pretty_msg:sub(curr_character_line_index)
            else
                prefix = pretty_msg:sub(0, math.max(pretty_msg:len() - 1, 0))
                suffix = pretty_msg:sub(math.max(pretty_msg:len() - 1, 0))
                prefix = prefix .. "-"
            end

            pretty_msg = prefix .. "\n\t\t" .. suffix .. character
            characters_in_current_line = 4 + TC_LenStringDisplay(suffix .. character)
        else
            pretty_msg = pretty_msg .. character
        end
    end

    return pretty_msg
end

function TC_FormatChatMessage(payload)
    local prefix = ""
    if cached_show_timestamps then
        prefix = _format_session_timestamp()
    end
    return prefix .. _wrap_message(payload)
end

Ext.Events.NetMessage:Subscribe(function (event)
    if event.Channel == CHANNEL then
        if event.Payload:sub(1, 5) == "[OHT]" then -- Overhead text update command
            Ext.Loca.UpdateTranslatedString(MSG_BUFFER_HANDLE, event.Payload:sub(7, event.Payload:len()))
        else
            TC_UpdateChat(TC_FormatChatMessage(event.Payload)) -- Output all received Text-Chat messages.
        end
    end
end)