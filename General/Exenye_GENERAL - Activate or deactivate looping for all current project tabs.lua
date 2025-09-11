--[[
    Script: Exenye_GENERAL - Activate or deactivate looping for all current project tabs
    Author: Exenye
    Description: Toggle loop on/off for all open projects based on user input
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

-- Function to check and set loop on/off based on user input
function check_and_toggle_loop(loop_on)
  local current_project = reaper.EnumProjects(-1, "") -- Save current project
  
  -- Initialize index and project
  local i = 0
  local project = reaper.EnumProjects(i, "")
  
  -- Iterate through all open project tabs
  while project do
    -- Switch focus to the project tab
    reaper.SelectProjectInstance(project)
    
    -- Get the current loop state
    local loop_state = reaper.GetSetRepeat(0)
    
    if loop_on then
      -- Turn loop ON if it's off
      if loop_state == 0 then
        reaper.GetSetRepeat(1)
      end
    else
      -- Turn loop OFF if it's on
      if loop_state == 1 then
        reaper.GetSetRepeat(0)
      end
    end
    
    -- Move to the next project
    i = i + 1
    project = reaper.EnumProjects(i, "")
  end
  
  -- Restore focus to the original project tab
  reaper.SelectProjectInstance(current_project)
end

-- Function to show UI and get user input
function show_toggle_loop_ui()
  local ret, user_input = reaper.GetUserInputs("Toggle Loop On/Off", 1, "Enter 1 for On, 0 for Off:", "")
  
  if ret then
    local loop_on = tonumber(user_input)
    
    if loop_on == 1 or loop_on == 0 then
      check_and_toggle_loop(loop_on == 1)
      reaper.ShowMessageBox("Loop state applied to all open projects", "Success", 0)
    else
      reaper.ShowMessageBox("Invalid input. Please enter 1 for ON or 0 for OFF.", "Error", 0)
    end
  end
end

--======================================================================================
--////////////                             MAIN SCRIPT                           \\\\\\\\\\\\
--======================================================================================

reaper.ClearConsole() -- Clear REAPER console (optional, for debugging)

-- Run the UI to get user input
show_toggle_loop_ui()

reaper.UpdateArrange() -- Update REAPER's arrange view (optional)
