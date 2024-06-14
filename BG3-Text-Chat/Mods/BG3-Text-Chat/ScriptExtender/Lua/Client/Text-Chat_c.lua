
local MOD_UUID = "0fd00c41-58c8-4fe2-97cb-dc87a810ad94"
local CHANNEL = "Text-Chat"
local REFRESH_RATE = 50

local _prev_rcvd_msg = ""

function TC_SendMessage(message) if message ~= "" then Ext.Net.PostMessageToServer(CHANNEL, message) end end

local function _refresh_chat()
    local new_message = Ext.Vars.GetModVariables(MOD_UUID).InBuf

    if new_message and new_message ~= _prev_rcvd_msg and new_message then
        TC_UpdateChat(new_message)

        _prev_rcvd_msg = new_message
    end
end

--Ext.Events.KeyInput:Subscribe(function (event) if event.Event == "KeyUp" and event.Key == "RETURN" then Ext.Net.PostMessageToServer(CHANNEL, Ext.Vars.GetModVariables(MOD_UUID).OutBuf) Ext.Vars.GetModVariables(MOD_UUID).OutBuf = "" end end) -- Send message and clear out buffer.
--Ext.Events.NetMessage:Subscribe(function (event) if event.Channel == CHANNEL then Ext.Vars.GetModVariables(MOD_UUID).InBuf = event.Payload end end) -- Output all received Text-Chat messaages.
Ext.Events.NetMessage:Subscribe(function (event) if event.Channel == CHANNEL then TC_UpdateChat(event.Payload) end end) -- Output all received Text-Chat messaages.
--local session_handle
--session_handle = Ext.Events.SessionLoaded:Subscribe(function (event) Ext.Timer.WaitFor(REFRESH_RATE, _refresh_chat, REFRESH_RATE) Ext.Events.SessionLoaded:Unsubscribe(session_handle) end)