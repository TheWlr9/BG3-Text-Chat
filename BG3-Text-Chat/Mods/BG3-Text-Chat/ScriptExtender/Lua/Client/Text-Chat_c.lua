CHANNEL = "Text-Chat"
local WINDOW_SETTINGS_PATH = "Data/Text-Chat_Window-Settings.json"

MSG_BUFFER_HANDLE = "h7961f8f8g2753g4885gb843gbad96a0098d7"

local CFG = Ext.Require("Shared/Text-Chat_Config.lua")

local BASELINE_GAME_WINDOW_WIDTH = 1920

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

local function _safe_chat_format(v, default)
    if v == "classic" or v == "modern" or v == "discord" or v == "roleplayer" then return v end
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

local function _format_clock_timestamp()
    local epoch = tonumber(Ext.Timer.ClockEpoch())
    if not epoch then return "" end
    if epoch > 1000000000000 then epoch = epoch / 1000 end

    local totalMinutesUtc = math.floor(epoch / 60)
    local minutesInDay = 24 * 60

    local localMinutes = totalMinutesUtc % minutesInDay
    if localMinutes < 0 then localMinutes = localMinutes + minutesInDay end

    local hh = math.floor(localMinutes / 60)
    local mm = localMinutes % 60
    return string.format("%02d:%02d", hh, mm)
end
TC_FormatClockTimestamp = _format_clock_timestamp

function TC_SaveWindowSettings(save_data)
    local cached_settings = {
        WindowXPos = _safe_number(save_data.WindowXPos, CFG.DefaultWindowXPos),
        WindowYPos = _safe_number(save_data.WindowYPos, CFG.DefaultWindowYPos),
        WindowWidth = _safe_number(save_data.WindowWidth, CFG.DefaultWindowWidth),
        WindowHeight = _safe_number(save_data.WindowHeight, CFG.DefaultWindowHeight),
        GameWindowWidth = _safe_number(save_data.GameWindowWidth, _get_root_width_fallback() or BASELINE_GAME_WINDOW_WIDTH),

        ActiveAlpha = _safe_number(save_data.ActiveAlpha, CFG.DefaultActiveAlpha),
        InactiveAlpha = _safe_number(save_data.InactiveAlpha, CFG.DefaultInactiveAlpha),

        ShowTimestamps = _safe_bool(save_data.ShowTimestamps, CFG.DefaultShowTimestamps),
        ShowHintMessage = _safe_bool(save_data.ShowHintMessage, CFG.DefaultShowHintMessage),
        ChatFormat = _safe_chat_format(save_data.ChatFormat, CFG.DefaultChatFormat),

        OpenKey = _safe_string(save_data.OpenKey, CFG.DefaultOpenKey),

        AutoHideEnabled = _safe_bool(save_data.AutoHideEnabled, CFG.DefaultAutoHideEnabled),
        AutoHideDelaySeconds = _safe_number(save_data.AutoHideDelaySeconds, CFG.AutoHideDelaySeconds),

        TypingNotificationsEnabled = _safe_bool(save_data.TypingNotificationsEnabled, CFG.DefaultTypingNotificationsEnabled),
        OverheadTextEnabled = _safe_bool(save_data.OverheadTextEnabled, CFG.DefaultOverheadTextEnabled),
    }

    Ext.IO.SaveFile(WINDOW_SETTINGS_PATH, Ext.Json.Stringify(cached_settings))
end

function TC_LoadWindowSettings()
    local raw = Ext.IO.LoadFile(WINDOW_SETTINGS_PATH)
    local save_data = Ext.Json.Parse(raw or "{}")
    if type(save_data) ~= "table" then save_data = {} end

    local rootW = _get_root_width_fallback()

    save_data.WindowXPos = _safe_number(save_data.WindowXPos, CFG.DefaultWindowXPos)
    save_data.WindowYPos = _safe_number(save_data.WindowYPos, CFG.DefaultWindowYPos)
    save_data.WindowWidth = _safe_number(save_data.WindowWidth, CFG.DefaultWindowWidth)
    save_data.WindowHeight = _safe_number(save_data.WindowHeight, CFG.DefaultWindowHeight)
    save_data.GameWindowWidth = _safe_number(save_data.GameWindowWidth, rootW or BASELINE_GAME_WINDOW_WIDTH)

    save_data.ActiveAlpha = _safe_number(save_data.ActiveAlpha, CFG.DefaultActiveAlpha)
    save_data.InactiveAlpha = _safe_number(save_data.InactiveAlpha, CFG.DefaultInactiveAlpha)

    save_data.ShowTimestamps = _safe_bool(save_data.ShowTimestamps, CFG.DefaultShowTimestamps)
    save_data.ShowHintMessage = _safe_bool(save_data.ShowHintMessage, CFG.DefaultShowHintMessage)
    save_data.ChatFormat = _safe_chat_format(save_data.ChatFormat, CFG.DefaultChatFormat)

    save_data.OpenKey = _safe_string(save_data.OpenKey, CFG.DefaultOpenKey)

    save_data.AutoHideEnabled = _safe_bool(save_data.AutoHideEnabled, CFG.DefaultAutoHideEnabled)
    save_data.AutoHideDelaySeconds = _safe_number(save_data.AutoHideDelaySeconds, CFG.AutoHideDelaySeconds)

    save_data.TypingNotificationsEnabled = _safe_bool(save_data.TypingNotificationsEnabled, CFG.DefaultTypingNotificationsEnabled)
    save_data.OverheadTextEnabled = _safe_bool(save_data.OverheadTextEnabled, CFG.DefaultOverheadTextEnabled)

    return save_data
end

local function _post(tbl)
    local ok, encoded = pcall(function() return Ext.Json.Stringify(tbl) end)
    if not ok or not encoded then return end
    Ext.Net.PostMessageToServer(CHANNEL, encoded)
end

function TC_SendMessage(message)
    if message == nil then return end
    if message == "" then return end
    _post({ t = "msg", body = message })
end

function TC_SendEdit(id, message)
    if id == nil or message == nil then return end
    if message == "" then return end
    _post({ t = "edit", id = id, body = message })
end

function TC_SendTyping(isTyping)
    _post({ t = "typing", on = isTyping and true or false })
end

function TC_ParseEmoteSegments(text)
    text = text or ""
    local segments = {}
    local pos = 1
    local len = #text

    while pos <= len do
        local s, e, inner = text:find("%*([^*]+)%*", pos)
        if not s then
            table.insert(segments, { text = text:sub(pos), emote = false })
            break
        end
        if s > pos then
            table.insert(segments, { text = text:sub(pos, s - 1), emote = false })
        end
        table.insert(segments, { text = "*" .. inner .. "*", emote = true })
        pos = e + 1
    end

    if #segments == 0 then
        table.insert(segments, { text = "", emote = false })
    end

    return segments
end
