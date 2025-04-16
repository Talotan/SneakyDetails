-- SneakyDetails
-- Controls visibility of Details! damage meters based on combat status

local addonName, SD = ...
local f = CreateFrame("Frame")

-- Default settings
local defaults = {
    hidingDelay = 5,
    autoHide = true,
    disableInInstances = true,
    showButton = true,
    buttonPosition = {point = "CENTER", relPoint = "CENTER", x = 0, y = 0},
}

-- Variables
local combatEnd = 0
local inInstance = false
local instanceEntered = false
local toggleButton
local optionsFrame

-- Make functions accessible in global scope for the addon
SD.ToggleDetails = function(show)
    if show then
        -- Try different ways to show Details
        if SlashCmdList["DETAILS"] then
            SlashCmdList["DETAILS"]("show")
        elseif _G._detalhes and _G._detalhes.OpenAllWindows then
            _G._detalhes:OpenAllWindows()
        elseif _G._detalhes and _G._detalhes.tabela_instancias then
            for i, instance in ipairs(_G._detalhes.tabela_instancias) do
                if instance.baseframe then
                    instance.baseframe:Show()
                end
            end
        end
    else
        -- Try different ways to hide Details
        if SlashCmdList["DETAILS"] then
            SlashCmdList["DETAILS"]("hide")
        elseif _G._detalhes and _G._detalhes.ShutDownAllInstances then
            _G._detalhes:ShutDownAllInstances()
        elseif _G._detalhes and _G._detalhes.tabela_instancias then
            for i, instance in ipairs(_G._detalhes.tabela_instancias) do
                if instance.baseframe then
                    instance.baseframe:Hide()
                end
            end
        end
    end
end

