--[[
    Script: Exenye_ITEM - Move all selected items to same start position
    Author: Exenye
    Description: Align selected items vertically at same start position
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
--////////////                              FUNCTIONS                            \\\\\\\\\\\\
--======================================================================================

function main()
    -- Check if items are selected
    local item_count = reaper.CountSelectedMediaItems(0)
    if item_count == 0 then
        reaper.ShowMessageBox("No items selected!", "Error", 0)
        return
    end
    
    -- Start undo block
    reaper.Undo_BeginBlock()
    
    -- Get all selected items and their info
    local items = {}
    local first_item_start = nil
    local start_track_index = nil
    
    -- Collect all selected items
    for i = 0, item_count - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local item_track = reaper.GetMediaItem_Track(item)
        local track_index = reaper.GetMediaTrackInfo_Value(item_track, "IP_TRACKNUMBER")
        
        table.insert(items, {
            item = item,
            start = item_start,
            track = item_track,
            track_index = track_index
        })
        
        -- Use first item's start position as reference
        if i == 0 then
            first_item_start = item_start
            start_track_index = track_index
        end
    end
    
    -- Sort items by their current track position to maintain order
    table.sort(items, function(a, b) 
        return a.track_index < b.track_index 
    end)
    
    -- Process each item
    for i, item_info in ipairs(items) do
        local target_track_index = start_track_index + i - 1
        
        -- Create track if it doesn't exist
        local track_count = reaper.CountTracks(0)
        while track_count < target_track_index do
            reaper.InsertTrackAtIndex(track_count, false)
            track_count = track_count + 1
        end
        
        -- Get target track
        local target_track = reaper.GetTrack(0, target_track_index - 1)
        
        -- Move item to target track
        reaper.MoveMediaItemToTrack(item_info.item, target_track)
        
        -- Set item start position to match first item
        reaper.SetMediaItemInfo_Value(item_info.item, "D_POSITION", first_item_start)
    end
    
    -- Update arrangement and end undo block
    reaper.UpdateArrange()
    reaper.Undo_EndBlock("Align Items Vertically at Same Start Position", -1)
end

--======================================================================================
--////////////                             MAIN SCRIPT                           \\\\\\\\\\\\
--======================================================================================

-- Run the script
main()
