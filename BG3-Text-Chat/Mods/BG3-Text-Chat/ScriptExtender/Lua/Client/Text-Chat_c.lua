
local MOD_UUID = "0fd00c41-58c8-4fe2-97cb-dc87a810ad94"
local CHANNEL = "Text-Chat"
local REFRESH_RATE = 50

local chat_width = 493 -- Not local

function TC_SendMessage(message) if message ~= "" then Ext.Net.PostMessageToServer(CHANNEL, message) end end

local function formatted_msg(msg)
    local pretty_msg = ""
    local max_characters_per_line = chat_width / 7

    local characters_in_current_line = 0
    for character in msg:gmatch('.') do
        characters_in_current_line = characters_in_current_line + TC_LenStringDisplay(character)

        if characters_in_current_line >= max_characters_per_line then
            local curr_character_line_index = pretty_msg:len()
            local prefix, suffix
            while pretty_msg:sub(curr_character_line_index, curr_character_line_index) ~= ' ' and pretty_msg:sub(curr_character_line_index, curr_character_line_index) ~= '\t' do
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
                prefix = pretty_msg:sub(0, pretty_msg:len() - 1)
                suffix = pretty_msg:sub(pretty_msg:len() - 1)

                prefix = prefix .. "-"
            end
            pretty_msg = prefix .. "\n\t" .. suffix .. character

            characters_in_current_line = 4 + TC_LenStringDisplay(suffix .. character)
        else pretty_msg = pretty_msg .. character
        end
    end
    return pretty_msg
end

--Ext.Events.KeyInput:Subscribe(function (event) if event.Event == "KeyUp" and event.Key == "RETURN" then TC_HandleEnterPressed() end end) -- Send message and clear out buffer.
--Ext.Events.NetMessage:Subscribe(function (event) if event.Channel == CHANNEL then Ext.Vars.GetModVariables(MOD_UUID).InBuf = event.Payload end end) -- Output all received Text-Chat messaages.
Ext.Events.NetMessage:Subscribe(function (event) if event.Channel == CHANNEL then TC_UpdateChat(formatted_msg(event.Payload)) end end) -- Output all received Text-Chat messaages.
--local session_handle
--session_handle = Ext.Events.SessionLoaded:Subscribe(function (event) Ext.Timer.WaitFor(REFRESH_RATE, _refresh_chat, REFRESH_RATE) Ext.Events.SessionLoaded:Unsubscribe(session_handle) end)