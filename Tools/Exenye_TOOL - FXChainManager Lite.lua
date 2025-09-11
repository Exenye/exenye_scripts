--[[
    Script: Exenye_TOOL - FXChainManager lite
    Author: Exenye
    Description: FX Chain Manager for applying, saving and managing FX chains with intuitive interface
    Version: 1.0
    
    Copyright (C) 2024 [Exenye / Wieland Müller]. All rights reserved.
    For licensing and inquiries, contact [wieland@exenye.com].
    
    Requires: SWS/S&M Extensions and ReaImGui
    Special thanks to X-Raym for his amazing scripts that helped with the FX chain save function.
]]


--======================================================================================
--////////////                              FUNCTIONS                            \\\\\\\\\\\\
--======================================================================================

local function focusMediaExplorer()
    local state = reaper.GetToggleCommandState(50124) 
    if state == 0 then
        reaper.Main_OnCommand(50124, 0)               
    end

    local hwnd = reaper.JS_Window_Find("Media Explorer", true)
    if hwnd then
        reaper.JS_Window_SetForeground(hwnd)
        reaper.JS_Window_SetFocus(hwnd)
    else
        reaper.ShowMessageBox("Media Explorer nicht gefunden.", "Fehler", 0)
    end
end

local function loadSettings()
    local str = reaper.GetExtState("FXChainManager", "Settings")
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
        showHoverEffect = false,
        showType = false,
        showManufacturer = false,
        fxChainListSize = 450,
        isAutoMode = true,
        replaceFX = true,
        muteInArrangementMode = true,
        buttonWidth = 240
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
    reaper.SetExtState("FXChainManager", "Settings", str, true)
end

local function loadFXChains()
    local fxChains = {}
    local chainPath = reaper.GetResourcePath() .. "/FXChains/"
    local i = 0
    repeat
        local file = reaper.EnumerateFiles(chainPath, i)
        if file then
            local name = file:match("(.+)%..+")
            if name then
                table.insert(fxChains, { name = name, path = chainPath .. file })
            end
        end
        i = i + 1
    until not file
    return fxChains
end

local function clearFXFromTrack(track)
    local fxCount = reaper.TrackFX_GetCount(track)
    for i = fxCount - 1, 0, -1 do
        reaper.TrackFX_Delete(track, i)
    end
end

local function applyFXChainToTrack(track, fxChainPath, replaceFX)
    if replaceFX then
        clearFXFromTrack(track)
    end

    reaper.Main_openProject(fxChainPath)

    local fxCount = reaper.TrackFX_GetCount(track)
    for i = 0, fxCount - 1 do
        reaper.TrackFX_Show(track, i, 2) 
    end
end

local function applyFXChainInArrangementMode(fxChainPath, replaceFX)
    local item = reaper.GetSelectedMediaItem(0, 0)
    local track

    if item then
        track = reaper.GetMediaItem_Track(item)
        -- Wenn replaceFX aktiv ist und ein Item ausgewählt ist, lösche Take FX
        if replaceFX then
            local take = reaper.GetActiveTake(item)
            if take then
                local fxCount = reaper.TakeFX_GetCount(take)
                for i = fxCount - 1, 0, -1 do
                    reaper.TakeFX_Delete(take, i)
                end
            end
        end
    else
        track = reaper.GetSelectedTrack(0, 0)
    end

    if track then
        -- Track selektieren damit Main_openProject auf den richtigen Track angewendet wird
        reaper.SetOnlyTrackSelected(track)
        applyFXChainToTrack(track, fxChainPath, replaceFX)
    else
        reaper.ShowMessageBox("Kein Media Item oder Track ausgewählt.", "Fehler", 0)
    end
end

local function createMediaTrack()
    local trackCount = reaper.CountTracks(0)
    for i = 0, trackCount - 1 do
        local track = reaper.GetTrack(0, i)
        local _, name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
        if name == "Media Explorer Preview" then
            return track
        end
    end

    reaper.InsertTrackAtIndex(trackCount, true)
    local mediaTrack = reaper.GetTrack(0, trackCount)
    reaper.GetSetMediaTrackInfo_String(mediaTrack, "P_NAME", "Media Explorer Preview", true)
    reaper.SetMediaTrackInfo_Value(mediaTrack, "I_RECMON", 1)

    return mediaTrack
end

local function getFXChainEffects(fxChainPath, showType, showManufacturer)
    local effects = {}
    local file = io.open(fxChainPath, "r")
    if file then
        for line in file:lines() do
            local effect = line:match("<VST.-\"(.-)\"")
            if effect then
                if not showType then
                    effect = effect:gsub("^[^:]+: ", "")
                end
                if not showManufacturer then
                    effect = effect:gsub("%s*%(.+%)$", "")
                end
                table.insert(effects, effect)
            end
        end
        file:close()
    end
    return effects
end

local function literalize(str)
    return str:gsub("([%.%+%-%*%?%[%]%^%$%(%)%%])", "%%%1")
end

local function ExtractFXChunk(track)
    if reaper.TrackFX_GetCount(track) == 0 then return end
    local _, chunk = reaper.GetTrackStateChunk(track, '', false)
    local lastfxGUID = literalize(reaper.TrackFX_GetFXGUID(track, reaper.TrackFX_GetCount(track) - 1))
    local out_ch = chunk:match('<FXCHAIN(.*FXID ' .. lastfxGUID .. '[\r\n]+WAK %d).*>')
    return out_ch
