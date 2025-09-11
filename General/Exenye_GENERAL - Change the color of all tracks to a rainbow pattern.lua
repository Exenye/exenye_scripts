--[[
    Script: Exenye_GENERAL - Change the color of all tracks to a rainbow pattern
    Author: Exenye
    Description: Colors all tracks in the current project with a rainbow gradient
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

-- Convert HSL to RGB (hue, saturation, lightness to red, green, blue)
function HSLToRGB(h, s, l)
  local r, g, b
  
  if s == 0 then
    r, g, b = l, l, l -- achromatic
  else
    local function hue2rgb(p, q, t)
      if t < 0 then t = t + 1 end
      if t > 1 then t = t - 1 end
      if t < 1/6 then return p + (q - p) * 6 * t end
      if t < 1/2 then return q end
      if t < 2/3 then return p + (q - p) * (2/3 - t) * 6 end
      return p
    end
    
    local q = l < 0.5 and l * (1 + s) or l + s - l * s
    local p = 2 * l - q
    
    r = hue2rgb(p, q, h + 1/3)
    g = hue2rgb(p, q, h)
    b = hue2rgb(p, q, h - 1/3)
  end
  
  return math.floor(r * 255), math.floor(g * 255), math.floor(b * 255)
end

-- Main function
function main()
  -- Count how many tracks are in the project
  local track_count = reaper.CountTracks(0)
  
  if track_count <= 0 then
    reaper.ShowMessageBox("No tracks in project!", "Error", 0)
    return
  end
  
  -- Begin undo block
  reaper.Undo_BeginBlock()
  
  -- Generate and apply colors
  for i = 0, track_count - 1 do
    local track = reaper.GetTrack(0, i)
    
    -- Calculate hue based on track position (full rainbow)
    local hue = i / track_count
    
    -- Convert HSL to RGB
    local r, g, b = HSLToRGB(hue, 0.65, 0.55)
    
    -- Convert RGB to Reaper color format
    local color = r + (g * 256) + (b * 65536)
    
    -- Apply color to track
    reaper.SetTrackColor(track, color)
  end
  
  -- End undo block
  reaper.Undo_EndBlock("Rainbow Track Colors", -1)
  
  -- Update the arrange view
  reaper.UpdateArrange()
end

--======================================================================================
--////////////                             MAIN SCRIPT                           \\\\\\\\\\\\
--======================================================================================

-- Run the script
reaper.PreventUIRefresh(1)
main()
reaper.PreventUIRefresh(0)
