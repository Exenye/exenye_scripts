--[[
    Script: Exenye_TOOL - SourceReplacer Lite
    Author: Exenye
    Description: Replace source files with multi-selection and category-based replacement
    Version: 1.0
    
    Copyright (C) 2024 [Exenye / Wieland Müller]. All rights reserved.
    For licensing and inquiries, contact [wieland@exenye.com].
 
    If you want to get updates or support my work, check out my new ko-fi:
    https://ko-fi.com/exenye

    My reaper forum profile:
    https://forum.cockos.com/member.php?u=165083

]]


--======================================================================================
--////////////                              SETTINGS                             \\\\\\\\\\\\
--======================================================================================

local EXT_SECTION   = "ReplaceSourcePopup"             -- Name des ExtState-Blocks
local AUDIO_TYPES   = { ".wav", ".flac", ".aiff", ".aif",
                        ".ogg", ".mp3", ".m4a", ".wv", ".mp4" } -- akzeptierte Endungen

--======================================================================================
--////////////                              FUNCTIONS                            \\\\\\\\\\\\
--======================================================================================

local function isAudioFile(fname)
  fname = fname:lower()
  for _,ext in ipairs(AUDIO_TYPES) do
    if fname:sub(-#ext) == ext then return true end
  end
  return false
end

local function normalizePath(path)
  if path == "" then return "" end
  -- Sicherstellen, dass der Pfad mit Separator endet
  local sep = package.config:sub(1,1) -- Windows: \, Unix: /
  if path:sub(-1) ~= sep and path:sub(-1) ~= "/" and path:sub(-1) ~= "\\" then
    path = path .. sep
  end
  return path
end

-- Cat ID aus UCS Naming Convention extrahieren
local function extractCatID(filename)
  -- Entferne Pfad und Endung
  local baseName = filename:match("([^/\\]+)$") or filename
  baseName = baseName:match("^(.+)%.[^%.]+$") or baseName
  
  -- UCS Cat IDs - der Teil vor dem ersten "-" oder "_"
  local catID = baseName:match("^([^%-_]+)")
  return catID or ""
end

-- Files nach Cat ID gruppieren
local function groupFilesByCatID(fileList)
  local catGroups = {}
  
  for _, fileObj in ipairs(fileList) do
    local catID = extractCatID(fileObj.file)
    if catID ~= "" then
      if not catGroups[catID] then
        catGroups[catID] = {}
      end
      table.insert(catGroups[catID], fileObj)
    end
  end
  
  return catGroups
end

-- Force Waveform Update
local function forceWaveformUpdate(item)
  if not item then return end
  
  -- Mehrere Methoden zur Waveform-Aktualisierung
  reaper.UpdateItemInProject(item)
  
  -- Force rebuild der Waveform durch temporäres Verschieben
  local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  reaper.SetMediaItemInfo_Value(item, "D_POSITION", pos + 0.0001)
  reaper.SetMediaItemInfo_Value(item, "D_POSITION", pos)
  
  -- Alternative: Reaper Action ausführen (Item: Refresh media file)
  reaper.Main_OnCommand(40441, 0) -- Item: Refresh media files
end

local function naturalSort(a, b)
  -- Proper weapon sorting: Auto -> Burst -> Single_Shot, then by full name, then by meters
  
  local function parseFilename(filename)
    -- Extract weapon type (Auto, Burst, Single_Shot, etc.)
    local weaponType = ""
    if filename:find("_Auto_") then
      weaponType = "1_Auto"
    elseif filename:find("_Burst_") then 
      weaponType = "2_Burst"
    elseif filename:find("_Single_") then
      weaponType = "3_Single"
    else
      weaponType = "0_Other"
    end
    
    -- Extract everything before meter indication
    local beforeMeter, meter = filename:match("^(.-)_(%d+)m_")
    if beforeMeter and meter then
      return weaponType, beforeMeter, tonumber(meter), filename
    end
    
    -- If no meter found, use whole filename
    return weaponType, filename, 0, filename
  end
  
  local weaponA, beforeA, meterA, fullA = parseFilename(a)
  local weaponB, beforeB, meterB, fullB = parseFilename(b)
  
  -- 1. First sort by weapon type (Auto, Burst, Single)
  if weaponA ~= weaponB then
    return weaponA < weaponB
  end
  
  -- 2. Then sort by everything before the meter
  if beforeA ~= beforeB then
    return beforeA:lower() < beforeB:lower()
  end
  
  -- 3. Then sort by meter distance within same gun/mic combo
  if meterA ~= meterB then
    return meterA < meterB
  end
  
  -- 4. Finally sort by full filename if everything else is equal
  return fullA:lower() < fullB:lower()
end

local function scanDirRecursive(basePath, filter)
  if basePath == "" then return {} end
  
  local files = {}
  
  -- Function to scan a single directory
  local function scanSingleDir(path, relativePath)
    local idx, fname = 0
    repeat
      fname = reaper.EnumerateFiles(path, idx)
      if fname then
        if isAudioFile(fname) and (filter == "" or fname:lower():find(filter:lower(), 1, true)) then
          local displayName = relativePath == "" and fname or (relativePath .. "/" .. fname)
          local fullPath = path .. fname
          files[#files+1] = {display = displayName, full = fullPath, file = fname}
        end
        idx = idx + 1
      end
    until not fname
    
    -- Now scan subdirectories
    idx = 0
    repeat
      local subdir = reaper.EnumerateSubdirectories(path, idx)
      if subdir then
        local subPath = path .. subdir .. (package.config:sub(1,1)) -- Add path separator
        local newRelativePath = relativePath == "" and subdir or (relativePath .. "/" .. subdir)
        scanSingleDir(subPath, newRelativePath)
      end
      idx = idx + 1
    until not subdir
  end
  
  -- Start recursive scan
  scanSingleDir(normalizePath(basePath), "")
  
  -- Sort by filename numbers first, then alphabetically
  table.sort(files, function(a, b) return naturalSort(a.file, b.file) end)
  
  return files
end

-- Random Cat ID Replace
local function randomCatIDReplace(fileList)
  local cntSel = reaper.CountSelectedMediaItems(0)
  if cntSel == 0 then 
    return 0, 0
  end
  
  -- Gruppiere alle Files nach Cat ID
  local catGroups = groupFilesByCatID(fileList)
  
  reaper.Undo_BeginBlock()
  
  local replacedCount = 0
  local totalCount = 0
  
  for i = 0, cntSel-1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    local take = reaper.GetActiveTake(item)
    if take then
      totalCount = totalCount + 1
      
      -- Get current source filename
      local source = reaper.GetMediaItemTake_Source(take)
      if source then
        local currentPath = reaper.GetMediaSourceFileName(source, "")
        local currentFilename = currentPath:match("([^\\/]+)$")
        
        if currentFilename then
          local currentCatID = extractCatID(currentFilename)
          
          if currentCatID ~= "" and catGroups[currentCatID] then
            local availableFiles = catGroups[currentCatID]
            
            -- Filter out the current file to avoid selecting the same one
            local otherFiles = {}
            for _, fileObj in ipairs(availableFiles) do
              if fileObj.file ~= currentFilename then
                table.insert(otherFiles, fileObj)
              end
            end
            
            -- Select random file from the same category
            if #otherFiles > 0 then
              math.randomseed(os.time() + i) -- Different seed for each item
              local randomIndex = math.random(1, #otherFiles)
              local selectedFile = otherFiles[randomIndex]
              
              local file = io.open(selectedFile.full, "r")
              if file then
                file:close()
                
                local newSrc = reaper.PCM_Source_CreateFromFile(selectedFile.full)
                if newSrc then
                  reaper.SetMediaItemTake_Source(take, newSrc)
                  
                  -- Rename item to new source filename
                  reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", selectedFile.file, true)
                  
                  -- Force Waveform Update
                  forceWaveformUpdate(item)
                  replacedCount = replacedCount + 1
                end
              end
            end
          end
        end
      end
    end
  end
  
  reaper.Undo_EndBlock("Random Cat ID Replace (" .. replacedCount .. "/" .. totalCount .. ")", -1)
  reaper.UpdateArrange()
  
  return replacedCount, totalCount
end

local function replaceSourceForSelection(fullFilePath)
  local cntSel = reaper.CountSelectedMediaItems(0)
  if cntSel == 0 then return end
  
  -- Prüfen ob Datei existiert
  local file = io.open(fullFilePath, "r")
  if not file then return end
  file:close()
  
  reaper.Undo_BeginBlock()
  
  for i = 0, cntSel-1 do
    local item = reaper.GetSelectedMediaItem(0, i)
    local take = reaper.GetActiveTake(item)
    if take then
      local newSrc = reaper.PCM_Source_CreateFromFile(fullFilePath)
      if newSrc then
        reaper.SetMediaItemTake_Source(take, newSrc)
        
        -- RENAME ITEM to source filename (without path)
        local filename = fullFilePath:match("([^\\/]+)$") -- Get filename only
        if filename then
          reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", filename, true)
        end
        
        -- Force Waveform Update
        forceWaveformUpdate(item)
      end
    end
  end
  
  reaper.Undo_EndBlock("Replace source", -1)
  reaper.UpdateArrange()
end

--======================================================================================
--////////////                          STYLING FUNCTIONS                        \\\\\\\\\\\\
--======================================================================================

local function applyStyle(ctx)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_DisabledAlpha(), 0.17)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowPadding(), 9, 8)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowRounding(), 12)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowBorderSize(), 0)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_WindowTitleAlign(), 0.5, 0.5)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ChildRounding(), 4)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_PopupRounding(), 4)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FramePadding(), 13, 4)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 7)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameBorderSize(), 1)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing(), 7, 4)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ItemInnerSpacing(), 0, 4)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_IndentSpacing(), 18)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_CellPadding(), 5, 1)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_ScrollbarRounding(), 5)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_GrabMinSize(), 10)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_GrabRounding(), 4)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_SelectableTextAlign(), 0.0, 0.5)  -- LEFT ALIGN for list items
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_SeparatorTextAlign(), 0, 0.48)
  reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_SeparatorTextPadding(), 16, 3)

  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(),                   0xD0D0D0FF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(),                 0x1E1E1EFF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TextDisabled(),           0x555555FF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(),               0x121212FF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ChildBg(),                0x00000000)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_PopupBg(),                0x1E1E1EFF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Border(),                 0x2E2E2EFF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBg(),                0x1E1E1EFF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgHovered(),         0x238080FF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgActive(),          0x2EA6A6FF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBg(),                0x1E1E1EFF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBgActive(),          0x238080FF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBgCollapsed(),       0x1E1E1EFF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_MenuBarBg(),              0x1E1E1EFF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ScrollbarBg(),            0x1A1A1AFF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ScrollbarGrab(),          0x2E2E2EFF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ScrollbarGrabHovered(),   0x238080FF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ScrollbarGrabActive(),    0x2EA6A6FF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_CheckMark(),              0x2EA6A6FF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrab(),             0x238080FF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrabActive(),       0x2EA6A6FF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(),          0x238080FF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(),           0x2EA6A6FF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(),                 0x1E1E1EFF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderHovered(),          0x238080FF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderActive(),           0x2EA6A6FF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Separator(),              0x2E2E2EFF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SeparatorHovered(),       0x238080FF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SeparatorActive(),        0x2EA6A6FF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ResizeGrip(),             0x2E2E2EFF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ResizeGripHovered(),      0x238080FF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ResizeGripActive(),       0x2EA6A6FF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Tab(),                    0x1E1E1EFF)
  reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TabHovered(),             0x238080FF)
