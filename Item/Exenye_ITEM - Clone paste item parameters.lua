--[[
    Script: Exenye_ITEM - Clone paste item parameters
    Author: Exenye
    Description: Apply saved relative item parameters including fades, stretch, pitch and length
    Version: 1.0
    
    This script is free to use, modify and distribute.
    If you want to get updates or support my work, check out my new ko-fi:
    https://ko-fi.com/exenye

    If you have an issue or want to reach out, just write me on my contact form on my website:
    https://exenye.com/

    My reaper forum profile:
    https://forum.cockos.com/member.php?u=165083

]]

--======================================================================================
--////////////                              SETTINGS                             \\\\\\\\\\\\
--======================================================================================

local save_fade = true
local save_stretch = true
local save_pitch = true
local save_length = true

--======================================================================================
--////////////                              FUNCTIONS                            \\\\\\\\\\\\
--======================================================================================

-- Apply saved relative data including additional parameters
function load_relative_fade(slot)
    -- Number of selected items
    local num_items = reaper.CountSelectedMediaItems(0)
    if num_items > 0 then
        -- Retrieve saved values
        local saved_item_length_str = reaper.GetExtState("FadePresets", "Slot_"..slot.."_item_length")
        local saved_item_length = tonumber(((saved_item_length_str or ""):gsub(",", ".")))

        local fade_in_ratio_str = reaper.GetExtState("FadePresets", "Slot_"..slot.."_fadein_ratio")
        local fade_out_ratio_str = reaper.GetExtState("FadePresets", "Slot_"..slot.."_fadeout_ratio")
        local fade_in_shape_str = reaper.GetExtState("FadePresets", "Slot_"..slot.."_fadein_shape")
        local fade_out_shape_str = reaper.GetExtState("FadePresets", "Slot_"..slot.."_fadeout_shape")

        local fade_in_ratio = tonumber(((fade_in_ratio_str or ""):gsub(",", ".")))
        local fade_out_ratio = tonumber(((fade_out_ratio_str or ""):gsub(",", ".")))
        local fade_in_shape = tonumber(fade_in_shape_str)
        local fade_out_shape = tonumber(fade_out_shape_str)

        local playrate_str = reaper.GetExtState("FadePresets", "Slot_"..slot.."_playrate")
        local playrate = tonumber(((playrate_str or ""):gsub(",", ".")))

        local pitch_str = reaper.GetExtState("FadePresets", "Slot_"..slot.."_pitch")
        local pitch = tonumber(((pitch_str or ""):gsub(",", ".")))

        for i = 0, num_items - 1 do
            local item = reaper.GetSelectedMediaItem(0, i)
            if item then
                if save_length and saved_item_length then
                    -- Apply saved item length
                    reaper.SetMediaItemInfo_Value(item, "D_LENGTH", saved_item_length)
                end

                -- After setting length, get the new item length
                local item_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

                if save_fade and fade_in_ratio and fade_out_ratio and fade_in_shape and fade_out_shape then
                    -- Calculate new fades based on item length
                    local fade_in_len = fade_in_ratio * item_length
                    local fade_out_len = fade_out_ratio * item_length

                    -- Apply fades and types
                    reaper.SetMediaItemInfo_Value(item, "D_FADEINLEN", fade_in_len)
                    reaper.SetMediaItemInfo_Value(item, "D_FADEOUTLEN", fade_out_len)
                    reaper.SetMediaItemInfo_Value(item, "C_FADEINSHAPE", fade_in_shape)
                    reaper.SetMediaItemInfo_Value(item, "C_FADEOUTSHAPE", fade_out_shape)
                end

                if save_stretch and playrate then
                    reaper.SetMediaItemInfo_Value(item, "D_PLAYRATE", playrate)
                end

                if save_pitch and pitch then
                    reaper.SetMediaItemInfo_Value(item, "D_PITCH", pitch)
                end
            end
        end
        reaper.UpdateArrange()
    else
        reaper.ShowMessageBox("No item selected.", "Error", 0)
    end
end

--======================================================================================
--////////////                             MAIN SCRIPT                           \\\\\\\\\\\\
--======================================================================================

-- Execute for slot 1
load_relative_fade(1)
