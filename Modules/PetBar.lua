local _, UI = ...
local F = CreateFrame("Frame")
F:RegisterEvent("PLAYER_ENTERING_WORLD")
F:RegisterEvent("UNIT_ENTERED_VEHICLE")
F:RegisterEvent("UNIT_EXITED_VEHICLE")
F:RegisterEvent("PLAYER_REGEN_ENABLED")
F:RegisterEvent("UPDATE_BINDINGS")
F:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
F:RegisterEvent("PLAYER_CONTROL_GAINED")

local PET_BUTTON_SIZE = 36
local PET_BUTTON_SPACING = 6

local Hider = CreateFrame("Frame", "CleanUIPetHider", UIParent)
Hider:Hide()

local function GetAnchor()
    return _G["CleanUIPetBarAnchor"]
end

-- Re-route CTRL+SHIFT+drag on a pet button to the anchor frame so the user can
-- move the whole bar by grabbing any button (matches the Mover.lua UX). Gated on
-- InCombatLockdown to avoid tainting the secure PetActionButton during combat.
local function RedirectClickToAnchor(self, button)
    if InCombatLockdown() then return end
    if button == "LeftButton" and IsShiftKeyDown() and IsControlKeyDown() then
        local anchor = GetAnchor()
        if anchor and anchor:GetScript("OnMouseDown") then
            anchor:GetScript("OnMouseDown")(anchor, button)
        end
    end
end

local function RedirectReleaseToAnchor(self, button)
    if InCombatLockdown() then return end
    local anchor = GetAnchor()
    if anchor and anchor.isCleanUIMoving and anchor:GetScript("OnMouseUp") then
        anchor:GetScript("OnMouseUp")(anchor, button)
    end
end

local function SkinButton(btn)
    if not btn then return end
    local name = btn:GetName()
    local icon = _G[name.."Icon"]
    local hotkey = _G[name.."HotKey"]
    if icon then icon:SetTexCoord(0, 1, 0, 1) end
    if btn:GetNormalTexture() then btn:GetNormalTexture():SetAlpha(1) end
    if hotkey then
        hotkey:SetFont("Fonts\\ARIALN.TTF", 12, "OUTLINE")
        hotkey:ClearAllPoints()
        hotkey:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -2, -3)
        hotkey:Show()
    end

    if not btn.cleanUIHooked then
        btn:HookScript("OnMouseDown", RedirectClickToAnchor)
        btn:HookScript("OnMouseUp", RedirectReleaseToAnchor)
        btn.cleanUIHooked = true
    end
end

-- Pet/vehicle buttons in 3.3.5 are bound under BONUSACTIONBUTTONn, not PETACTIONBUTTONn.
local function UpdatePetBindings()
    for i = 1, 10 do
        local hotkey = _G["PetActionButton"..i.."HotKey"]
        if hotkey then
            local key = GetBindingKey("BONUSACTIONBUTTON"..i)
            if key and key ~= "" then
                key = key:gsub("SHIFT%-", "S-"):gsub("ALT%-", "A-"):gsub("CTRL%-", "C-")
                hotkey:SetText(key)
                hotkey:Show()
            else
                hotkey:SetText("")
                hotkey:Hide()
            end
        end
    end
end

-- Argent Tournament steeds, Oculus drakes, and similar 3.3.5 vehicles route abilities
-- through the pet action bar. inVehicle: pass explicit state from transition events;
-- UnitInVehicle can lag behind UNIT_EXITED_VEHICLE on Oculus.
local function ApplyPetAnchorPosition(inVehicle)
    local petAnchor = _G["CleanUIPetBarAnchor"]
    if not petAnchor then return end

    if InCombatLockdown() then
        F.needsUpdate = true
        return
    end
    F.needsUpdate = false

    if inVehicle == nil then
        inVehicle = UnitInVehicle("player")
    end

    local key
    if inVehicle and ActionButton1 then
        key = "vehicle"
    elseif CleanUIPositions and CleanUIPositions["PetBarAnchor"] then
        local p = CleanUIPositions["PetBarAnchor"]
        key = "saved:"..p.pt..":"..p.rel..":"..tostring(p.x)..":"..tostring(p.y)
    else
        key = "default"
    end
    if petAnchor.cleanUIPositionKey == key then return end
    petAnchor.cleanUIPositionKey = key

    petAnchor:ClearAllPoints()
    if key == "vehicle" then
        petAnchor:SetPoint("BOTTOMLEFT", ActionButton1, "BOTTOMLEFT", 0, 0)
    elseif key == "default" then
        petAnchor:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
    else
        local p = CleanUIPositions["PetBarAnchor"]
        petAnchor:SetPoint(p.pt, UIParent, p.rel, p.x, p.y)
        petAnchor:SetUserPlaced(true)
    end
