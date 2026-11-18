CHANNEL = "Text-Chat"
local WINDOW_SETTINGS_PATH = "Data/Text-Chat_Window-Settings.json"

MSG_BUFFER_HANDLE = "h7961f8f8g2753g4885gb843gbad96a0098d7"

local CFG = Ext.Require("Shared/Text-Chat_Config.lua")
local Lang = Ext.Require("Shared/Text-Chat_Lang.lua")

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

local function _safe_language(v, default)
    if type(v) == "string" and Lang.Strings[v] then return v end
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

        Language = _safe_language(save_data.Language, CFG.DefaultLanguage),
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

    save_data.Language = _safe_language(save_data.Language, CFG.DefaultLanguage)

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

function TC_SendRoll(kind, id, roll_type, tier, advantage, hidden)
    if not kind or not id or not tier then return end
    _post({
        t = "roll", kind = kind, id = id, rollType = roll_type or "active", tier = tier,
        adv = advantage and true or false,
        hidden = hidden and true or false,
    })
end

function TC_SendWho()
    _post({ t = "who" })
end

local UTF8_CHAR = "[\1-\127\194-\244][\128-\191]*"

local ACCENT_FOLD = {}
for base, accented in pairs({
    a = "àáâãäåā", c = "çćč", e = "èéêëēėę", i = "ìíîïī", n = "ñń", o = "òóôõöøō",
    u = "ùúûüū", y = "ýÿ", s = "śš", z = "źżž", l = "ł",
}) do
    for ch in accented:gmatch(UTF8_CHAR) do
        ACCENT_FOLD[ch] = base
    end
end

local function _sort_key(text)
    return (text:lower():gsub(UTF8_CHAR, function(ch) return ACCENT_FOLD[ch] or ch end))
end

function TC_GetSortedSkills()
    local T = Lang.T
    local sorted = {}
    for _, s in ipairs(CFG.DiceSkills) do table.insert(sorted, s) end
    table.sort(sorted, function(a, b) return _sort_key(T("skill." .. a.id)) < _sort_key(T("skill." .. b.id)) end)
    return sorted
end

local function _roll_result_text(r)
    local T = Lang.T
    local result = tonumber(r.result) or 0
    local crit = tonumber(r.crit) or 0
    if result == 2 then return T("dice.cancelled") end
    if crit == 1 then return T("dice.criticalSuccess") end
    if crit == 2 then return T("dice.criticalFailure") end
    return T(result == 1 and "dice.success" or "dice.failure")
end

function TC_FormatRoll(r)
    if type(r) ~= "table" then return "" end
    local T = Lang.T

    local title
    if r.kind == "ability" then
        title = T("check." .. tostring(r.id))
    else
        title = T("skill." .. tostring(r.id))
    end
    if r.adv then
        title = title .. " " .. T("dice.advantage")
    end

    return string.format("~ %s - %s - %s : %s ~",
        tostring(r.name), title, T("dice.dcValue", math.floor(tonumber(r.dc) or 0)), _roll_result_text(r))
end

function TC_FormatRollOverhead(r)
    if type(r) ~= "table" then return "" end
    local T = Lang.T
    local label = T((r.kind == "ability" and "ability." or "skill.") .. tostring(r.id))
    return T("dice.overhead", label, _roll_result_text(r))
end

Ext.Events.SessionLoaded:Subscribe(function() CFG.ResolveDiceDifficultyClasses() end)

function TC_GenerateLogFile(lines)
    local stamp = tostring(Ext.Timer.ClockTime()):gsub("[ %.:]", "-")
    local path = "Data/Logs/Text-Chat_Log_" .. stamp .. ".log"
    local ok, saved = pcall(function() return Ext.IO.SaveFile(path, table.concat(lines or {}, "\r\n")) end)
    if ok and saved ~= false then return path end
    return nil
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