-- Create a standalone options frame
SD.CreateOptionsFrame = function()
    if optionsFrame then
        optionsFrame:Show()
        return
    end
    
    -- Create the main frame
    optionsFrame = CreateFrame("Frame", "SneakyDetailsOptionsFrame", UIParent, "BasicFrameTemplateWithInset")
    optionsFrame:SetSize(300, 300)  -- Changed to 300x300 as requested
    optionsFrame:SetPoint("CENTER")
    optionsFrame:SetMovable(true)
    optionsFrame:EnableMouse(true)
    optionsFrame:RegisterForDrag("LeftButton")
    optionsFrame:SetScript("OnDragStart", optionsFrame.StartMoving)
    optionsFrame:SetScript("OnDragStop", optionsFrame.StopMovingOrSizing)
    optionsFrame:SetClampedToScreen(true)
    
    -- Set the title
    optionsFrame.title = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    optionsFrame.title:SetPoint("TOP", optionsFrame, "TOP", 0, -5)
    optionsFrame.title:SetText("SneakyDetails Options")
    
    -- Auto-Hide checkbox
    local autoHideCheckbox = CreateFrame("CheckButton", "SneakyDetailsAutoHideCheckbox", optionsFrame, "UICheckButtonTemplate")
    autoHideCheckbox:SetPoint("TOPLEFT", optionsFrame, "TOPLEFT", 20, -40)
    autoHideCheckbox.text:SetText("Auto-Hide")
    autoHideCheckbox.tooltipText = "Automatically hide Details when out of combat"
    autoHideCheckbox:SetChecked(SneakyDetailsDB.autoHide)
    autoHideCheckbox:SetScript("OnClick", function(self)
        SneakyDetailsDB.autoHide = self:GetChecked()
        print("|cff33ff99SneakyDetails|r: Auto-hiding " .. (SneakyDetailsDB.autoHide and "enabled" or "disabled") .. ".")
    end)
    
    -- Delay text
    local delayText = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    delayText:SetPoint("TOPLEFT", autoHideCheckbox, "BOTTOMLEFT", 0, -20)
    delayText:SetText("Hide Delay (seconds):")
    
    -- Hiding Delay slider
    local delaySlider = CreateFrame("Slider", "SneakyDetailsDelaySlider", optionsFrame, "OptionsSliderTemplate")
    delaySlider:SetPoint("TOPLEFT", delayText, "BOTTOMLEFT", 0, -15)
    delaySlider:SetWidth(260)
    delaySlider:SetMinMaxValues(0, 30)
    delaySlider:SetValueStep(1)
    delaySlider:SetObeyStepOnDrag(true)
    delaySlider:SetValue(SneakyDetailsDB.hidingDelay)
    getglobal(delaySlider:GetName() .. "Low"):SetText("0")
    getglobal(delaySlider:GetName() .. "High"):SetText("30")
    getglobal(delaySlider:GetName() .. "Text"):SetText(SneakyDetailsDB.hidingDelay)
    
    delaySlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5)
        SneakyDetailsDB.hidingDelay = value
        getglobal(self:GetName() .. "Text"):SetText(value)
        -- Removed chat message for delay change
    end)
    
    -- Instance behavior checkbox
    local instanceCheckbox = CreateFrame("CheckButton", "SneakyDetailsInstanceCheckbox", optionsFrame, "UICheckButtonTemplate")
    instanceCheckbox:SetPoint("TOPLEFT", delaySlider, "BOTTOMLEFT", 0, -20)
    instanceCheckbox.text:SetText("Always Show in Instances")
    instanceCheckbox.tooltipText = "Always show Details when in dungeons, raids or scenarios"
    instanceCheckbox:SetChecked(SneakyDetailsDB.disableInInstances)
    instanceCheckbox:SetScript("OnClick", function(self)
        SneakyDetailsDB.disableInInstances = self:GetChecked()
        print("|cff33ff99SneakyDetails|r: Auto-hiding in instances " .. (SneakyDetailsDB.disableInInstances and "disabled" or "enabled") .. ".")
    end)
    
    -- Toggle button checkbox
    local buttonCheckbox = CreateFrame("CheckButton", "SneakyDetailsButtonCheckbox", optionsFrame, "UICheckButtonTemplate")
    buttonCheckbox:SetPoint("TOPLEFT", instanceCheckbox, "BOTTOMLEFT", 0, -20)
    buttonCheckbox.text:SetText("Show Toggle Button")
    buttonCheckbox.tooltipText = "Show a movable button to toggle Details visibility"
    buttonCheckbox:SetChecked(SneakyDetailsDB.showButton)
    buttonCheckbox:SetScript("OnClick", function(self)
        SneakyDetailsDB.showButton = self:GetChecked()
        if SneakyDetailsDB.showButton then
            if not toggleButton then
                SD.CreateToggleButton()
            else
                toggleButton:Show()
            end
            print("|cff33ff99SneakyDetails|r: Toggle button enabled.")
        else
            if toggleButton then
                toggleButton:Hide()
            end
            print("|cff33ff99SneakyDetails|r: Toggle button disabled.")
        end
    end)
    
    -- Done button
    local doneButton = CreateFrame("Button", nil, optionsFrame, "UIPanelButtonTemplate")
    doneButton:SetSize(100, 25)
    doneButton:SetPoint("BOTTOM", 0, 15)
    doneButton:SetText("Done")
    doneButton:SetScript("OnClick", function()
        optionsFrame:Hide()
    end)
end

