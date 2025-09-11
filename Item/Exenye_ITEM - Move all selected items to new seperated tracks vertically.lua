--[[
    Script: Exenye_ITEM - Move all selected items to new seperated tracks vertically
    Author: Exenye
    Description: Move selected items to individual tracks and position them at cursor
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
    -- Get the number of selected items
    local num_selected_items = reaper.CountSelectedMediaItems(0)
    
    -- Check if there are any selected items
    if num_selected_items == 0 then
        reaper.ShowMessageBox("No items selected!", "Error", 0)
        return
    end
    
    -- Get current cursor position
    local cursor_pos = reaper.GetCursorPosition()
    
    -- Start undo block
    reaper.Undo_BeginBlock()
    
    -- Get all selected items and store them in a table
    local selected_items = {}
    for i = 0, num_selected_items - 1 do
        selected_items[i + 1] = reaper.GetSelectedMediaItem(0, i)
    end
    
    -- Get the current number of tracks
    local num_tracks = reaper.CountTracks(0)
    
    -- Process each selected item
    for i = 1, num_selected_items do
        local item = selected_items[i]
        
        -- Create a new track if needed
        local target_track_index = num_tracks + i - 1
        
        -- Insert new track if it doesn't exist
        while reaper.CountTracks(0) <= target_track_index do
            reaper.InsertTrackAtIndex(reaper.CountTracks(0), false)
        end
        
        -- Get the target track
        local target_track = reaper.GetTrack(0, target_track_index)
        
        -- Move item to the new track
        reaper.MoveMediaItemToTrack(item, target_track)
        
        -- Set item position to cursor position
        reaper.SetMediaItemPosition(item, cursor_pos, true)
        
        -- Optional: Set track name based on item name
        local take = reaper.GetActiveTake(item)
        if take then
            local take_name = reaper.GetTakeName(take)
            if take_name and take_name ~= "" then
                reaper.GetSetMediaTrackInfo_String(target_track, "P_NAME", take_name, true)
            else
                reaper.GetSetMediaTrackInfo_String(target_track, "P_NAME", "Item " .. i, true)
            end
        else
            reaper.GetSetMediaTrackInfo_String(target_track, "P_NAME", "Item " .. i, true)
        end
    end
    
    -- Update timeline and arrange view
    reaper.UpdateArrange()
    reaper.TrackList_AdjustWindows(false)
    
    -- End undo block
    reaper.Undo_EndBlock("Move selected items to separate tracks at cursor position", -1)
    
    -- Show completion message
    reaper.ShowMessageBox(num_selected_items .. " items moved to separate tracks at cursor position " .. string.format("%.3f", cursor_pos) .. "s", "Complete", 0)
end

--======================================================================================
--////////////                             MAIN SCRIPT                           \\\\\\\\\\\\
--======================================================================================

-- Run the main function
main()
