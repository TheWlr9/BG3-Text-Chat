local CHANNEL = "Text-Chat"
local WINDOW_SETTINGS_PATH = "Data/Text-Chat_Window-Settings.json"

local cached_window_width
local cached_game_window_width

function TC_DebugPrint(text) if TC_Debug then Ext.Utils.Print(text) end end

function TC_SetDebug(value) TC_Debug = value end

function TC_SaveWindowSettings(save_data)
    Ext.IO.SaveFile(WINDOW_SETTINGS_PATH, Ext.Json.Stringify(save_data))
    cached_window_width = save_data.WindowWidth
    cached_game_window_width = save_data.GameWindowWidth
end

function TC_LoadWindowSettings()
    local save_data = Ext.Json.Parse(Ext.IO.LoadFile(WINDOW_SETTINGS_PATH) or "{}")
    cached_window_width = save_data == {} and 0 or save_data.WindowWidth
    cached_game_window_width = save_data == {} and 1 or save_data.GameWindowWidth -- Don't default to 0 because we might get a DBZ error later.
    return save_data
end

function TC_SendMessage(message) if message ~= "" then Ext.Net.PostMessageToServer(CHANNEL, message) end end

local function formatted_msg(msg)
    local pretty_msg = ""
    local max_characters_per_line = cached_window_width / (7 * (cached_game_window_width / 1920))

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
            pretty_msg = prefix .. "\n\t\t" .. suffix .. character

            characters_in_current_line = 4 + TC_LenStringDisplay(suffix .. character)
        else pretty_msg = pretty_msg .. character
        end
    end
    return pretty_msg
end

Ext.Events.NetMessage:Subscribe(function (event) if event.Channel == CHANNEL then TC_UpdateChat(formatted_msg(event.Payload)) end end) -- Output all received Text-Chat messaages.