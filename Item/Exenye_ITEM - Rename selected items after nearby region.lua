--[[
    Script: Exenye_ITEM - Rename selected items after nearby region
    Author: Exenye
    Description: Rename selected items based on their nearby region names
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

function GetRegionNameAtPosition(position)
    local marker_count, region_count = reaper.CountProjectMarkers(0)
    local total_count = marker_count + region_count
    
    -- Iterate through all markers and regions
    for i = 0, total_count - 1 do
        local retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(i)
        
        -- Only consider regions (not markers)
        if isrgn then
            -- Check if position is within the region
            if position >= pos and position <= rgnend then
                return name
            end
        end
    end
    
    -- If no region found, search for the nearest region
    return GetNearestRegionName(position)
end

function GetNearestRegionName(position)
    local marker_count, region_count = reaper.CountProjectMarkers(0)
    local total_count = marker_count + region_count
    
    local nearest_region = nil
    local nearest_distance = math.huge
    
    -- Iterate through all markers and regions
    for i = 0, total_count - 1 do
        local retval, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(i)
        
        -- Only consider regions
        if isrgn then
            -- Calculate distance to region
            local distance
            if position < pos then
                distance = pos - position
            elseif position > rgnend then
                distance = position - rgnend
            else
                distance = 0
            end
            
            -- Update nearest region
            if distance < nearest_distance then
                nearest_distance = distance
                nearest_region = name
            end
        end
    end
    
    return nearest_region
end

function rename_selected_items()
    -- Get number of selected items
    local item_count = reaper.CountSelectedMediaItems(0)
    
    if item_count == 0 then
        reaper.ShowMessageBox("No items selected!", "Error", 0)
        return
    end
    
    local renamed_count = 0
    
    -- Iterate through all selected items
    for i = 0, item_count - 1 do
        local item = reaper.GetSelectedMediaItem(0, i)
        
        if item then
            -- Get item position and length
            local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
            local item_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
            local item_center = item_pos + (item_length / 2) -- Center point of item
            
            -- Find region for this item
            local region_name = GetRegionNameAtPosition(item_center)
            
            if region_name and region_name ~= "" then
                -- Rename all takes of the item
                local take_count = reaper.CountTakes(item)
                for t = 0, take_count - 1 do
                    local take = reaper.GetTake(item, t)
                    if take then
                        reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", region_name, true)
                        renamed_count = renamed_count + 1
                    end
                end
            end
        end
    end
    
    -- Update arrange view
    reaper.UpdateArrange()
end

--======================================================================================
--////////////                             MAIN SCRIPT                           \\\\\\\\\\\\
--======================================================================================

-- Start undo block
reaper.Undo_BeginBlock()

-- Execute the renaming
rename_selected_items()

-- End undo block
reaper.Undo_EndBlock("Rename items after regions", -1)
