--[[
    Script: Exenye_ITEM - Toggle move playhead to automation item
    Author: Exenye
    Description: Toggle follow edit cursor to start of selected automation items
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

local UPDATE_INTERVAL = 0.033   -- 33 ms  ≙ ca. 30 Hz

--======================================================================================
--////////////                              CONSTANTS                            \\\\\\\\\\\\
--======================================================================================

local EXT_SECTION = "AI_CURSOR_FOLLOW"
local EXT_KEY     = "running"

--======================================================================================
--////////////                              FUNCTIONS                            \\\\\\\\\\\\
--======================================================================================

-- Find earliest start position
local function get_earliest_AI_pos()
  local earliest, proj = nil, 0
  for t = 0, reaper.CountTracks(proj)-1 do
    local tr = reaper.GetTrack(proj, t)
    for e = 0, reaper.CountTrackEnvelopes(tr)-1 do
      local env = reaper.GetTrackEnvelope(tr, e)
      for ai = 0, reaper.CountAutomationItems(env)-1 do
        if reaper.GetSetAutomationItemInfo(env, ai, "D_UISEL", 0, false) == 1 then
          local pos = reaper.GetSetAutomationItemInfo(env, ai, "D_POSITION", 0, false)
          if not earliest or pos < earliest then earliest = pos end
        end
      end
    end
  end
  return earliest
end

-- Main loop
local function loop()
  if reaper.GetExtState(EXT_SECTION, EXT_KEY) ~= "1" then return end  -- Toggle OFF → End loop

  local pos = get_earliest_AI_pos()
  if pos then
    -- true: View follows cursor • false: Transport stays in place
    reaper.SetEditCurPos(pos, true, false)
  end

  -- Next iteration
  reaper.defer(loop)
end

--======================================================================================
--////////////                             MAIN SCRIPT                           \\\\\\\\\\\\
--======================================================================================

-- Toggle switch
local running = (reaper.GetExtState(EXT_SECTION, EXT_KEY) == "1")

if running then
  -- Turn OFF
  reaper.DeleteExtState(EXT_SECTION, EXT_KEY, true)           -- Delete status
  -- Update toolbar button (if assigned)
  local _, _, secID, cmdID = reaper.get_action_context()
  reaper.SetToggleCommandState(secID, cmdID, 0)
  reaper.RefreshToolbar2(secID, cmdID)

else
  -- Turn ON
  reaper.SetExtState(EXT_SECTION, EXT_KEY, "1", false)        -- Set status
  local _, _, secID, cmdID = reaper.get_action_context()
  reaper.SetToggleCommandState(secID, cmdID, 1)
  reaper.RefreshToolbar2(secID, cmdID)

  loop()                                                      -- Start loop
end
