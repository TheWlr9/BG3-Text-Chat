local MOD_UUID = "0fd00c41-58c8-4fe2-97cb-dc87a810ad94"
local POLLING_RATE = 50 -- In ms. The upper bound on the data's age is currently 82ms.

TC_MessageBuffer = ""

local _rolling_ticker = 0
local _prev_message_buffer = ""

function TC_CommitMessage(header)
    header = header or {UserID=0, UnsafeMode=false}

    if not TC_MessageBuffer:match"\n$" then TC_MessageBuffer = TC_MessageBuffer .. '\n' end

    if header.UserID ~= 0 then Ext.Vars.GetModVariables(MOD_UUID).MessageBuffer = "<" .. str(GetCurrentCharacter(header.UserID)) .. "> " .. TC_MessageBuffer
    else Ext.Vars.GetModVariables(MOD_UUID).MessageBuffer = "<ADMIN> " .. TC_MessageBuffer
    end

    TC_MessageBuffer = "" -- Reset the message buffer.
end

function TC_AppendToMessage(string)
    TC_MessageBuffer = TC_MessageBuffer .. string
end

local function display_messages_to_screen()
    local new_message_buffer = Ext.Vars.GetModVariables(MOD_UUID).MessageBuffer
    
    if new_message_buffer ~= _prev_message_buffer then
        _P(Ext.Vars.GetModVariables(MOD_UUID).MessageBuffer)
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