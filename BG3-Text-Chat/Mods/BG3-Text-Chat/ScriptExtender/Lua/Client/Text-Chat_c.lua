
local MOD_UUID = "0fd00c41-58c8-4fe2-97cb-dc87a810ad94"
local POLLING_RATE = 50 -- In ms. The upper bound on the data's age is currently 82ms.
local CHANNEL = "Text-Chat"
local HANDSHAKE = "{'Command':'Handshake'}"

local user_id
local _rolling_ticker = 0
local _prev_message_buffer = ""

function TC_CommitMessage(header)
    header = header or {UserID=nil, UnsafeMode=false}

    if header.UserID then Ext.Vars.GetModVariables(MOD_UUID).ChatLog = "<" .. str(Ext..GetCurrentCharacter(header.UserID)) .. "> " .. Ext.Vars.GetModVariables(MOD_UUID).LocalMessageBuffer
    else Ext.Vars.GetModVariables(MOD_UUID).ChatLog = "<ADMIN> " .. Ext.Vars.GetModVariables(MOD_UUID).LocalMessageBuffer
    end
end

local function display_messages_to_screen()
    local new_message_buffer = Ext.Vars.GetModVariables(MOD_UUID).ChatLog
    
    if new_message_buffer ~= _prev_message_buffer then
        _P(Ext.Vars.GetModVariables(MOD_UUID).ChatLog)
        _prev_message_buffer = new_message_buffer
    end
end

local function _on_tick(tickEvent)
    _rolling_ticker = _rolling_ticker + tickEvent.Time.DeltaTime * 1000

    if _rolling_ticker >= POLLING_RATE then
        pcall(display_messages_to_screen)
        _rolling_ticker = 0
    end
end

local session_handle
session_handle = Ext.Events.SessionLoaded:Subscribe(function(event) Ext.Events.Tick:Subscribe(_on_tick) Ext.Events.SessionLoaded:Unsubscribe(session_handle) end)
Ext.Events.NetMessage:Subscribe(function (event) if event.Channel == CHANNEL and event.Payload == HANDSHAKE then user_id = event.UserID end end)
--Ext.Events.KeyInput:Subscribe(function (event) if event.Event == "KeyUp" and event.Key == "RETURN" then Ext.Net.PostMessageToServer(CHANNEL, Ext.Vars.GetModVariables(MOD_UUID).LocalMessageBuffer) end end)