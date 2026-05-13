local _, UI = ...

local Config = {
    MainBarOffset = 255,   
    VerticalPadding = 15,  
    BarGap = 2,            
}

local F = CreateFrame("Frame")
F:RegisterEvent("PLAYER_ENTERING_WORLD")
F:RegisterEvent("UNIT_ENTERED_VEHICLE")
F:RegisterEvent("UNIT_EXITED_VEHICLE")
F:RegisterEvent("VEHICLE_UPDATE")
F:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
F:RegisterEvent("PLAYER_CONTROL_GAINED")

local Hider = CreateFrame("Frame", "CleanUIHider", UIParent):Hide()
local isLocking = false

local ActionButtons, BonusButtons = {}, {}
for i = 1, 12 do
    ActionButtons[i] = _G["ActionButton"..i]
    BonusButtons[i] = _G["BonusActionButton"..i]
end

local function OverlayOnActionButton(btn, target)
    if not (btn and target) then return end
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", target, "CENTER", 0, 0)
    btn:SetFrameStrata(target:GetFrameStrata())
    btn:SetFrameLevel(target:GetFrameLevel() + 2)
end

local function kill(f)
    if not f or f.isDead then return end
    
    f:Hide()
    if f.UnregisterAllEvents then f:UnregisterAllEvents() end
    if f.SetAlpha then f:SetAlpha(0) end
    
    if f.SetParent and f:GetObjectType() == "Frame" then
        f:SetParent(Hider)
    end
    
    f.isDead = true
end

local function ApplySelectiveLockdown()
    if (CleanUIPositions and CleanUIPositions.MinimalistMode) or InCombatLockdown() or isLocking then return end
    isLocking = true

    MainMenuBar:ClearAllPoints()
    MainMenuBar:SetPoint("BOTTOM", UIParent, "BOTTOM", Config.MainBarOffset, Config.VerticalPadding)
    
    if not MainMenuBar.isLobotomized then
        MainMenuBar.ClearAllPoints = function() end
        MainMenuBar.SetPoint = function() end
        MainMenuBar.isLobotomized = true
    end

    if BonusActionBarFrame then
        BonusActionBarFrame:ClearAllPoints()
        BonusActionBarFrame:SetPoint("BOTTOM", MainMenuBar, "BOTTOM", 0, 0)
    end

    for i = 1, 12 do
        local mainBtn = _G["ActionButton"..i]
        local bonusBtn = _G["BonusActionButton"..i]

        if mainBtn then
            mainBtn:SetAttribute("showgrid", 1)
            ActionButton_ShowGrid(mainBtn)
        end

        if bonusBtn then
            bonusBtn:SetAttribute("showgrid", 1)
            ActionButton_ShowGrid(bonusBtn)
            OverlayOnActionButton(bonusBtn, mainBtn)
            bonusBtn:SetAlpha(1)
        end
    end

    if OverrideActionBar and ActionButton1 then
        OverrideActionBar:ClearAllPoints()
        OverrideActionBar:SetPoint("BOTTOM", ActionButton1, "BOTTOM", 0, 0)
        OverrideActionBar:SetFrameStrata("MEDIUM")
        for i = 1, 6 do
            OverlayOnActionButton(_G["OverrideActionBarButton"..i], _G["ActionButton"..i])
        end
    end

    if PossessBarFrame and ActionButton1 then
        PossessBarFrame:ClearAllPoints()
        PossessBarFrame:SetPoint("BOTTOM", ActionButton1, "BOTTOM", 0, 0)
        for i = 1, 2 do
            OverlayOnActionButton(_G["PossessButton"..i], _G["ActionButton"..i])
        end
    end

    if MultiBarBottomLeft then
        MultiBarBottomLeft:ClearAllPoints()
        MultiBarBottomLeft:SetPoint("BOTTOMLEFT", ActionButton1, "TOPLEFT", 0, Config.BarGap)
        if not MultiBarBottomLeft.isLobotomized then
            MultiBarBottomLeft.ClearAllPoints = function() end
            MultiBarBottomLeft.SetPoint = function() end
            MultiBarBottomLeft.isLobotomized = true
        end
    end
    
    if MultiBarBottomRight then
        local bar2Visible = MultiBarBottomLeft and MultiBarBottomLeft:IsShown()
        local anchor = bar2Visible and MultiBarBottomLeftButton1 or ActionButton1
        
        MultiBarBottomRight:ClearAllPoints()
        MultiBarBottomRight:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, Config.BarGap)
    end

    isLocking = false