-- Create a toggle button for Details
SD.CreateToggleButton = function()
    -- Create the button
    toggleButton = CreateFrame("Button", "SneakyDetailsToggleButton", UIParent)
    toggleButton:SetSize(24, 24)  -- Changed to 24x24 as requested
    toggleButton:SetPoint("CENTER", UIParent, "CENTER", 0, 0) -- Default position
    
    -- Make the button movable
    toggleButton:SetMovable(true)
    toggleButton:EnableMouse(true)
    toggleButton:RegisterForDrag("LeftButton")
    toggleButton:SetScript("OnDragStart", toggleButton.StartMoving)
    toggleButton:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Save position for future sessions
        local point, _, relPoint, x, y = self:GetPoint()
        SneakyDetailsDB.buttonPosition = {point = point, relPoint = relPoint, x = x, y = y}
    end)
    
    -- Set up the button textures
    local iconPath = "Interface\\AddOns\\SneakyDetails\\icon"
    local iconBWPath = "Interface\\AddOns\\SneakyDetails\\icon-bw"
    
    -- Check if the files exist (this check isn't 100% reliable but helps)
    local fileExists = true
    local bwFileExists = true
    
    pcall(function() 
        local test = GetFileIDFromPath(iconPath)
        if not test or test == 0 then fileExists = false end
    end)
    
    pcall(function() 
        local test = GetFileIDFromPath(iconBWPath)
        if not test or test == 0 then bwFileExists = false end
    end)
    
    -- Use fallback if icons not found
    if not fileExists then
        iconPath = "Interface\\Icons\\Ability_Rogue_Disguise"  -- A stealth icon, good for "Sneaky" Details
    end
    
    if not bwFileExists then
        iconBWPath = "Interface\\Icons\\Ability_Rogue_Disguise_Ghost"  -- Desaturated version
        if not GetFileIDFromPath(iconBWPath) then
            iconBWPath = iconPath -- Fallback to same icon if ghost version doesn't exist
        end
    end
    
    -- Set initial texture based on Details visibility
    local detailsObject = _G._detalhes and _G._detalhes.tabela_instancias and _G._detalhes.tabela_instancias[1]
    local isVisible = detailsObject and detailsObject.baseframe and detailsObject.baseframe:IsShown()
    
    if isVisible then
        toggleButton:SetNormalTexture(iconPath)
        toggleButton:SetPushedTexture(iconPath)
    else
        toggleButton:SetNormalTexture(iconBWPath)
        toggleButton:SetPushedTexture(iconBWPath)
    end
    
    -- Make the pushed texture slightly smaller to give a "pressed" effect
    local pushed = toggleButton:GetPushedTexture()
    pushed:ClearAllPoints()
    pushed:SetPoint("TOPLEFT", toggleButton, "TOPLEFT", 2, -2)
    pushed:SetPoint("BOTTOMRIGHT", toggleButton, "BOTTOMRIGHT", -2, 2)
    
    -- Add tooltip
    toggleButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("SneakyDetails")
        GameTooltip:AddLine("Left-click: Toggle Details visibility", 1, 1, 1)
        GameTooltip:AddLine("Right-click: Open SneakyDetails options", 1, 1, 1)
        GameTooltip:AddLine("Middle-click: Open Details! options", 1, 1, 1)
        GameTooltip:AddLine("Drag: Move button", 1, 1, 1)
        GameTooltip:Show()
    end)
    toggleButton:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    -- Handle button clicks
    toggleButton:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
    toggleButton:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            -- Toggle Details visibility
            local detailsObject = _G._detalhes and _G._detalhes.tabela_instancias and _G._detalhes.tabela_instancias[1]
            local isVisible = detailsObject and detailsObject.baseframe and detailsObject.baseframe:IsShown()
            SD.ToggleDetails(not isVisible)
            
            -- Update button texture based on new visibility state
            if not isVisible then -- It will become visible
                self:SetNormalTexture(iconPath)
                self:SetPushedTexture(iconPath)
            else -- It will become hidden
                self:SetNormalTexture(iconBWPath)
                self:SetPushedTexture(iconBWPath)
            end
            
            -- Make sure the pushed texture stays properly sized
            local pushed = self:GetPushedTexture()
            pushed:ClearAllPoints()
            pushed:SetPoint("TOPLEFT", self, "TOPLEFT", 2, -2)
            pushed:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -2, 2)
        elseif button == "RightButton" then
            -- Open options window
            SD.CreateOptionsFrame()
        elseif button == "MiddleButton" then
            -- Open official Details options
            if SlashCmdList["DETAILS"] then
                SlashCmdList["DETAILS"]("options")
            elseif _G._detalhes and _G._detalhes.OpenOptionsWindow then
                _G._detalhes:OpenOptionsWindow()
            else
                -- Fallback if the above methods don't work
                ChatFrame1:AddMessage("|cff33ff99SneakyDetails|r: Unable to open Details! options directly. Try typing /details options")
            end
        end
    end)
    
    -- Restore saved position if available
    if SneakyDetailsDB.buttonPosition then
        toggleButton:ClearAllPoints()
        toggleButton:SetPoint(
            SneakyDetailsDB.buttonPosition.point,
            UIParent,
            SneakyDetailsDB.buttonPosition.relPoint,
            SneakyDetailsDB.buttonPosition.x,
            SneakyDetailsDB.buttonPosition.y
        )
    end
    
    -- Update icon when Details visibility changes from other sources
    if not SD.HookDetailsVisibility then
        SD.HookDetailsVisibility = true
        -- Hook the ToggleDetails function to update our button
        local originalToggleDetails = SD.ToggleDetails
        SD.ToggleDetails = function(show)
            originalToggleDetails(show)
            
            -- Only update if our button exists
            if toggleButton and toggleButton:IsShown() then
                if show then
                    toggleButton:SetNormalTexture(iconPath)
                    toggleButton:SetPushedTexture(iconPath)
                else
                    toggleButton:SetNormalTexture(iconBWPath)
                    toggleButton:SetPushedTexture(iconBWPath)
                end
                
                -- Make sure the pushed texture stays properly sized
                local pushed = toggleButton:GetPushedTexture()
                pushed:ClearAllPoints()
                pushed:SetPoint("TOPLEFT", toggleButton, "TOPLEFT", 2, -2)
                pushed:SetPoint("BOTTOMRIGHT", toggleButton, "BOTTOMRIGHT", -2, 2)
            end
        end
    end
