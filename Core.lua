local _, UI = ...

local Setup = CreateFrame("Frame")
Setup:RegisterEvent("PLAYER_LOGIN")
Setup:RegisterEvent("PLAYER_ENTERING_WORLD")

Setup:SetScript("OnEvent", function(self, event)
    CleanUIPositions = CleanUIPositions or {}
    
    if CleanUI_UseClassPortraits == nil then 
        CleanUI_UseClassPortraits = true 
    end
    
    if CleanUIPositions.MinimalistMode == nil then 
        CleanUIPositions.MinimalistMode = true 
    end

    if TargetFrameToTHealthBar then UI.ProtectFrame(TargetFrameToTHealthBar) end
    if FocusFrameToTHealthBar then UI.ProtectFrame(FocusFrameToTHealthBar) end
end)

SLASH_CLEANUI1 = "/cui"
SlashCmdList["CLEANUI"] = function(msg)
    msg = msg:lower()
    
    if msg == "reset" then
        CleanUIPositions = {} 
        CleanUIPositions.MinimalistMode = true 

        local frames = {
            PlayerFrame, TargetFrame, FocusFrame, PetFrame, 
            TargetFrameToT, FocusFrameToT, 
            CleanUILootAnchor, CleanUIActionBarAnchor, CleanUIPartyAnchor,
            CleanUIPetBarAnchor, CleanUIStanceBarAnchor, CleanUIMicroMenuAnchor, CleanUIBagBarAnchor,
        }
        
        for i = 1, 4 do
            table.insert(frames, _G["PartyMemberFrame"..i])
            table.insert(frames, _G["PartyMemberFrame"..i.."PetFrame"])
        end

        for _, f in pairs(frames) do 
            if f then 
                if f.SetMovable then f:SetMovable(true) end
                f:SetUserPlaced(false) 
                f:ClearAllPoints()     
            end 
        end

        print("|cff00ff00CleanUI:|r UI reset to Blizzlike (Gryphons Hidden). Reloading...")
        ReloadUI()

    elseif msg:find("loot") and msg:find("test") then
        CleanUI_LootTestActive = not CleanUI_LootTestActive
        if UI.UpdateLootTest then UI.UpdateLootTest() end
        print("|cff00ff00CleanUI:|r Loot Test Mode " .. (CleanUI_LootTestActive and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r"))

    elseif msg:find("party") and msg:find("test") then
        CleanUI_TestActive = not CleanUI_TestActive
        if UI.UpdatePartyLayout then UI.UpdatePartyLayout() end
        print("|cff00ff00CleanUI:|r Party Test Mode " .. (CleanUI_TestActive and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r"))

    elseif msg == "portrait" then
        CleanUI_UseClassPortraits = not CleanUI_UseClassPortraits
        if UI.RefreshPortraits then UI.RefreshPortraits() end
        print("|cff00ff00CleanUI:|r Portraits toggled.")

    elseif msg == "vehicle" then
        if CleanUILeaveVehicleButton and CleanUILeaveVehicleButton:IsShown() then
            CleanUILeaveVehicleButton:Click()
        end
        if UI.ApplyPetAnchorPosition then UI.ApplyPetAnchorPosition(false) end
        if UI.UpdateLeaveVehicleButton then UI.UpdateLeaveVehicleButton(false) end
        print("|cff00ff00CleanUI:|r Vehicle UI reset.")
    end
end

hooksecurefunc("TargetofTarget_Update", function(self)
    if InCombatLockdown() then return end
    local name = (self == TargetFrameToT) and "TargetFrameToT" or "FocusFrameToT"
    local parent = (self == TargetFrameToT) and TargetFrame or FocusFrame

    if not CleanUIPositions or not CleanUIPositions[name] then
        self:ClearAllPoints()
        self:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -10, -10)
    end
end)