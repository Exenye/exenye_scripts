--[[
    Script: Exenye_ITEM - Clone save item parameters
    Author: Exenye
    Description: Save relative item parameters including fades, stretch, pitch and length
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

-- Save Fade-In/Fade-Out relatively, including additional parameters
function save_relative_fade(slot)
    local item = reaper.GetSelectedMediaItem(0, 0)
    if item then
        local item_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")

        if save_fade then
            local fade_in_len = reaper.GetMediaItemInfo_Value(item, "D_FADEINLEN")
            local fade_out_len = reaper.GetMediaItemInfo_Value(item, "D_FADEOUTLEN")

            -- Calculate ratio of fade length to item length
            local fade_in_ratio = fade_in_len / item_length
            local fade_out_ratio = fade_out_len / item_length

            -- Get fade types
            local fade_in_shape = reaper.GetMediaItemInfo_Value(item, "C_FADEINSHAPE")
            local fade_out_shape = reaper.GetMediaItemInfo_Value(item, "C_FADEOUTSHAPE")

            -- Save ratios and types
            reaper.SetExtState("FadePresets", "Slot_"..slot.."_fadein_ratio", string.format("%.16f", fade_in_ratio), true)
            reaper.SetExtState("FadePresets", "Slot_"..slot.."_fadeout_ratio", string.format("%.16f", fade_out_ratio), true)
            reaper.SetExtState("FadePresets", "Slot_"..slot.."_fadein_shape", tostring(fade_in_shape), true)
            reaper.SetExtState("FadePresets", "Slot_"..slot.."_fadeout_shape", tostring(fade_out_shape), true)
        end

        if save_stretch then
            local playrate = reaper.GetMediaItemInfo_Value(item, "D_PLAYRATE")
            reaper.SetExtState("FadePresets", "Slot_"..slot.."_playrate", string.format("%.16f", playrate), true)
        end

        if save_pitch then
            local pitch = reaper.GetMediaItemInfo_Value(item, "D_PITCH")
            reaper.SetExtState("FadePresets", "Slot_"..slot.."_pitch", string.format("%.16f", pitch), true)
        end

        if save_length then
            -- Save item length
            reaper.SetExtState("FadePresets", "Slot_"..slot.."_item_length", string.format("%.16f", item_length), true)
        end

        -- Remove popup when saving
        -- reaper.ShowMessageBox("Saved", "Info", 0)
    else
        reaper.ShowMessageBox("No item selected.", "Error", 0)
    end
end

--======================================================================================
--////////////                             MAIN SCRIPT                           \\\\\\\\\\\\
--======================================================================================

-- Execute for slot 1
save_relative_fade(1)