end

-- Initialize addon
local function Initialize()
    -- Load saved variables
    SneakyDetailsDB = SneakyDetailsDB or {}
    
    -- Apply defaults for any missing values
    for k, v in pairs(defaults) do
        if SneakyDetailsDB[k] == nil then
            SneakyDetailsDB[k] = v
        end
    end
    
    -- Create the toggle button if enabled
    if SneakyDetailsDB.showButton then
        SD.CreateToggleButton()
    end
    
    -- Print loading message
    print("|cff33ff99SneakyDetails|r loaded. Type |cffFFFF00/sd help|r for commands.")
end

-- Handle events
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:RegisterEvent("ADDON_LOADED")

f:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_REGEN_DISABLED" then
        -- Entered combat, show Details
        if SneakyDetailsDB.autoHide and not (inInstance and SneakyDetailsDB.disableInInstances) then
            SD.ToggleDetails(true)
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Exited combat, start timer
        combatEnd = GetTime()
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        -- Check if we're in an instance
        local inInst, instanceType = IsInInstance()
        inInstance = inInst and (instanceType == "party" or instanceType == "raid" or instanceType == "scenario")
        
        -- If we just entered an instance and have the setting enabled, show Details
        if inInstance and SneakyDetailsDB.disableInInstances and not instanceEntered then
            SD.ToggleDetails(true)
            instanceEntered = true
        elseif not inInstance and instanceEntered then
            instanceEntered = false
        end
    elseif event == "ADDON_LOADED" and arg1 == addonName then
        -- Initialize on load
        Initialize()
    end
end)

-- Handle update (for timer)
f:SetScript("OnUpdate", function(self, elapsed)
    if combatEnd > 0 and SneakyDetailsDB.autoHide and SneakyDetailsDB.hidingDelay > 0 and 
        not InCombatLockdown() and not (inInstance and SneakyDetailsDB.disableInInstances) then
        
        local timePassed = GetTime() - combatEnd
        
        if timePassed >= SneakyDetailsDB.hidingDelay then
            SD.ToggleDetails(false)
            combatEnd = 0
        end
    end
end)

-- Slash commands
SLASH_SNEAKYDETAILS1 = "/sneakydetails"
SLASH_SNEAKYDETAILS2 = "/sd"

