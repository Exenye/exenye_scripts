--[[
    Script: Exenye_ITEM - Count all items on all tracks and rename tracks with the number of items
    Author: Exenye
    Description: Rename all tracks based on item count, create summary track and select non-standard tracks
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
  -- Begin undo action
  reaper.Undo_BeginBlock()
  
  -- Get number of tracks in project
  local numTracks = reaper.CountTracks(0)
  
  -- Variable for total number of all items in project
  local totalItemCount = 0
  
  -- Deselect all existing tracks
  reaper.Main_OnCommand(40297, 0) -- Deselect all tracks
  
  -- Loop through all tracks
  for i = 0, numTracks - 1 do
    -- Get current track
    local track = reaper.GetTrack(0, i)
    
    -- Count items on this track
    local itemCount = reaper.CountTrackMediaItems(track)
    
    -- Increase total count
    totalItemCount = totalItemCount + itemCount
    
    -- Rename track to number of items
    reaper.GetSetMediaTrackInfo_String(track, "P_NAME", tostring(itemCount), true)
    
    -- Check if track doesn't have exactly 10 or 12 items and mark accordingly
    if itemCount ~= 10 and itemCount ~= 12 then
      reaper.SetTrackSelected(track, true) -- Select track
    else
      reaper.SetTrackSelected(track, false) -- Deselect track
    end
  end
  
  -- Create new track at end of project
  reaper.InsertTrackAtIndex(numTracks, true)
  local newTrack = reaper.GetTrack(0, numTracks)
  
  -- Name new track with total number of all items
  reaper.GetSetMediaTrackInfo_String(newTrack, "P_NAME", tostring(totalItemCount), true)
  
  -- End undo action
  reaper.Undo_EndBlock("Rename tracks, add total count track, and select non-standard tracks", -1)
  
  -- Update UI
  reaper.UpdateArrange()
end

--======================================================================================
--////////////                             MAIN SCRIPT                           \\\\\\\\\\\\
--======================================================================================

-- Execute main function
main()
