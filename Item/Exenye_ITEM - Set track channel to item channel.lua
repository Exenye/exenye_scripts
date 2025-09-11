--[[
    Script: Exenye_ITEM - Set track channel to item channel
    Author: Exenye
    Description: Set track channel count to match item channel count
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
--////////////                             MAIN SCRIPT                           \\\\\\\\\\\\
--======================================================================================

-- Begin undo block
reaper.Undo_BeginBlock()

-- Get number of selected media items
local num_items = reaper.CountSelectedMediaItems(0)

for i = 0, num_items - 1 do
    -- Get media item
    local item = reaper.GetSelectedMediaItem(0, i)
    if item ~= nil then
        -- Get active take
        local take = reaper.GetActiveTake(item)
        if take ~= nil then
            -- Get media source
            local source = reaper.GetMediaItemTake_Source(take)
            if source ~= nil then
                -- Get number of channels of the item
                local num_channels = reaper.GetMediaSourceNumChannels(source)
                -- Get associated track
                local track = reaper.GetMediaItemTrack(item)
                if track ~= nil then
                    -- Adjust channel count of track
                    reaper.SetMediaTrackInfo_Value(track, "I_NCHAN", num_channels)
                end
            end
        end
    end
end

-- Update arrangement
reaper.UpdateArrange()

-- End undo block
reaper.Undo_EndBlock("Adjust track channel count to item channel count", -1)
