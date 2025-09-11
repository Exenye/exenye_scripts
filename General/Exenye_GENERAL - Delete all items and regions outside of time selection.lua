--[[
    Script: Exenye_GENERAL - Delete all items and regions outside of time selection
    Author: Exenye
    Description: Crop to time selection, keep original positions
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

local RemoveTimeSel = true -- true / false - Remove time selection after crop

local FADE = -1
        -- = < 0 fade in/out default (depends on REAPER settings)
        -- = Otherwise set in milliseconds

--======================================================================================
--////////////                              FUNCTIONS                            \\\\\\\\\\\\
--======================================================================================

local function compare(x,y)
    local floatShare = 0.0000001
    return math.abs(x-y) < floatShare
end

local function CropRegionsAndMarkers(startTime, endTime)
    local retval, num_markers, num_regions = reaper.CountProjectMarkers(0)
    
    -- Collect all markers/regions to delete and trim
    local toDelete = {}
    
    for i = retval-1, 0, -1 do -- Backwards to avoid index corruption
        local retval_, isrgn, pos, rgnend, name, markrgnindexnumber = reaper.EnumProjectMarkers(i)
        
        if isrgn == true then -- Region
            if rgnend <= startTime or pos >= endTime then
                -- Region completely outside - delete
                reaper.DeleteProjectMarker(0, markrgnindexnumber, true)
            elseif pos < startTime and rgnend > startTime then
                -- Region overlaps at start - trim it (new start position = startTime)
                local newEnd = math.min(rgnend, endTime)
                reaper.SetProjectMarker(markrgnindexnumber, true, startTime, newEnd, name)
            elseif pos < endTime and rgnend > endTime then
                -- Region overlaps at end - trim it (new end position = endTime)
                reaper.SetProjectMarker(markrgnindexnumber, true, pos, endTime, name)
            end
            -- Regions completely inside remain unchanged
        else -- Marker
            if pos < startTime or pos >= endTime then
                -- Marker outside - delete
                reaper.DeleteProjectMarker(0, markrgnindexnumber, false)
            end
            -- Markers inside remain unchanged
        end
    end
end

local function SelAllAutoItems(Sel)
    for i = 1, reaper.CountTracks(0) do
        local track = reaper.GetTrack(0, i-1)
        for i2 = 1, reaper.CountTrackEnvelopes(track) do
            local TrackEnv = reaper.GetTrackEnvelope(track, i2-1)
            for i3 = 1, reaper.CountAutomationItems(TrackEnv) do
                reaper.GetSetAutomationItemInfo(TrackEnv, i3-1, "D_UISEL", Sel, 1)
            end
        end
    end
end

local function no_undo()
    reaper.defer(function()end)
end

--======================================================================================
--////////////                             MAIN SCRIPT                           \\\\\\\\\\\\
--======================================================================================

-- Main script starts here
local Start, End = reaper.GetSet_LoopTimeRange(0, 0, 0, 0, 0)
if compare(Start, End) then 
    reaper.MB("No Time Selected", "ERROR", 0)
    no_undo()
    return 
end

local countTrack = reaper.CountTracks(0)
if countTrack == 0 then 
    no_undo()
    return 
end

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

-- Save cursor position
local Cur = reaper.GetCursorPosition()

-- Crop regions and markers
CropRegionsAndMarkers(Start, End)

SelAllAutoItems(0)

-- Go through all tracks
for t = 1, countTrack do
    local track = reaper.GetTrack(0, t-1)
    
    -- Process items
    local CountTrItem = reaper.CountTrackMediaItems(track)
    for i = CountTrItem-1, 0, -1 do
        local Item = reaper.GetTrackMediaItem(track, i)
        local positi = reaper.GetMediaItemInfo_Value(Item, "D_POSITION")
        local length = reaper.GetMediaItemInfo_Value(Item, "D_LENGTH")
        local itemEnd = positi + length
        
        if itemEnd <= Start or positi >= End then
            -- Item completely outside selection - delete
            reaper.DeleteTrackMediaItem(track, Item)
        elseif positi < Start and itemEnd > Start then
            -- Item overlaps at start - trim from left
            local take = reaper.GetActiveTake(Item)
            if take then
                local sourceOffset = reaper.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
                reaper.SetMediaItemTakeInfo_Value(take, "D_STARTOFFS", sourceOffset + (Start - positi))
            end
            
            -- Set new position and length
            local newLength = math.min(itemEnd - Start, End - Start)
            reaper.SetMediaItemInfo_Value(Item, "D_POSITION", Start)
            reaper.SetMediaItemInfo_Value(Item, "D_LENGTH", newLength)
            
            -- Set fade in if desired
            if tonumber(FADE) and FADE >= 0 then
                reaper.SetMediaItemInfo_Value(Item, "D_FADEINLEN", FADE/1000)
            end
            
        elseif positi < End and itemEnd > End then
            -- Item overlaps at end - trim from right
            local newLength = End - positi
            reaper.SetMediaItemInfo_Value(Item, "D_LENGTH", newLength)
            
            -- Set fade out if desired
            if tonumber(FADE) and FADE >= 0 then
                reaper.SetMediaItemInfo_Value(Item, "D_FADEOUTLEN", FADE/1000)
            end
        end
        -- Items completely inside remain unchanged
    end
    
    -- Process automation/envelopes
    local CountTrEnv = reaper.CountTrackEnvelopes(track)
    for i = 1, CountTrEnv do
        local TrackEnv = reaper.GetTrackEnvelope(track, i-1)
        reaper.SetCursorContext(2, TrackEnv)
        
        -- Delete all points outside time selection
        -- First all points before selection
        if Start > 0 then
            reaper.GetSet_LoopTimeRange(1, 0, 0, Start, 0)
            reaper.Main_OnCommand(40089, 0) -- Delete all points in time selection
        end
        
        -- Then all points after selection until project end
        local projectLength = reaper.GetProjectLength(0)
        if End < projectLength then
            reaper.GetSet_LoopTimeRange(1, 0, End, projectLength, 0)
            reaper.Main_OnCommand(40089, 0) -- Delete all points in time selection
        end
        
        -- Process automation items
        for i3 = reaper.CountAutomationItems(TrackEnv), 1, -1 do
            local posAutoIt = reaper.GetSetAutomationItemInfo(TrackEnv, i3-1, "D_POSITION", 0, 0)
            local lenAutoIt = reaper.GetSetAutomationItemInfo(TrackEnv, i3-1, "D_LENGTH", 0, 0)
            local autoEnd = posAutoIt + lenAutoIt
            
            if autoEnd <= Start or posAutoIt >= End then
                -- Automation item completely outside - delete
                reaper.GetSetAutomationItemInfo(TrackEnv, i3-1, "D_UISEL", 1, 1)
                reaper.Main_OnCommand(42086, 0) -- Delete automation items
            elseif posAutoIt < Start and autoEnd > Start then
                -- Overlaps at start - trim (new position = Start)
                local newLength = math.min(autoEnd - Start, End - Start)
                reaper.GetSetAutomationItemInfo(TrackEnv, i3-1, "D_POSITION", Start, 1)
                reaper.GetSetAutomationItemInfo(TrackEnv, i3-1, "D_LENGTH", newLength, 1)
            elseif posAutoIt < End and autoEnd > End then
                -- Overlaps at end - trim (position stays, only length changes)
                local newLength = End - posAutoIt
                reaper.GetSetAutomationItemInfo(TrackEnv, i3-1, "D_LENGTH", newLength, 1)
            end
            -- Automation items completely inside remain unchanged
        end
        
        reaper.SetCursorContext(1, TrackEnv)
    end
end

-- Remove time selection if desired
if RemoveTimeSel == true then
    reaper.GetSet_LoopTimeRange(1, 0, 0, 0, 0)
end

-- Restore cursor position (if it was inside the selection)
if Cur >= Start and Cur <= End then
    reaper.SetEditCurPos(Cur, false, false)
else
    reaper.SetEditCurPos(Start, false, false)
end

reaper.UpdateArrange()
reaper.PreventUIRefresh(-1)
reaper.Undo_EndBlock("Crop to time selection - keep original positions", -1)
