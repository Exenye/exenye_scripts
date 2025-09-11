--[[
    @version 1.1
    @author Exenye
    Script: Exenye_TOOL - FX Manager Lite
    Description: FX Manager with multi-selection, copy/paste and delete functionality for track effects
    
    
    Copyright (C) 2024 [Exenye / Wieland Müller]. All rights reserved.
    For licensing and inquiries, contact [wieland@exenye.com].
 
    If you want to get updates or support my work, check out my new ko-fi:
    https://ko-fi.com/exenye

    My reaper forum profile:
    https://forum.cockos.com/member.php?u=165083

]]


--======================================================================================
--////////////                              FUNCTIONS                            \\\\\\\\\\\\
--======================================================================================

local function loadSettings()
    local str = reaper.GetExtState("FXManager", "Settings")
    local settings = {}
    if str ~= "" then
        for line in str:gmatch("[^\n]+") do
            local k, v = line:match("([^:]+):(.+)")
            if k and v then
                if v == "true" then
                    v = true
                elseif v == "false" then
                    v = false
                else
                    local num = tonumber(v)
                    if num ~= nil then
                        v = num
                    end
                end
                settings[k] = v
            end
        end
    end

    local defaultSettings = {
        fxListSize = 400,
        buttonWidth = 280,
        autoRefresh = true
    }

    for k, v in pairs(defaultSettings) do
        if settings[k] == nil then
            settings[k] = v
        end
    end

    return settings
end

local function saveSettings(settings)
    local str = ""
    for k, v in pairs(settings) do
        str = str .. k .. ":" .. tostring(v) .. "\n"
    end
    reaper.SetExtState("FXManager", "Settings", str, true)
end

local function getCurrentTarget()
    local item = reaper.GetSelectedMediaItem(0, 0)
    if item then
        local take = reaper.GetActiveTake(item)
        if take then
            return reaper.GetMediaItem_Track(item), "item", item, take
        else
            return reaper.GetMediaItem_Track(item), "track", nil, nil
        end
    else
        return reaper.GetSelectedTrack(0, 0), "track", nil, nil
    end
end

local function getFXList(track, targetType, item, take)
    local fxList = {}
    
    if targetType == "item" and take then
        local fxCount = reaper.TakeFX_GetCount(take)
        for i = 0, fxCount - 1 do
            local _, fxName = reaper.TakeFX_GetFXName(take, i, "")
            local cleanName = fxName:gsub("^[^:]+: ", ""):gsub(" %(.+%)$", "")
            table.insert(fxList, {
                index = i,
                name = cleanName,
                fullName = fxName
            })
        end
    elseif targetType == "track" and track then
        local fxCount = reaper.TrackFX_GetCount(track)
        for i = 0, fxCount - 1 do
            local _, fxName = reaper.TrackFX_GetFXName(track, i, "")
            local cleanName = fxName:gsub("^[^:]+: ", ""):gsub(" %(.+%)$", "")
            table.insert(fxList, {
                index = i,
                name = cleanName,
                fullName = fxName
            })
        end
    end
    
    return fxList
end

-- Global variables for copy/paste
local copiedFXSource = {}

local function copySelectedFX(selectedIndices, track, fxList, targetType, take)
    copiedFXSource = {
        track = track,
        take = take,
        targetType = targetType,
        fxIndices = {}
    }
    
    -- Collect FX indices to copy
    for idx, _ in pairs(selectedIndices) do
        if fxList[idx] then
            table.insert(copiedFXSource.fxIndices, fxList[idx].index)
        end
    end
    
    -- Sort indices
    table.sort(copiedFXSource.fxIndices)
    
    return #copiedFXSource.fxIndices
end

