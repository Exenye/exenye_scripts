--[[
    Script: Exenye_ITEM - Select all items containing FX
    Author: Exenye
    Description: Select all media items that contain FX (Item-FX or Take-FX)
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

-- Check if item's state chunk contains an FX block
local function item_contains_fx(item)
  -- Get complete chunk (read-only = false)
  local ok, chunk = reaper.GetItemStateChunk(item, "", false)
  if not ok then return false end

  -- Item-FX  ->  <ITEMFX
  -- Take-FX  ->  <TAKEFX  (once per take)
  return chunk:find("<ITEMFX") or chunk:find("<TAKEFX")
end

-- Main routine: deselect all, then select items with FX
local function select_items_with_fx()
  reaper.Main_OnCommand(40289, 0)              -- "Item selection: Unselect all items"
  local proj  = 0
  local count = reaper.CountMediaItems(proj)

  for i = 0, count-1 do
    local it = reaper.GetMediaItem(proj, i)
    if item_contains_fx(it) then
      reaper.SetMediaItemSelected(it, true)    -- Select item
    end
  end
  reaper.UpdateArrange()                       -- GUI refresh
end

--======================================================================================
--////////////                             MAIN SCRIPT                           \\\\\\\\\\\\
--======================================================================================

reaper.Undo_BeginBlock()
select_items_with_fx()
reaper.Undo_EndBlock("Select items containing FX", -1)
