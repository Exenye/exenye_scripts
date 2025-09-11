--[[
    Script: Exenye_ITEM - Select all items that do not contain certain words
    Author: Exenye
    Description: Select all media items except those containing specified keywords
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

function Main()
  -- Unselect all media items first
  reaper.Main_OnCommand(40289, 0) -- Unselect all media items
  
  -- Create input box for keywords
  local retval, userInput = reaper.GetUserInputs("Exclude Items With Keywords", 1, "Enter keywords (comma-separated):", "")
  
  -- If user cancelled, exit
  if not retval then return end
  
  -- Split the input into individual keywords
  local keywords = {}
  for word in string.gmatch(userInput, "([^,]+)") do
    keywords[#keywords + 1] = string.lower(string.gsub(word, "^%s*(.-)%s*$", "%1")) -- Trim whitespace and convert to lowercase
  end
  
  -- Count for stats
  local total_items = 0
  local excluded_items = 0
  
  -- Get number of media items in project
  local item_count = reaper.CountMediaItems(0)
  
  -- Loop through all media items
  for i = 0, item_count - 1 do
    local item = reaper.GetMediaItem(0, i)
    local take = reaper.GetActiveTake(item)
    
    total_items = total_items + 1
    
    if take then
      local item_name = reaper.GetTakeName(take)
      local exclude = false
      
      -- Check if item name contains any of the keywords
      item_name = string.lower(item_name)
      for _, keyword in ipairs(keywords) do
        if string.find(item_name, keyword, 1, true) then
          exclude = true
          excluded_items = excluded_items + 1
          break
        end
      end
      
      -- Select the item if it doesn't contain any keywords
      if not exclude then
        reaper.SetMediaItemSelected(item, true)
      end
    else
      -- If there's no active take, select the item by default
      reaper.SetMediaItemSelected(item, true)
    end
  end
  
  -- Update the arrange view
  reaper.UpdateArrange()
  
  -- Results processed silently
end

--======================================================================================
--////////////                             MAIN SCRIPT                           \\\\\\\\\\\\
--======================================================================================

reaper.Undo_BeginBlock()
Main()
reaper.Undo_EndBlock("Select items excluding keywords", -1)