SlashCmdList["SNEAKYDETAILS"] = function(msg)
    local args = {}
    for word in msg:lower():gmatch("%S+") do
        table.insert(args, word)
    end
    
    local command = args[1] or "help"
    
    if command == "show" then
        SD.ToggleDetails(true)
        -- Removed chat message for showing Details
    elseif command == "hide" then
        SD.ToggleDetails(false)
        -- Removed chat message for hiding Details
    elseif command == "toggle" then
        -- Try to detect current state
        local detailsObject = _G._detalhes and _G._detalhes.tabela_instancias and _G._detalhes.tabela_instancias[1]
        local isVisible = detailsObject and detailsObject.baseframe and detailsObject.baseframe:IsShown()
        SD.ToggleDetails(not isVisible)
        -- Removed chat message for toggling Details
    elseif command == "delay" then
        local value = tonumber(args[2])
        if value and value >= 0 and value <= 30 then
            SneakyDetailsDB.hidingDelay = value
            -- Removed chat message for delay change
        else
            print("|cff33ff99SneakyDetails|r: Current delay is " .. SneakyDetailsDB.hidingDelay .. " seconds.")
            print("|cff33ff99SneakyDetails|r: Usage: /sd delay <value> (0-30)")
        end
    elseif command == "auto" then
        if args[2] == "on" then
            SneakyDetailsDB.autoHide = true
            print("|cff33ff99SneakyDetails|r: Auto-hiding enabled.")
        elseif args[2] == "off" then
            SneakyDetailsDB.autoHide = false
            print("|cff33ff99SneakyDetails|r: Auto-hiding disabled.")
        else
            if SneakyDetailsDB.autoHide then
                print("|cff33ff99SneakyDetails|r: Auto-hiding is currently enabled.")
            else
                print("|cff33ff99SneakyDetails|r: Auto-hiding is currently disabled.")
            end
            print("|cff33ff99SneakyDetails|r: Usage: /sd auto on|off")
        end
    elseif command == "instance" then
        if args[2] == "on" then
            SneakyDetailsDB.disableInInstances = true
            print("|cff33ff99SneakyDetails|r: Auto-hiding disabled in instances.")
        elseif args[2] == "off" then
            SneakyDetailsDB.disableInInstances = false
            print("|cff33ff99SneakyDetails|r: Auto-hiding enabled in instances.")
        else
            if SneakyDetailsDB.disableInInstances then
                print("|cff33ff99SneakyDetails|r: Auto-hiding is disabled in instances.")
            else
                print("|cff33ff99SneakyDetails|r: Auto-hiding is enabled in instances.")
            end
            print("|cff33ff99SneakyDetails|r: Usage: /sd instance on|off")
        end
    elseif command == "button" then
        if args[2] == "on" then
            SneakyDetailsDB.showButton = true
            if not toggleButton then
                SD.CreateToggleButton()
            else
                toggleButton:Show()
            end
            print("|cff33ff99SneakyDetails|r: Toggle button enabled.")
        elseif args[2] == "off" then
            SneakyDetailsDB.showButton = false
            if toggleButton then
                toggleButton:Hide()
            end
            print("|cff33ff99SneakyDetails|r: Toggle button disabled.")
        else
            print("|cff33ff99SneakyDetails|r: Toggle button is currently " .. (SneakyDetailsDB.showButton and "enabled" or "disabled") .. ".")
            print("|cff33ff99SneakyDetails|r: Usage: /sd button on|off")
        end
    elseif command == "options" then
        SD.CreateOptionsFrame()
        print("|cff33ff99SneakyDetails|r: Opening options window.")
    elseif command == "status" or command == "info" then
        print("|cff33ff99SneakyDetails|r: Status:")
        print("  Auto-hide: " .. (SneakyDetailsDB.autoHide and "Enabled" or "Disabled"))
        print("  Hide delay: " .. SneakyDetailsDB.hidingDelay .. " seconds")
        print("  Instance behavior: " .. (SneakyDetailsDB.disableInInstances and "Always show" or "Follow auto-hide rules"))
        print("  Toggle button: " .. (SneakyDetailsDB.showButton and "Enabled" or "Disabled"))
        print("  Currently in instance: " .. (inInstance and "Yes" or "No"))
    elseif command == "reset" then
        SneakyDetailsDB = {}
        for k, v in pairs(defaults) do
            SneakyDetailsDB[k] = v
        end
        print("|cff33ff99SneakyDetails|r: Settings reset to defaults.")
    else
        print("|cff33ff99SneakyDetails|r: Available commands:")
        print("  /sd show - Show Details")
        print("  /sd hide - Hide Details")
        print("  /sd toggle - Toggle Details visibility")
        print("  /sd delay [seconds] - Get/set auto-hide delay (0-30)")
        print("  /sd auto [on|off] - Enable/disable auto-hiding")
        print("  /sd instance [on|off] - Disable/enable auto-hiding in instances")
        print("  /sd button [on|off] - Show/hide the toggle button")
        print("  /sd options - Open the settings window")
        print("  /sd status - Show current settings")
        print("  /sd reset - Reset all settings to defaults")
    end
end