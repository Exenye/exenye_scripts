--[[
    Script: Exenye_REGION - Expand all regions by custom amount
    Author: Exenye
    Description: Expands all regions by a custom amount of milliseconds at start and end
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

-- Default values (can be overridden by user input)
local default_start_ms = 100
local default_end_ms = 100

--======================================================================================
--////////////                              FUNCTIONS                            \\\\\\\\\\\\
--======================================================================================

function expand_all_regions(start_ms, end_ms)
    -- Convert milliseconds to seconds
    local start_seconds = start_ms / 1000
    local end_seconds = end_ms / 1000
    
    -- Get number of markers/regions in project
    local num_markers = reaper.CountProjectMarkers(0)
    
    -- Counter for modified regions
    local modified_regions = 0
    
    -- Iterate through all markers and regions
    for i = 0, num_markers - 1 do
        local retval, isrgn, pos, rgnend, name, markrgnindexnumber, color = reaper.EnumProjectMarkers3(0, i)
        
        -- Check if it's a region (not a marker)
        if isrgn then
            -- Calculate new start and end positions
            local new_pos = pos - start_seconds
            local new_end = rgnend + end_seconds
            
            -- Ensure start position doesn't go negative
            if new_pos < 0 then
                new_pos = 0
            end
            
            -- Update region
            reaper.SetProjectMarkerByIndex(0, i, isrgn, new_pos, new_end, markrgnindexnumber, name, color)
            
            modified_regions = modified_regions + 1
        end
    end
    
    return modified_regions
end

function get_user_input()
    -- Get saved values from previous run
    local saved_start = reaper.GetExtState("ExpandRegions", "start_ms")
    local saved_end = reaper.GetExtState("ExpandRegions", "end_ms")
    
    local start_ms = saved_start ~= "" and tonumber(saved_start) or default_start_ms
    local end_ms = saved_end ~= "" and tonumber(saved_end) or default_end_ms
    
    -- Create input dialog
    local retval, user_input = reaper.GetUserInputs(
        "Expand All Regions", 
        2, 
        "Start expansion (ms):,End expansion (ms):", 
        start_ms .. "," .. end_ms
    )
    
    if not retval then
        return nil, nil -- User cancelled
    end
    
    -- Parse input
    local start_str, end_str = user_input:match("([^,]*),([^,]*)")
    start_ms = tonumber(start_str)
    end_ms = tonumber(end_str)
    
    -- Validate input
    if not start_ms or not end_ms then
        reaper.ShowMessageBox("Invalid input. Please enter valid numbers.", "Error", 0)
        return nil, nil
    end
    
    if start_ms < 0 or end_ms < 0 then
        reaper.ShowMessageBox("Values cannot be negative.", "Error", 0)
        return nil, nil
    end
    
    -- Save values for next time
    reaper.SetExtState("ExpandRegions", "start_ms", tostring(start_ms), true)
    reaper.SetExtState("ExpandRegions", "end_ms", tostring(end_ms), true)
    
    return start_ms, end_ms
end

--======================================================================================
--////////////                             MAIN SCRIPT                           \\\\\\\\\\\\
--======================================================================================

-- Start undo block
reaper.Undo_BeginBlock()

-- Get user input for expansion amounts
local start_ms, end_ms = get_user_input()

if start_ms and end_ms then
    -- Execute expansion
    local modified_count = expand_all_regions(start_ms, end_ms)
    
    
    -- Update arrange view
    reaper.UpdateArrange()
end

-- End undo block
reaper.Undo_EndBlock("Expand all regions by custom amount", -1)
