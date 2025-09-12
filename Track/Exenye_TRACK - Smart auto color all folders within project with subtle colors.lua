--[[
    Script: Harmonious Track Group Coloring
    Author: Exenye
    Description: Colors track folders and their children harmoniously. Parent folders are darker, children lighter same color. Non-grouped tracks stay gray.
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

-- Base color palette for folders (RGB values)
local FOLDER_COLORS = {
    {74, 144, 164},   -- Calm Blue
    {143, 188, 143},  -- Soft Green  
    {147, 112, 219},  -- Soft Purple
    {210, 180, 140},  -- Warm Beige
    {205, 133, 63},   -- Warm Brown
    {135, 206, 235},  -- Sky Blue
    {32, 178, 170},   -- Teal
    {255, 182, 193},  -- Light Pink
    {123, 104, 238},  -- Medium Slate Blue
    {144, 238, 144},  -- Light Green
    {240, 230, 140},  -- Khaki
    {255, 160, 122},  -- Light Salmon
    {176, 196, 222},  -- Light Steel Blue
    {221, 160, 221},  -- Plum
    {250, 240, 230},  -- Linen
    {188, 143, 143},  -- Rosy Brown
    {152, 251, 152},  -- Pale Green
    {255, 218, 185},  -- Peach Puff
    {175, 238, 238},  -- Pale Turquoise
    {255, 228, 181},  -- Moccasin
    {230, 230, 250},  -- Lavender
    {255, 239, 213},  -- Papaya Whip
    {176, 224, 230},  -- Powder Blue
    {255, 228, 225},  -- Misty Rose
    {245, 245, 220},  -- Beige
    {255, 240, 245},  -- Lavender Blush
    {240, 248, 255},  -- Alice Blue
    {248, 248, 255},  -- Ghost White
    {220, 220, 220},  -- Gainsboro
    {211, 211, 211}   -- Light Gray
}

local GRAY_COLOR = {128, 128, 128}  -- Gray for non-grouped tracks
local DARKEN_FACTOR = 0.1           -- How much darker parent should be (0.0 - 1.0)
local LIGHTEN_FACTOR = 0.1          -- How much lighter children should be (0.0 - 1.0)

--======================================================================================
--////////////                              FUNCTIONS                            \\\\\\\\\\\\
--======================================================================================

local function rgb_to_reaper_color(r, g, b)
    return r + (g * 256) + (b * 65536)
end

local function darken_color(r, g, b, factor)
    local new_r = math.max(0, r * (1 - factor))
    local new_g = math.max(0, g * (1 - factor))
    local new_b = math.max(0, b * (1 - factor))
    return math.floor(new_r), math.floor(new_g), math.floor(new_b)
end

local function lighten_color(r, g, b, factor)
    local new_r = math.min(255, r + (255 - r) * factor)
    local new_g = math.min(255, g + (255 - g) * factor)
    local new_b = math.min(255, b + (255 - b) * factor)
    return math.floor(new_r), math.floor(new_g), math.floor(new_b)
end

local function is_folder(track)
    local _, flags = reaper.GetTrackState(track)
    return (flags & 1) ~= 0
end

local function is_in_folder(track)
    local depth = reaper.GetTrackDepth(track)
    return depth > 0
end

local function get_folder_end(folder_start_idx)
    local folder_depth = reaper.GetTrackDepth(reaper.GetTrack(0, folder_start_idx))
    local num_tracks = reaper.CountTracks(0)
    
    for i = folder_start_idx + 1, num_tracks - 1 do
        local track = reaper.GetTrack(0, i)
        local depth = reaper.GetTrackDepth(track)
        
        if depth <= folder_depth then
            return i - 1
        end
    end
    
    return num_tracks - 1
end

local function no_undo()
    reaper.defer(function()end)
end

--======================================================================================
--////////////                             MAIN SCRIPT                           \\\\\\\\\\\\
--======================================================================================

local function colorize_track_groups()
    local num_tracks = reaper.CountTracks(0)
    if num_tracks == 0 then
        reaper.MB("No tracks found in project", "INFO", 0)
        no_undo()
        return
    end
    
    reaper.Undo_BeginBlock()
    reaper.PreventUIRefresh(1)
    
    local folder_color_index = 1
    local processed_tracks = {}
    local gray_color = rgb_to_reaper_color(GRAY_COLOR[1], GRAY_COLOR[2], GRAY_COLOR[3])
    
    -- Process all tracks
    for i = 0, num_tracks - 1 do
        if not processed_tracks[i] then
            local track = reaper.GetTrack(0, i)
            
            if is_folder(track) then
                -- Found folder - process it and all its children
                local folder_end = get_folder_end(i)
                local folder_depth = reaper.GetTrackDepth(track)
                
                -- Get base color for this folder
                local base_color = FOLDER_COLORS[folder_color_index]
                local base_r, base_g, base_b = base_color[1], base_color[2], base_color[3]
                
                -- Create darker color for parent folder
                local parent_r, parent_g, parent_b = darken_color(base_r, base_g, base_b, DARKEN_FACTOR)
                local parent_color = rgb_to_reaper_color(parent_r, parent_g, parent_b)
                
                -- Create lighter color for children (all children get same color)
                local child_r, child_g, child_b = lighten_color(base_r, base_g, base_b, LIGHTEN_FACTOR)
                local child_color = rgb_to_reaper_color(child_r, child_g, child_b)
                
                -- Color the parent folder
                reaper.SetTrackColor(track, parent_color)
                processed_tracks[i] = true
                
                -- Color all children with same lighter color
                for j = i + 1, folder_end do
                    if not processed_tracks[j] then
                        local child_track = reaper.GetTrack(0, j)
                        local child_depth = reaper.GetTrackDepth(child_track)
                        
                        if child_depth >= folder_depth + 1 then
                            -- This is a child track - give it the lighter color
                            reaper.SetTrackColor(child_track, child_color)
                            processed_tracks[j] = true
                        end
                    end
                end
                
                -- Move to next folder color
                folder_color_index = folder_color_index + 1
                if folder_color_index > #FOLDER_COLORS then 
                    folder_color_index = 1 
                end
                
            elseif not is_in_folder(track) then
                -- Single track not in any folder - color it gray
                reaper.SetTrackColor(track, gray_color)
                processed_tracks[i] = true
            end
        end
    end
    
    reaper.UpdateArrange()
    reaper.PreventUIRefresh(-1)
    reaper.Undo_EndBlock("Harmonious Track Group Coloring", -1)
    
end

-- Execute script
colorize_track_groups()