end

UI.ApplyPetAnchorPosition = ApplyPetAnchorPosition

local function ApplyPetBarSkin()
    if CleanUIPositions and CleanUIPositions.MinimalistMode then return end
    if not PetActionBarFrame then return end

    local petAnchor = _G["CleanUIPetBarAnchor"] or CreateFrame("Frame", "CleanUIPetBarAnchor", UIParent, "SecureHandlerStateTemplate")
    local barWidth = (PET_BUTTON_SIZE * 10) + (PET_BUTTON_SPACING * 9)
    petAnchor:SetSize(barWidth, PET_BUTTON_SIZE)
    petAnchor:SetClampedToScreen(true)

    if UI.MakeMovableAndSave then
        UI.MakeMovableAndSave(petAnchor, "PetBarAnchor")
    end

    ApplyPetAnchorPosition()

    -- Reduce PetActionBarFrame to a 1x1 invisible nub so Blizzard's slide animation and
    -- ShowPetActionBar/HidePetActionBar have nothing visible to act on. The buttons are
    -- reparented to our anchor (below), so they're no longer affected by it.
    PetActionBarFrame:SetAlpha(0)
    PetActionBarFrame:EnableMouse(false)
    PetActionBarFrame:SetSize(1, 1)

    -- showgrid=1 disables the alpha-fade animation path in PetActionBar_OnUpdate entirely.
    -- Without this the buttons would fade to alpha 0 every time HidePetActionBar fires,
    -- regardless of who their parent is.
    PetActionBarFrame.showgrid = 1
    if PetActionBar_ShowGrid then PetActionBar_ShowGrid() end

    local artFrames = {SlidingActionBarTexture0, SlidingActionBarTexture1}
    for _, frame in ipairs(artFrames) do
        if frame then frame:SetParent(Hider) end
    end

    for i = 1, 10 do
        local btn = _G["PetActionButton"..i]
        if btn then
            btn:SetParent(petAnchor)
            btn:SetFrameLevel(5)
            btn:SetSize(PET_BUTTON_SIZE, PET_BUTTON_SIZE)
            btn:ClearAllPoints()
            btn:SetAlpha(1)

            if i == 1 then
                btn:SetPoint("BOTTOMLEFT", petAnchor, "BOTTOMLEFT", 0, 0)
            else
                btn:SetPoint("LEFT", _G["PetActionButton"..(i-1)], "RIGHT", PET_BUTTON_SPACING, 0)
            end

            SkinButton(btn)
        end
    end

    UpdatePetBindings()

    RegisterStateDriver(petAnchor, "visibility", "[pet] show; hide")
end

F:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_ENTERING_WORLD" then
        ApplyPetBarSkin()
    elseif event == "UNIT_ENTERED_VEHICLE" then
        if unit == "player" then ApplyPetAnchorPosition(true) end
    elseif event == "UNIT_EXITED_VEHICLE" then
        if unit == "player" then ApplyPetAnchorPosition(false) end
    elseif event == "PLAYER_CONTROL_GAINED" then
        ApplyPetAnchorPosition(false)
    elseif event == "UPDATE_BONUS_ACTIONBAR" then
        ApplyPetAnchorPosition()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if self.needsUpdate then ApplyPetAnchorPosition() end
    elseif event == "UPDATE_BINDINGS" then
        UpdatePetBindings()
    end
end)
