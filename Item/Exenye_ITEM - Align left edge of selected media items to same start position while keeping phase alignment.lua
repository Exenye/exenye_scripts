
--[[
    Script: EAlign Left Edges of Item Variations
    Author: Exenye
    Description: This script extends the left edge of items in each variation group
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
    local num_selected = reaper.CountSelectedMediaItems(0)
    if num_selected == 0 then
        reaper.ShowMessageBox("Please select the items you want to align.", "No Items Selected", 0)
        return
    end
    
    -- Start undo block
    reaper.Undo_BeginBlock()
    
    -- Get all selected items
    local items = {}
    for i = 0, num_selected - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        local start_time = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
        local track = reaper.GetMediaItem_Track(item)
        
        table.insert(items, {
            item = item,
            start_time = start_time,
            track = track
        })
    end
    
    -- Sort items by start time first
    table.sort(items, function(a, b) return a.start_time < b.start_time end)
    
    -- Group items by temporal overlap (variations)
    -- Items that overlap in time or are close belong to the same variation
    local silence_threshold = 0.5 -- 500ms of complete silence to separate variations
    local groups = {}
    local current_group = {}
    local current_group_end = 0
    
    for i, item_data in ipairs(items) do
        local item_start = item_data.start_time
        local item_length = reaper.GetMediaItemInfo_Value(item_data.item, "D_LENGTH")
        local item_end = item_start + item_length
        
        if i == 1 then
            -- First item starts the first group
            table.insert(current_group, item_data)
            current_group_end = item_end
        else
            -- Check if there's a gap between this item and the current group
            local gap = item_start - current_group_end
            
            if gap > silence_threshold then
                -- Complete silence gap - finish current group and start new one
                if #current_group > 0 then
                    table.insert(groups, current_group)
                end
                current_group = {item_data}
                current_group_end = item_end
            else
                -- No significant gap - add to current group and extend group end time
                table.insert(current_group, item_data)
                if item_end > current_group_end then
                    current_group_end = item_end
                end
            end
        end
    end
    
    -- Don't forget the last group
    if #current_group > 0 then
        table.insert(groups, current_group)
    end
    
    -- Process each group
    for _, group in ipairs(groups) do
        if #group > 1 then -- Only process groups with multiple items
            -- Find the leftmost (earliest) start time in this group
            local leftmost_time = group[1].start_time
            for _, item_data in ipairs(group) do
                if item_data.start_time < leftmost_time then
                    leftmost_time = item_data.start_time
                end
            end
            
            -- Align all items in this group to the leftmost position
            for _, item_data in ipairs(group) do
                local item = item_data.item
                local current_start = item_data.start_time
                
                if current_start > leftmost_time then
                    -- Calculate how much we need to extend to the left
                    local extension_amount = current_start - leftmost_time
                    
                    -- Get current item properties
                    local current_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
                    local take = reaper.GetActiveTake(item)
                    
                    if take then
                        -- Get current media source offset
                        local current_offset = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
                        
                        -- First, set the new position and length
                        reaper.SetMediaItemInfo_Value(item, "D_POSITION", leftmost_time)
                        reaper.SetMediaItemInfo_Value(item, "D_LENGTH", current_length + extension_amount)
                        
                        -- Now adjust the media source offset to compensate
                        -- The content should start playing at the same absolute time as before
                        -- So we subtract the extension amount from the offset
                        reaper.SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", current_offset - extension_amount)
                    else
                        -- For items without takes (like empty items), just extend
                        reaper.SetMediaItemInfo_Value(item, "D_POSITION", leftmost_time)
                        reaper.SetMediaItemInfo_Value(item, "D_LENGTH", current_length + extension_amount)
                    end
                end
            end
        end
    end
    
    -- Update the project
    reaper.UpdateArrange()
    reaper.Undo_EndBlock("Align Item Left Edges", -1)
    
    -- Show completion message
    reaper.ShowMessageBox("Successfully aligned " .. #groups .. " variation groups!", "Alignment Complete", 0)
end

-- Run the main function
main()