end

local function saveCurrentFXChain()
    local cnt_seltr = reaper.CountSelectedTracks(0)
    if cnt_seltr == 0 then
        reaper.ShowMessageBox("KNo Tracks selected", "Error :/", 0)
        return
    end

    local ret, fxChainName = reaper.GetUserInputs("Save Chain", 1, "Insert Name:", "")
    if not ret or fxChainName == "" then return end

    local saving_folder = reaper.GetResourcePath() .. '/FXChains/'

    local t = {}
    for i = 1, cnt_seltr do
        local tr = reaper.GetSelectedTrack(0, i - 1)
        local ch = ExtractFXChunk(tr)
        if ch then
            table.insert(t, { name = fxChainName, chunk = ch })
        end
    end

    if #t == 0 then return end
    for i = 1, #t do
        local fname = t[i].name
        local f = io.open(saving_folder .. fname .. '.RfxChain', 'w')
        if f then
            f:write(t[i].chunk)
            f:close()
        end
    end
end

local function swapItems(tbl, index1, index2)
    tbl[index1], tbl[index2] = tbl[index2], tbl[index1]
end

--======================================================================================
--////////////                             MAIN SCRIPT                           \\\\\\\\\\\\
--======================================================================================

local function showFXChainManager()
    local ctx = reaper.ImGui_CreateContext('VST Chain Manager')
    if not ctx then
        reaper.ShowMessageBox("ImGui Kontext konnte nicht erstellt werden.", "Fehler", 0)
        return
    end

    local settings = loadSettings()
    local fxChainListSize = settings.fxChainListSize
    local buttonWidth = settings.buttonWidth
    local showHoverEffect = settings.showHoverEffect
    local showType = settings.showType
    local showManufacturer = settings.showManufacturer
    local isAutoMode = settings.isAutoMode
    local replaceFX = settings.replaceFX
    local muteInArrangementMode = settings.muteInArrangementMode

    local fxChains = loadFXChains()
    local selectedChainIndex = 0
    local fxChainToApply = nil

    local function loop()
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
        
        local visible, open = reaper.ImGui_Begin(ctx, 'FX Chain Manager Lite', true,
            reaper.ImGui_WindowFlags_AlwaysAutoResize() | reaper.ImGui_WindowFlags_NoCollapse())
        
        if visible then
            -- Button für Auto/Manual Modus
            if reaper.ImGui_Button(ctx, isAutoMode and 'Auto' or 'Manual', buttonWidth) then
                isAutoMode = not isAutoMode
                settings.isAutoMode = isAutoMode
                saveSettings(settings)
            end

            -- Button für Replace On/Off
            if reaper.ImGui_Button(ctx, replaceFX and 'Replace On' or 'Replace Off', buttonWidth) then
                replaceFX = not replaceFX
                settings.replaceFX = replaceFX
                saveSettings(settings)
            end

            -- Anzeige der FX Chains ohne Kategorien
            reaper.ImGui_Text(ctx, 'FX Chains:')
            if reaper.ImGui_BeginListBox(ctx, '##FXChains', buttonWidth, fxChainListSize) then
                for i, chain in ipairs(fxChains) do
                    if reaper.ImGui_Selectable(ctx, chain.name, selectedChainIndex == i) then
                        selectedChainIndex = i
                        fxChainToApply = chain.path

                        if isAutoMode then
                            applyFXChainInArrangementMode(fxChainToApply, replaceFX)
                        end
                    end

                    if showHoverEffect and reaper.ImGui_IsItemHovered(ctx) then
                        local effects = getFXChainEffects(chain.path, showType, showManufacturer)
                        if #effects > 0 then
                            reaper.ImGui_BeginTooltip(ctx)
                            for _, effect in ipairs(effects) do
                                reaper.ImGui_Text(ctx, effect)
                            end
                            reaper.ImGui_EndTooltip(ctx)
                        end
                    end

                    if reaper.ImGui_BeginPopupContextItem(ctx) then
                        if reaper.ImGui_MenuItem(ctx, "Delete Chain") then
                            os.remove(chain.path)
                            fxChains = loadFXChains()
                        end
                        reaper.ImGui_EndPopup(ctx)
                    end
                end
                reaper.ImGui_EndListBox(ctx)
            end

            reaper.ImGui_Dummy(ctx, 0, 0)
            if reaper.ImGui_Button(ctx, 'Apply Chain', buttonWidth) then
                if fxChainToApply then
                    applyFXChainInArrangementMode(fxChainToApply, replaceFX)
                else
                    reaper.ShowMessageBox("No chain selected", "Error :()", 0)
                end
            end

            if reaper.ImGui_Button(ctx, 'Refresh Chains', buttonWidth) then
                fxChains = loadFXChains()
            end

       

            if reaper.ImGui_Button(ctx, 'Save Current Chain', buttonWidth) then
                saveCurrentFXChain()
                fxChains = loadFXChains()
            end

            -- Pop Style Colors (Anzahl: 34)
            reaper.ImGui_PopStyleColor(ctx, 34)

            -- Pop Style Vars (Anzahl: 20)
            reaper.ImGui_PopStyleVar(ctx, 20)
        end

        reaper.ImGui_End(ctx)

        if open then
            reaper.defer(loop)
        end
    end

    loop()
end

showFXChainManager()