end

local function popStyle(ctx)
  reaper.ImGui_PopStyleColor(ctx, 34)
  reaper.ImGui_PopStyleVar(ctx, 20)
end

--======================================================================================
--////////////                             MAIN SCRIPT                           \\\\\\\\\\\\
--======================================================================================

local ctx = nil
local sizeX, sizeY = 500, 450
local keepRunning = true

-- Gespeicherte Werte laden
local path = reaper.GetExtState(EXT_SECTION, "path") or ""
local filter = reaper.GetExtState(EXT_SECTION, "filter") or ""

-- Initial scannen
local fileList = path ~= "" and scanDirRecursive(normalizePath(path), filter) or {}
local selectedFile = 1

local function saveSettings()
  reaper.SetExtState(EXT_SECTION, "path", path, true)
  reaper.SetExtState(EXT_SECTION, "filter", filter, true)
end

local function loop()
  if not ctx or not keepRunning then
    saveSettings()
    if ctx then
     
      ctx = nil
    end
    return
  end

  -- ESC Key Check
  if reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Escape()) then
    keepRunning = false
    return
  end

  applyStyle(ctx)
  
  reaper.ImGui_SetNextWindowSize(ctx, sizeX, sizeY, reaper.ImGui_Cond_FirstUseEver())
  
  local visible
  visible, keepRunning = reaper.ImGui_Begin(ctx, "SourceReplacer Lite", true, reaper.ImGui_WindowFlags_NoCollapse())
  
  if visible then
    -- === PATH SECTION ===
    reaper.ImGui_Text(ctx, "Path:")
    
    -- Path input with Browse and Clear buttons on the same line
    local windowWidth = reaper.ImGui_GetContentRegionAvail(ctx)
    local buttonWidth = 60
    local spacing = 4
    local inputWidth = windowWidth - (buttonWidth * 2) - (spacing * 2)
    
    reaper.ImGui_PushItemWidth(ctx, inputWidth)
    local pathChanged
    pathChanged, path = reaper.ImGui_InputText(ctx, "##PathInput", path)
    reaper.ImGui_PopItemWidth(ctx)
    
    reaper.ImGui_SameLine(ctx, 0, spacing)
    if reaper.ImGui_Button(ctx, "Browse", buttonWidth, 0) then
      local ok, selectedPath = reaper.GetUserFileNameForRead("", "Select any file in the target folder (folder will be used)", "*")
      if ok and selectedPath then
        local newPath = selectedPath:match("^(.*[\\/])") or selectedPath:match("^(.*[/])") or ""
        if newPath ~= "" then
          path = newPath
          pathChanged = true
        end
      end
    end
    
    reaper.ImGui_SameLine(ctx, 0, spacing)
    if reaper.ImGui_Button(ctx, "Clear", buttonWidth, 0) then
      path = ""
      pathChanged = true
    end
    
    if pathChanged then
      path = normalizePath(path)
      fileList = scanDirRecursive(path, filter)
      selectedFile = 1
      saveSettings()
    end

    -- Filter input with Clear button
    reaper.ImGui_Text(ctx, "Search/Filter:")
    local clearButtonWidth = 50
    local filterInputWidth = windowWidth - clearButtonWidth - spacing
    
    reaper.ImGui_PushItemWidth(ctx, filterInputWidth)
    local filterChanged
    filterChanged, filter = reaper.ImGui_InputText(ctx, "##FilterInput", filter, 128)
    reaper.ImGui_PopItemWidth(ctx)
    
    reaper.ImGui_SameLine(ctx, 0, spacing)
    local clearPressed = reaper.ImGui_Button(ctx, "Clear##Filter", clearButtonWidth, 0)
    if clearPressed then
      filter = ""
      filterChanged = true
    end
    
    -- Update file list on filter change
    if filterChanged then
      fileList = scanDirRecursive(path, filter)
      selectedFile = 1
      saveSettings()
    end

    -- Info
    reaper.ImGui_Text(ctx, "Found: " .. #fileList .. " files")
    
    reaper.ImGui_Separator(ctx)

    -- === FILE LIST ===
    reaper.ImGui_Text(ctx, "Audio Files (click = instant replace):")
    
    -- Calculate available space for file list (reserve space for Random button)
    local windowWidth, windowHeight = reaper.ImGui_GetWindowSize(ctx)
    local cursorY = reaper.ImGui_GetCursorPosY(ctx)
    local listHeight = windowHeight - cursorY - 80 -- Reserve space for Random button and margins
    
    if reaper.ImGui_BeginListBox(ctx, "##files", -1, listHeight) then
      for i, fileObj in ipairs(fileList) do
        local isSelected = (i == selectedFile)
        -- Text is now left-aligned due to global style setting
        if reaper.ImGui_Selectable(ctx, fileObj.display, isSelected, reaper.ImGui_SelectableFlags_None()) then
          selectedFile = i
          -- INSTANT replace on single click - use full path
          replaceSourceForSelection(fileObj.full)
        end
      end
      reaper.ImGui_EndListBox(ctx)
    end
    
    reaper.ImGui_Separator(ctx)
    
    -- === RANDOM CAT ID BUTTON ===
    local selectedItems = reaper.CountSelectedMediaItems(0)
    local buttonText = "🎲 Random Cat ID Replace"
    if selectedItems > 0 then
      buttonText = buttonText .. " (" .. selectedItems .. " items)"
    else
      buttonText = buttonText .. " (no items selected)"
    end
    
    -- Disable button if no items selected or no files available
    local buttonEnabled = selectedItems > 0 and #fileList > 0
    if not buttonEnabled then
      reaper.ImGui_BeginDisabled(ctx)
    end
    
    if reaper.ImGui_Button(ctx, buttonText, -1, 35) then
      local replaced, total = randomCatIDReplace(fileList)
    end
    
    if not buttonEnabled then
      reaper.ImGui_EndDisabled(ctx)
    end
    
    -- Show Cat ID info
    if selectedItems > 0 then
      local catGroups = groupFilesByCatID(fileList)
      local uniqueCats = 0
      for _ in pairs(catGroups) do
        uniqueCats = uniqueCats + 1
      end
      reaper.ImGui_Text(ctx, "Available Cat IDs: " .. uniqueCats)
    end
    
  end

  reaper.ImGui_End(ctx)
  popStyle(ctx)
  
  if keepRunning then
    reaper.defer(loop)
  else
    saveSettings()
    if ctx then
     
      ctx = nil
    end
  end
end

-- Script starten
function main()
  ctx = reaper.ImGui_CreateContext("SourceReplacer Lite")
  if ctx then
    reaper.defer(loop)
  end
end

main()