end

local function ApplyCleanSkin()
    if CleanUIPositions and CleanUIPositions.MinimalistMode then
        UI.HaltModules = true
        kill(MainMenuBarLeftEndCap)
        kill(MainMenuBarRightEndCap)
        return 
    end

    kill(ActionBarUpButton)
    kill(ActionBarDownButton)
    kill(MainMenuBarPageNumber)

    if OverrideActionBar then OverrideActionBar:SetParent(UIParent) end
    if PossessBarFrame then PossessBarFrame:SetParent(UIParent) end

    local framesToDisable = {
        MainMenuBarOverlayFrame, MainMenuBarMaxLevelBar, MainMenuExpBar, 
        ReputationWatchBar, MainMenuBarPerformanceBarFrame, ExhaustionTick, 
        MainMenuBarArtFrame, 
        CharacterMicroButton, SpellbookMicroButton, TalentMicroButton, QuestLogMicroButton, 
        SocialsMicroButton, WorldMapMicroButton, MainMenuMicroButton, HelpMicroButton,
        MainMenuBarBackpackButton, CharacterBag0Slot, CharacterBag1Slot, CharacterBag2Slot, CharacterBag3Slot, KeyRingButton
    }
    for _, f in ipairs(framesToDisable) do kill(f) end

    local texturesToHide = {
        MainMenuBarTexture0, MainMenuBarTexture1, MainMenuBarTexture2, MainMenuBarTexture3,
        MainMenuMaxLevelBar0, MainMenuMaxLevelBar1, MainMenuMaxLevelBar2, MainMenuMaxLevelBar3,
        BonusActionBarTexture0, BonusActionBarTexture1,
        MainMenuBarLeftEndCap, MainMenuBarRightEndCap
    }
    for _, tex in ipairs(texturesToHide) do kill(tex) end

    ApplySelectiveLockdown()
end

-- Pins BonusActionButton AND ActionButton alphas to 1 every frame while in a vehicle, and clears
-- the slide-animation state (BonusActionBarFrame.mode = "show"/"hide"). This defends against two
-- bugs at once: (1) Blizzard's BonusActionBar_OnUpdate fading alphas to 0 over 0.2s on mode=hide,
-- and (2) the ShowBonusActionBar-fires-before-UNIT_ENTERED_VEHICLE race where UnitInVehicle is
-- still false when we'd want to skip hiding the main bar.
local BonusWatchdog = CreateFrame("Frame")
BonusWatchdog:Hide()
BonusWatchdog:SetScript("OnUpdate", function()
    if BonusActionBarFrame then
        BonusActionBarFrame.mode = nil
        BonusActionBarFrame.timeLeft = 0
        if BonusActionBarFrame:GetAlpha() ~= 1 then BonusActionBarFrame:SetAlpha(1) end
    end
    for i = 1, 12 do
        local b = BonusButtons[i]
        if b and b:GetAlpha() ~= 1 then b:SetAlpha(1) end
        local m = ActionButtons[i]
        if m and m:GetAlpha() ~= 1 then m:SetAlpha(1) end
    end
end)
UI.BonusWatchdog = BonusWatchdog

hooksecurefunc("ShowBonusActionBar", function()
    if BonusActionBarFrame then
        BonusActionBarFrame.mode = nil
        BonusActionBarFrame:SetAlpha(1)
        BonusActionBarFrame:Show()
    end
    -- GetBonusBarOffset() >= 5 means the vehicle bonus bar — UnitInVehicle isn't reliable here
    -- because ShowBonusActionBar often fires before UNIT_ENTERED_VEHICLE.
    local isVehicleBar = (GetBonusBarOffset() or 0) >= 5
    for i = 1, 12 do
        local mainBtn = ActionButtons[i]
        local bonusBtn = BonusButtons[i]
        if mainBtn and not isVehicleBar then mainBtn:SetAlpha(0) end
        if bonusBtn and mainBtn then
            OverlayOnActionButton(bonusBtn, mainBtn)
            bonusBtn:SetAlpha(1)
            bonusBtn:Show()
        end
    end
    if isVehicleBar then BonusWatchdog:Show() end
end)