local function pasteFX(targetTrack, targetType, targetItem, targetTake)
    if not copiedFXSource.track and not copiedFXSource.take then
        return false
    end
    
    if #copiedFXSource.fxIndices == 0 then
        return false
    end
    
    -- Get all selected targets for multi-paste
    local allTargets = {}
    
    -- Check for selected items first
    local itemCount = reaper.CountSelectedMediaItems(0)
    if itemCount > 0 then
        for i = 0, itemCount - 1 do
            local item = reaper.GetSelectedMediaItem(0, i)
            local take = reaper.GetActiveTake(item)
            if take then
                table.insert(allTargets, {
                    track = reaper.GetMediaItem_Track(item),
                    targetType = "item",
                    item = item,
                    take = take
                })
            end
        end
    else
        -- Check for selected tracks
        local trackCount = reaper.CountSelectedTracks(0)
        if trackCount > 0 then
            for i = 0, trackCount - 1 do
                local track = reaper.GetSelectedTrack(0, i)
                table.insert(allTargets, {
                    track = track,
                    targetType = "track",
                    item = nil,
                    take = nil
                })
            end
        else
            -- Fallback to single target
            table.insert(allTargets, {
                track = targetTrack,
                targetType = targetType,
                item = targetItem,
                take = targetTake
            })
        end
    end
    
    reaper.Undo_BeginBlock()
    
    local success = false
    
    -- Paste to all targets
    for _, target in ipairs(allTargets) do
        for _, fxIndex in ipairs(copiedFXSource.fxIndices) do
            if copiedFXSource.targetType == "item" and copiedFXSource.take then
                -- Source is item
                if target.targetType == "item" and target.take then
                    -- Item to Item
                    if reaper.TakeFX_CopyToTake(copiedFXSource.take, fxIndex, target.take, -1, false) then
                        success = true
                    end
                elseif target.targetType == "track" and target.track then
                    -- Item to Track  
                    if reaper.TakeFX_CopyToTrack(copiedFXSource.take, fxIndex, target.track, -1, false) then
                        success = true
                    end
                end
            elseif copiedFXSource.targetType == "track" and copiedFXSource.track then
                -- Source is track
                if target.targetType == "item" and target.take then
                    -- Track to Item
                    if reaper.TrackFX_CopyToTake(copiedFXSource.track, fxIndex, target.take, -1, false) then
                        success = true
                    end
                elseif target.targetType == "track" and target.track then
                    -- Track to Track
                    if reaper.TrackFX_CopyToTrack(copiedFXSource.track, fxIndex, target.track, -1, false) then
                        success = true
                    end
                end
            end
        end
    end
    
    reaper.Undo_EndBlock("Paste FX", -1)
    return success
end

local function deleteSelectedFX(selectedIndices, track, fxList, targetType, take)
    local indicesToDelete = {}
    for idx, _ in pairs(selectedIndices) do
        if fxList[idx] then
            table.insert(indicesToDelete, fxList[idx].index)
        end
    end
    
    -- Sort indices in descending order to delete from highest to lowest
    table.sort(indicesToDelete, function(a, b) return a > b end)
    
    local deletedCount = 0
    for _, fxIndex in ipairs(indicesToDelete) do
        if targetType == "item" and take then
            reaper.TakeFX_Delete(take, fxIndex)
        elseif targetType == "track" and track then
            reaper.TrackFX_Delete(track, fxIndex)
        end
        deletedCount = deletedCount + 1
    end
    
    return deletedCount
end

--======================================================================================
--////////////                             MAIN SCRIPT                           \\\\\\\\\\\\
--======================================================================================

