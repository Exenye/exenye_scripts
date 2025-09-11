--[[
    Script: Exenye_ITEM - Split selected item in multiple parts with equal length
    Author: Exenye
    Description: Split selected items into specified number of equal parts
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
  -- Open input field to get number of parts
  local retval, user_input = reaper.GetUserInputs("Split Items", 1, "Number of parts:", "")
  if not retval then return end -- User cancelled

  local num_parts = tonumber(user_input)
  if not num_parts or num_parts < 1 then
    reaper.ShowMessageBox("Please enter a valid number greater than 0.", "Error", 0)
    return
  end

  -- Check if items are selected
  local num_items = reaper.CountSelectedMediaItems(0)
  if num_items == 0 then
    reaper.ShowMessageBox("Please select at least one item.", "Error", 0)
    return
  end

  reaper.Undo_BeginBlock() -- Start undo block

  -- Collect selected items to avoid indices that change after cuts
  local selected_items = {}
  for i = 0, num_items - 1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    table.insert(selected_items, item)
  end

  -- Iterate through all collected items
  for _, item in ipairs(selected_items) do
    local item_start = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
    local item_length = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
    local item_end = item_start + item_length

    local interval = item_length / num_parts -- Calculate interval between cuts

    local cut_positions = {}

    -- Collect cut positions
    for j = 1, num_parts - 1 do
      local cut_pos = item_start + interval * j
      table.insert(cut_positions, cut_pos)
    end

    -- Sort cut positions in reverse order
    table.sort(cut_positions, function(a, b) return a > b end)

    -- Perform cuts
    for _, cut_pos in ipairs(cut_positions) do
      reaper.SplitMediaItem(item, cut_pos)
    end
  end

  reaper.UpdateArrange()
  reaper.Undo_EndBlock("Split selected items into "..num_parts.." equal parts", -1)
end

--======================================================================================
--////////////                             MAIN SCRIPT                           \\\\\\\\\\\\
--======================================================================================

main()
