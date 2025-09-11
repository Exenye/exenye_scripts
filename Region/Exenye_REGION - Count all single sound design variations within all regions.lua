--[[
    Script: Exenye_REGION - Count all single sound design variations within all regions
    Author: Exenye
    Description: Count the number of items (variations) in each region on selected track and add markers with count at region start
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

-- No specific settings for this script

--======================================================================================
--////////////                              FUNCTIONS                            \\\\\\\\\\\\
--======================================================================================

function count_variations_in_regions()
    -- Get the number of project markers and regions
    local retval, num_markers, num_regions = reaper.CountProjectMarkers(0)
    local total_count = num_markers + num_regions
    
    -- Collect all regions
    local regions = {}
    for i = 0, total_count - 1 do
        local retval, is_region, pos, rgn_end, name, markrgnindexnumber = reaper.EnumProjectMarkers(i)
        if is_region then
            table.insert(regions, {start = pos, end_pos = rgn_end, name = name, index = markrgnindexnumber})
        end
    end
    
    if #regions == 0 then
        reaper.ShowMessageBox("No regions found in project.", "Error", 0)
        return
    end
    
    -- For each region, count the number of items on ALL tracks within the region
    for _, region in ipairs(regions) do
        local count = 0
        local num_tracks = reaper.CountTracks(0)
        
        -- Go through all tracks
        for track_idx = 0, num_tracks - 1 do
            local track = reaper.GetTrack(0, track_idx)
            local num_items = reaper.CountTrackMediaItems(track)
            
            for i = 0, num_items - 1 do
                local item = reaper.GetTrackMediaItem(track, i)
                local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
                local item_end = item_pos + item_len
                
                -- Improved overlap check: item overlaps with region if any part is inside
                -- An item overlaps if: item_start < region_end AND item_end > region_start
                local overlaps = (item_pos < region.end_pos) and (item_end > region.start)
                
                if overlaps then
                    count = count + 1
                end
            end
        end
        
        -- Add marker at the beginning of the region with the count
        local marker_name = tostring(count)
        reaper.AddProjectMarker(0, false, region.start, 0, marker_name, -1)
    end
    
    reaper.UpdateArrange()
    
    -- Markers added silently
end

--======================================================================================
--////////////                             MAIN SCRIPT                           \\\\\\\\\\\\
--======================================================================================

reaper.Undo_BeginBlock()
count_variations_in_regions()
reaper.Undo_EndBlock("Count variations in each region and add markers", -1)
