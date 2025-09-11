--[[
    Script: Exenye_GENERAL - Render all open project tabs with latest render settings
    Author: Exenye
    Description: Render all open projects sequentially with overwrite enabled
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

-- Function to render the current project and move to the next project tab
function RenderAndNextProject()
    -- Set render settings to automatically overwrite files without prompts
    local render_flags = reaper.GetSetProjectInfo(0, "RENDER_SETTINGS", 0, false) -- Get current render settings
    render_flags = render_flags | 16 -- Set the overwrite flag (bitwise OR with 16 to force overwrite)
    reaper.GetSetProjectInfo(0, "RENDER_SETTINGS", render_flags, true) -- Apply the new render settings

    -- Render the current project using the most recent render settings
    reaper.Main_OnCommand(41824, 0) -- File: Render project, using the most recent render settings

    -- Move to the next project tab
    reaper.Main_OnCommand(40861, 0) -- Project: Switch to next tab
end

--======================================================================================
--////////////                             MAIN SCRIPT                           \\\\\\\\\\\\
--======================================================================================

local reaper = reaper

-- Get the total number of open projects
local project_count = 0
while reaper.EnumProjects(project_count, "") do
    project_count = project_count + 1
end

-- Ensure there's more than one project open
if project_count < 2 then
    reaper.ShowMessageBox("Less than two projects open. Operation cancelled.", "Error", 0)
    return
end

-- Loop through all projects and render them sequentially
for i = 1, project_count do
    RenderAndNextProject()
end

-- Return to the first project tab to check if rendering is done
reaper.Main_OnCommand(40862, 0) -- Project: Switch to previous tab (go back to the first tab)

-- Notify the user that all projects have been rendered
reaper.ShowMessageBox("All projects have been rendered.", "Operation Complete", 0)