hooksecurefunc("HideBonusActionBar", function()
    if UnitInVehicle("player") and not InCombatLockdown() then
        if BonusActionBarFrame then
            BonusActionBarFrame.mode = nil
            BonusActionBarFrame.timeLeft = 0
        end
        for i = 1, 12 do
            local b = BonusButtons[i]
            if b then b:SetAlpha(1) end
        end
        return
    end
    for i = 1, 12 do
        local btn = ActionButtons[i]
        if btn then btn:SetAlpha(1) end
    end
end)

-- /leavevehicle macro avoids any taint risk vs. calling protected VehicleExit() from a non-secure OnClick.
local function CreateLeaveVehicleButton()
    if _G["CleanUILeaveVehicleButton"] then return _G["CleanUILeaveVehicleButton"] end

    local btn = CreateFrame("Button", "CleanUILeaveVehicleButton", UIParent, "SecureActionButtonTemplate")
    btn:SetSize(36, 36)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(10)
    btn:Hide()

    btn:RegisterForClicks("AnyUp")
    btn:SetAttribute("type", "macro")
    btn:SetAttribute("macrotext", "/leavevehicle")

    if ActionButton12 then
        btn:SetPoint("BOTTOMLEFT", ActionButton12, "BOTTOMRIGHT", 12, 0)
    end

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\Vehicles\\UI-Vehicles-Button-Exit-Up")
    icon:SetTexCoord(0.140625, 0.859375, 0.140625, 0.859375)
    icon:SetPoint("TOPLEFT", btn, "TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)

    btn:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2")
    local nt = btn:GetNormalTexture()
    if nt then nt:SetAllPoints(btn); nt:SetAlpha(1) end
    btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(LEAVE_VEHICLE or "Leave Vehicle")
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

    return btn
end

local function UpdateLeaveVehicleButton(inVehicle)
    local btn = _G["CleanUILeaveVehicleButton"]
    if not btn or InCombatLockdown() then return end

    if CleanUIPositions and CleanUIPositions.MinimalistMode then
        btn:Hide()
        return
    end

    if inVehicle == nil then inVehicle = UnitInVehicle("player") end

    if inVehicle and CanExitVehicle() then
        btn:Show()
        -- Blizzard's exit button is parented to MainMenuBar, not MainMenuBarArtFrame, so it
        -- survives our kill — hide it to avoid duplicate buttons.
        if MainMenuBarVehicleLeaveButton then MainMenuBarVehicleLeaveButton:Hide() end
    else
        btn:Hide()
    end
end

UI.UpdateLeaveVehicleButton = UpdateLeaveVehicleButton

local function ReoverlayBonusBar()
    if InCombatLockdown() then return end
    if not (BonusActionBarFrame and BonusActionBarFrame:IsShown()) then return end
    BonusActionBarFrame.mode = nil
    BonusActionBarFrame:SetAlpha(1)
    for i = 1, 12 do
        local mainBtn = ActionButtons[i]
        local bonusBtn = BonusButtons[i]
        if bonusBtn and mainBtn then
            OverlayOnActionButton(bonusBtn, mainBtn)
            bonusBtn:SetAlpha(1)
        end
    end
end

local function RestoreMainBarAlpha()
    for i = 1, 12 do
        local btn = ActionButtons[i]
        if btn then btn:SetAlpha(1) end
    end
end

F:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_ENTERING_WORLD" then
        ApplyCleanSkin()
        CreateLeaveVehicleButton()
        UpdateLeaveVehicleButton()
        if UnitInVehicle("player") then BonusWatchdog:Show() end
    elseif event == "UNIT_ENTERED_VEHICLE" then
        if unit == "player" then
            UpdateLeaveVehicleButton(true)
            ReoverlayBonusBar()
            BonusWatchdog:Show()
        end
    elseif event == "UNIT_EXITED_VEHICLE" then
        if unit == "player" then
            BonusWatchdog:Hide()
            UpdateLeaveVehicleButton(false)
            RestoreMainBarAlpha()
        end
    elseif event == "PLAYER_CONTROL_GAINED" then
        BonusWatchdog:Hide()
        UpdateLeaveVehicleButton(false)
        RestoreMainBarAlpha()
    elseif event == "VEHICLE_UPDATE" or event == "UPDATE_BONUS_ACTIONBAR" then
        UpdateLeaveVehicleButton()
        ReoverlayBonusBar()
    end
end)

hooksecurefunc("UIParent_ManageFramePositions", ApplySelectiveLockdown)
hooksecurefunc("MultiActionBar_Update", ApplySelectiveLockdown)