local function showFXManager()
    local ctx = reaper.ImGui_CreateContext('FX Manager MultiSelect')
    if not ctx then
        reaper.ShowMessageBox("ImGui context could not be created.", "Error", 0)
        return
    end

    local settings = loadSettings()
    local fxListSize = settings.fxListSize
    local buttonWidth = settings.buttonWidth

    local currentTrack = nil
    local currentTargetType = ""
    local currentItem = nil
    local currentTake = nil
    local fxList = {}
    local selectedFX = {} -- Table to track selected FX indices
    local lastTargetPointer = nil

    local function refreshFXList()
        local track, targetType, item, take = getCurrentTarget()
        currentTrack = track
        currentTargetType = targetType
        currentItem = item
        currentTake = take
        fxList = getFXList(currentTrack, currentTargetType, currentItem, currentTake)
        
        -- Clear selections if target changed
        local currentTargetPointer = item or track
        if currentTargetPointer ~= lastTargetPointer then
            selectedFX = {}
            lastTargetPointer = currentTargetPointer
        end
        
        -- Remove invalid selections
        local validSelections = {}
        for idx, _ in pairs(selectedFX) do
            if fxList[idx] then
                validSelections[idx] = true
            end
        end
        selectedFX = validSelections
    end

    local function loop()
        -- Apply styling
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
        reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_SelectableTextAlign(), 0.5, 0.5)
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

        local visible, open = reaper.ImGui_Begin(ctx, 'FX Manager Lite', true,
            reaper.ImGui_WindowFlags_AlwaysAutoResize() | reaper.ImGui_WindowFlags_NoCollapse())

        if visible then
            -- Always refresh to catch changes
            refreshFXList()

            -- Track info
            local trackInfo = "No track selected"
            if currentTrack then
                local _, trackName = reaper.GetSetMediaTrackInfo_String(currentTrack, "P_NAME", "", false)
                if trackName == "" then
                    trackInfo = "Track " .. (reaper.GetMediaTrackInfo_Value(currentTrack, "IP_TRACKNUMBER")) .. " (" .. currentTargetType .. ")"
                else
                    trackInfo = trackName .. " (" .. currentTargetType .. ")"
                end
                
                -- Begrenze die Länge des Track-Infos, um die Fensterbreite zu kontrollieren
                local maxLength = 30-- Maximale Anzahl Zeichen
                if string.len(trackInfo) > maxLength then
                    trackInfo = string.sub(trackInfo, 1, maxLength - 3) .. "..."
                end
            end
            reaper.ImGui_Text(ctx, "Current: " .. trackInfo)

            -- Control buttons
            if reaper.ImGui_Button(ctx, 'Refresh FX List', buttonWidth) then
                refreshFXList()
            end

            if reaper.ImGui_Button(ctx, 'Select All', buttonWidth / 2 - 4) then
                selectedFX = {}
                for i = 1, #fxList do
                    selectedFX[i] = true
                end
            end
            reaper.ImGui_SameLine(ctx)
            if reaper.ImGui_Button(ctx, 'Deselect All', buttonWidth / 2 - 4) then
                selectedFX = {}
            end

            -- Selected count
            local selectedCount = 0
            for _, _ in pairs(selectedFX) do
                selectedCount = selectedCount + 1
            end
            reaper.ImGui_Text(ctx, 'FX List (' .. #fxList .. ' effects, ' .. selectedCount .. ' selected):')

            -- FX List
            if reaper.ImGui_BeginListBox(ctx, '##FXList', buttonWidth, fxListSize) then
                for i = 1, #fxList do
                    local fx = fxList[i]
                    reaper.ImGui_PushID(ctx, i)
                    
                    local isSelected = selectedFX[i] or false
                    
                    -- Apply highlight colors for selected items
                    if isSelected then
                        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(), 0x2EA6A6FF)
                        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderHovered(), 0x238080FF)
                        reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderActive(), 0x2EA6A6FF)
                    end
                    
                    local clicked = reaper.ImGui_Selectable(ctx, fx.name, isSelected)
                    
                    -- Remove highlight colors
                    if isSelected then
                        reaper.ImGui_PopStyleColor(ctx, 3)
                    end
                    
                    if clicked then
                        local ctrlPressed = reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_LeftCtrl()) or 
                                          reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_RightCtrl())
                        
                        if ctrlPressed then
                            -- Toggle selection
                            if selectedFX[i] then
                                selectedFX[i] = nil
                            else
                                selectedFX[i] = true
                            end
                        else
                            -- Single selection
                            selectedFX = {}
                            selectedFX[i] = true
                        end
                    end

                    -- Right click handling
                    if reaper.ImGui_IsItemClicked(ctx, reaper.ImGui_MouseButton_Right()) then
                        if not selectedFX[i] then
                            selectedFX = {}
                            selectedFX[i] = true
                        end
                    end

                    -- Context menu for FX items
                    if reaper.ImGui_BeginPopupContextItem(ctx) then
                        if reaper.ImGui_MenuItem(ctx, "Copy Selected FX") then
                            copySelectedFX(selectedFX, currentTrack, fxList, currentTargetType, currentTake)
                        end
                        if reaper.ImGui_MenuItem(ctx, "Delete Selected FX") then
                            deleteSelectedFX(selectedFX, currentTrack, fxList, currentTargetType, currentTake)
                            selectedFX = {}
                            refreshFXList()
                        end
                        if reaper.ImGui_MenuItem(ctx, "Paste FX") then
                            if pasteFX(currentTrack, currentTargetType, currentItem, currentTake) then
                                refreshFXList()
                            end
                        end
                        reaper.ImGui_Separator(ctx)
                        if reaper.ImGui_MenuItem(ctx, "Open FX UI") then
                            if currentTargetType == "item" and currentTake then
                                reaper.TakeFX_Show(currentTake, fx.index, 3) -- 3 = floating window
                            elseif currentTargetType == "track" and currentTrack then
                                reaper.TrackFX_Show(currentTrack, fx.index, 3) -- 3 = floating window
                            end
                        end
                        reaper.ImGui_EndPopup(ctx)
                    end
                    
                    reaper.ImGui_PopID(ctx)
                end
                
                -- Context menu for empty area (when no FX or on empty space)
                if reaper.ImGui_BeginPopupContextWindow(ctx, "EmptyAreaContext", reaper.ImGui_PopupFlags_MouseButtonRight() | reaper.ImGui_PopupFlags_NoOpenOverItems()) then
                    -- Only show paste option in empty area context menu
                    if reaper.ImGui_MenuItem(ctx, "Paste FX") then
                        if pasteFX(currentTrack, currentTargetType, currentItem, currentTake) then
                            refreshFXList()
                        end
                    end
                    reaper.ImGui_EndPopup(ctx)
                end
                
                reaper.ImGui_EndListBox(ctx)
            end

            -- Keyboard shortcuts for Undo/Redo
            if reaper.ImGui_IsWindowFocused(ctx) then
                -- Ctrl+Z for Undo
                if (reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_LeftCtrl()) or 
                    reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_RightCtrl())) and
                   reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Z()) then
                    reaper.Main_OnCommand(40029, 0) -- Undo
                end
                
                -- Ctrl+Y for Redo  
                if (reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_LeftCtrl()) or 
                    reaper.ImGui_IsKeyDown(ctx, reaper.ImGui_Key_RightCtrl())) and
                   reaper.ImGui_IsKeyPressed(ctx, reaper.ImGui_Key_Y()) then
                    reaper.Main_OnCommand(40030, 0) -- Redo
                end
            end

            -- Action buttons
            if reaper.ImGui_Button(ctx, 'Copy Selected', buttonWidth) then
                copySelectedFX(selectedFX, currentTrack, fxList, currentTargetType, currentTake)
            end

            if reaper.ImGui_Button(ctx, 'Paste FX', buttonWidth) then
                pasteFX(currentTrack, currentTargetType, currentItem, currentTake)
                refreshFXList()
            end

            if reaper.ImGui_Button(ctx, 'Delete Selected', buttonWidth) then
                deleteSelectedFX(selectedFX, currentTrack, fxList, currentTargetType, currentTake)
                selectedFX = {}
                refreshFXList()
            end

            reaper.ImGui_PopStyleColor(ctx, 34)
            reaper.ImGui_PopStyleVar(ctx, 20)
        end

        reaper.ImGui_End(ctx)

        if open then
            reaper.defer(loop)
        end
    end

    loop()
end

showFXManager()
