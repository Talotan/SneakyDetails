-- SneakyDetails - Control Details! visibility with style
local addonName, addonTable = ...

-- Main addon frame
local SDFrame = CreateFrame("Frame", "SneakyDetailsFrame")
SDFrame:RegisterEvent("ADDON_LOADED")
SDFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

-- Default settings
local defaults = {
    enabled = true,
    combatAutomation = true,      -- Now enabled by default
    postCombatDelay = 5,
    disableInInstance = true,      -- Now enabled by default
    showButton = true,
    fadeButton = false,
    lastDetailsState = true,
    verbose = false,               -- Now disabled by default
    buttonPosition = {
        x = 100,
        y = -100,
        point = "CENTER",
        relativeTo = "UIParent",
        relativePoint = "CENTER"
    }
}

-- Initialize variables
local SD_SavedVars
local inInstance = false
local InCombat = false
local postCombatTimer = nil
local postCombatTimerActive = false
local optionsFrame = nil
local buttonFadeTimer = nil

-- Debug function
local function PrintMessage(message)
    if SD_SavedVars and SD_SavedVars.verbose then
        print("|cFF00CCFF[SneakyDetails]|r " .. message)
    end
end

-- Function to toggle visibility of Details windows
function ToggleDetailsVisibility(show)
    -- Check if Details is loaded
    if not Details then
        PrintMessage("Details! is not loaded or enabled.")
        return
    end
    
    -- Get all instances of Details
    local instances = Details:GetAllInstances()
    
    -- If no instances found
    if #instances == 0 then
        PrintMessage("No Details! windows found.")
        return
    end
    
    -- Default behavior: if no parameter passed, toggle visibility
    if show == nil then
        -- Try to determine current state from first instance
        local firstInstance = instances[1]
        if firstInstance and firstInstance.baseframe then
            show = not firstInstance.baseframe:IsShown()
        else
            show = false
        end
    end
    
    -- Loop through all instances with safe nil checks
    for _, instance in ipairs(instances) do
        -- Safe way to set alpha or visibility on a frame
        local function SafeSetVisibility(frame, isVisible)
            if frame and type(frame) == "table" then
                if isVisible then
                    if frame.Show and type(frame.Show) == "function" then
                        frame:Show()
                    end
                    if frame.SetAlpha and type(frame.SetAlpha) == "function" then
                        frame:SetAlpha(1)
                    end
                else
                    if frame.SetAlpha and type(frame.SetAlpha) == "function" then
                        frame:SetAlpha(0)
                    end
                    if frame.Hide and type(frame.Hide) == "function" then
                        frame:Hide()
                    end
                end
            end
        end
        
        -- Handle main instance visibility
        if show then
            if instance.ativa ~= nil then
                instance.ativa = true
            end
            if type(instance.Show) == "function" then
                instance:Show()
            end
        else
            if instance.ativa ~= nil then
                instance.ativa = false
            end
            if type(instance.Hide) == "function" then
                instance:Hide()
            end
        end
        
        -- Handle baseframe visibility
        SafeSetVisibility(instance.baseframe, show)
        
        -- Handle rowframe visibility (this contains the bars)
        SafeSetVisibility(instance.rowframe, show)
        
        -- Try using Details native show/hide methods if available
        if not show and type(instance.ShutDown) == "function" then
            instance:ShutDown()
        elseif show and type(instance.AtivarInstancia) == "function" then
            instance:AtivarInstancia()
        end
    end
    
    -- Simpler direct approach as a fallback
    if not show then
        for _, instance in ipairs(instances) do
            if instance.baseframe then
                instance.baseframe:Hide()
            end
            if instance.rowframe then
                instance.rowframe:Hide()
            end
        end
    else
        for _, instance in ipairs(instances) do
            if instance.baseframe then
                instance.baseframe:Show()
            end
            if instance.rowframe then
                instance.rowframe:Show()
            end
        end
    end
    
    PrintMessage("Details! windows are now " .. (show and "|cFF00FF00visible|r" or "|cFFFF0000hidden|r"))
    
    -- Save the current state
    SD_SavedVars.lastDetailsState = show
    
    -- Update button appearance to match the current state
    if SDFrame.button then
        UpdateButtonAppearance(show)
    end
    
    return show
end

-- Function to update button appearance based on Details visibility
function UpdateButtonAppearance(isVisible)
    if not SDFrame.button then return end
    
    -- Set text based on visibility
    SDFrame.button.text:SetText(isVisible and "Hide" or "Show")
    
    -- Set background color based on visibility
    SDFrame.button.backdrop:SetBackdropColor(
        isVisible and 0.1 or 0.3,  -- Red component
        isVisible and 0.3 or 0.1,  -- Green component
        0.1,                       -- Blue component
        0.8                        -- Alpha
    )
end

-- Function to check if a Details window is visible
local function IsDetailsVisible()
    if not Details then return SD_SavedVars.lastDetailsState end
    
    local instances = Details:GetAllInstances()
    if #instances == 0 then return SD_SavedVars.lastDetailsState end
    
    local firstInstance = instances[1]
    return firstInstance and firstInstance.baseframe and firstInstance.baseframe:IsShown()
end

-- Function to fade the button in/out
local function FadeButton(fadeIn)
    if not SDFrame.button or not SD_SavedVars.fadeButton then return end
    
    -- Cancel any existing fade timer
    if buttonFadeTimer then
        C_Timer.After(0, function() 
            buttonFadeTimer = nil 
        end)
    end
    
    if fadeIn then
        -- Fade in (show button)
        SDFrame.button:SetAlpha(1)
        
        -- Set timer to fade out
        buttonFadeTimer = C_Timer.After(5, function()
            -- Fade out after 5 seconds
            if SDFrame.button and SD_SavedVars.fadeButton then
                SDFrame.button:SetAlpha(0)
            end
            buttonFadeTimer = nil
        end)
    else
        -- Fade out (hide button)
        SDFrame.button:SetAlpha(0)
    end
end

-- Simplified combat handling function
local function HandleCombatState(inCombat)
    -- Set global combat state
    InCombat = inCombat
    
    -- If in an instance with "Always Show in Instances" enabled
    if inInstance and SD_SavedVars.disableInInstance then
        ToggleDetailsVisibility(true)
        return
    end
    
    -- If combat automation is enabled
    if SD_SavedVars.combatAutomation then
        if inCombat then
            -- Show Details when entering combat
            ToggleDetailsVisibility(true)
            
            -- Cancel any existing post-combat timer by setting the flag to false
            if postCombatTimerActive then
                PrintMessage("Combat re-entered, cancelling hide timer")
                postCombatTimerActive = false
            end
        else
            -- Handle leaving combat
            if SD_SavedVars.postCombatDelay > 0 then
                -- Set the flag to true to indicate an active timer
                postCombatTimerActive = true
                
                -- Use C_Timer for post-combat delay
                C_Timer.After(SD_SavedVars.postCombatDelay, function()
                    -- Only hide Details if the timer is still active (not cancelled by entering combat)
                    if postCombatTimerActive then
                        ToggleDetailsVisibility(false)
                        postCombatTimerActive = false
                    end
                end)
            else
                -- Hide immediately if no delay
                ToggleDetailsVisibility(false)
            end
        end
    end
end

-- Function to toggle button visibility
local function UpdateButtonVisibility()
    if SDFrame.button then
        if SD_SavedVars.showButton then
            SDFrame.button:Show()
            -- Set initial alpha based on fade setting
            if SD_SavedVars.fadeButton then
                SDFrame.button:SetAlpha(0)
            else
                SDFrame.button:SetAlpha(1)
            end
        else
            SDFrame.button:Hide()
        end
    end
end

-- Create a standalone options panel
local function CreateOptionsFrame()
    -- If the frame already exists, just show it and return
    if optionsFrame then
        -- Update values in case they changed elsewhere
        if optionsFrame.delaySlider then
            optionsFrame.delaySlider:SetValue(SD_SavedVars.postCombatDelay)
        end
        if optionsFrame.combatCheck then
            optionsFrame.combatCheck:SetChecked(SD_SavedVars.combatAutomation)
        end
        if optionsFrame.instanceCheck then
            optionsFrame.instanceCheck:SetChecked(SD_SavedVars.disableInInstance)
        end
        if optionsFrame.buttonCheck then
            optionsFrame.buttonCheck:SetChecked(SD_SavedVars.showButton)
        end
        if optionsFrame.fadeCheck then
            optionsFrame.fadeCheck:SetChecked(SD_SavedVars.fadeButton)
        end
        if optionsFrame.verboseCheck then
            optionsFrame.verboseCheck:SetChecked(SD_SavedVars.verbose)
        end
        optionsFrame:Show()
        return optionsFrame
    end
    
    -- Create the main frame
    optionsFrame = CreateFrame("Frame", "SneakyDetailsOptions", UIParent, "BackdropTemplate")
    optionsFrame:SetSize(250, 360) -- More compact size
    optionsFrame:SetPoint("CENTER")
    optionsFrame:SetFrameStrata("DIALOG")
    optionsFrame:SetMovable(true)
    optionsFrame:EnableMouse(true)
    optionsFrame:RegisterForDrag("LeftButton")
    optionsFrame:SetScript("OnDragStart", optionsFrame.StartMoving)
    optionsFrame:SetScript("OnDragStop", optionsFrame.StopMovingOrSizing)
    
    -- Set backdrop
    optionsFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    
    -- Create title text
    local title = optionsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -15)
    title:SetText("SneakyDetails Options")
    
    -- Combat Automation checkbox
    local combatCheck = CreateFrame("CheckButton", "SneakyDetailsCombatCheck", optionsFrame, "UICheckButtonTemplate")
    combatCheck:SetPoint("TOPLEFT", 30, -50)
    _G[combatCheck:GetName() .. "Text"]:SetText("Combat Automation")
    combatCheck:SetChecked(SD_SavedVars.combatAutomation)
    combatCheck:SetScript("OnClick", function(self)
        SD_SavedVars.combatAutomation = self:GetChecked()
    end)
    optionsFrame.combatCheck = combatCheck
    
    -- Create a helper function for text labels
    local function CreateLabel(parent, text, anchorFrame, xOffset, yOffset)
        local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", anchorFrame, "BOTTOMLEFT", xOffset, yOffset)
        label:SetText(text)
        return label
    end
    
    -- Post-Combat Delay text and slider
    local delayLabel = CreateLabel(optionsFrame, "Post-Combat Delay: " .. SD_SavedVars.postCombatDelay .. "s", combatCheck, 0, -12)
    optionsFrame.delayLabel = delayLabel
    
    local delaySlider = CreateFrame("Slider", "SneakyDetailsDelaySlider", optionsFrame, "OptionsSliderTemplate")
    delaySlider:SetPoint("TOPLEFT", delayLabel, "BOTTOMLEFT", 0, -5)
    delaySlider:SetWidth(180) -- Reduced width
    delaySlider:SetMinMaxValues(0, 30)
    delaySlider:SetValue(SD_SavedVars.postCombatDelay)
    delaySlider:SetValueStep(1)
    delaySlider:SetObeyStepOnDrag(true)
    optionsFrame.delaySlider = delaySlider
    
    -- Set slider texts
    _G[delaySlider:GetName() .. "Low"]:SetText("0s")
    _G[delaySlider:GetName() .. "High"]:SetText("30s")
    
    -- Update slider value when changed
    delaySlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value + 0.5) -- Round to nearest integer
        SD_SavedVars.postCombatDelay = value
        delayLabel:SetText("Post-Combat Delay: " .. value .. "s")
        
        -- If there is an active post-combat timer, update it
        if postCombatTimer then
            C_Timer.After(0, function()
                postCombatTimer = C_Timer.After(value, function()
                    ToggleDetailsVisibility(false)
                    postCombatTimer = nil
                end)
            end)
        end
    end)
    
    -- Always show in instances checkbox
    local instanceCheck = CreateFrame("CheckButton", "SneakyDetailsInstanceCheck", optionsFrame, "UICheckButtonTemplate")
    instanceCheck:SetPoint("TOPLEFT", delaySlider, "BOTTOMLEFT", 0, -25)
    _G[instanceCheck:GetName() .. "Text"]:SetText("Always Show in Instances")
    instanceCheck:SetChecked(SD_SavedVars.disableInInstance)
    instanceCheck:SetScript("OnClick", function(self)
        SD_SavedVars.disableInInstance = self:GetChecked()
        -- If we're in an instance now, update visibility
        if inInstance and SD_SavedVars.disableInInstance then
            ToggleDetailsVisibility(true)
        end
    end)
    optionsFrame.instanceCheck = instanceCheck
    
    -- Show Button checkbox
    local buttonCheck = CreateFrame("CheckButton", "SneakyDetailsButtonCheck", optionsFrame, "UICheckButtonTemplate")
    buttonCheck:SetPoint("TOPLEFT", instanceCheck, "BOTTOMLEFT", 0, -5)
    _G[buttonCheck:GetName() .. "Text"]:SetText("Show On-Screen Button")
    buttonCheck:SetChecked(SD_SavedVars.showButton)
    buttonCheck:SetScript("OnClick", function(self)
        SD_SavedVars.showButton = self:GetChecked()
        UpdateButtonVisibility()
    end)
    optionsFrame.buttonCheck = buttonCheck
    
    -- Fade Button checkbox
    local fadeCheck = CreateFrame("CheckButton", "SneakyDetailsFadeCheck", optionsFrame, "UICheckButtonTemplate")
    fadeCheck:SetPoint("TOPLEFT", buttonCheck, "BOTTOMLEFT", 0, -5)
    _G[fadeCheck:GetName() .. "Text"]:SetText("Auto-Fade Button")
    fadeCheck:SetChecked(SD_SavedVars.fadeButton)
    fadeCheck:SetScript("OnClick", function(self)
        SD_SavedVars.fadeButton = self:GetChecked()
        -- Update immediately
        if SDFrame.button then
            if self:GetChecked() then
                SDFrame.button:SetAlpha(0)
            else
                SDFrame.button:SetAlpha(1)
            end
        end
    end)
    optionsFrame.fadeCheck = fadeCheck
    
    -- Verbose Output checkbox
    local verboseCheck = CreateFrame("CheckButton", "SneakyDetailsVerboseCheck", optionsFrame, "UICheckButtonTemplate")
    verboseCheck:SetPoint("TOPLEFT", fadeCheck, "BOTTOMLEFT", 0, -5)
    _G[verboseCheck:GetName() .. "Text"]:SetText("Show Chat Messages")
    verboseCheck:SetChecked(SD_SavedVars.verbose)
    verboseCheck:SetScript("OnClick", function(self)
        SD_SavedVars.verbose = self:GetChecked()
    end)
    optionsFrame.verboseCheck = verboseCheck
    
    -- Close button
    local closeButton = CreateFrame("Button", nil, optionsFrame, "UIPanelButtonTemplate")
    closeButton:SetSize(100, 25)
    closeButton:SetPoint("BOTTOM", 0, 20) -- Slightly more padding
    closeButton:SetText("Close")
    closeButton:SetScript("OnClick", function() optionsFrame:Hide() end)
    
    -- Make Escape key close the panel
    tinsert(UISpecialFrames, optionsFrame:GetName())
    
    return optionsFrame
end

-- Create a draggable button for the addon
local function CreateButton()
    -- Main button frame
    local button = CreateFrame("Button", "SneakyDetailsButton", UIParent)
    button:SetSize(50, 25) -- Adjusted size for text-only button
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(5)
    
    -- Initialize buttonPosition if it doesn't exist yet
    if not SD_SavedVars.buttonPosition then
        SD_SavedVars.buttonPosition = {
            x = 100,
            y = -100,
            point = "CENTER",
            relativeTo = "UIParent",
            relativePoint = "CENTER"
        }
    end
    
    -- Set initial position from saved variables
    local pos = SD_SavedVars.buttonPosition
    button:SetPoint(pos.point, pos.relativeTo, pos.relativePoint, pos.x, pos.y)
    
    -- Make button movable
    button:SetMovable(true)
    button:RegisterForDrag("LeftButton")
    button:SetScript("OnDragStart", function(self)
        if IsShiftKeyDown() then
            self:StartMoving()
        end
    end)
    button:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- Save position
        local point, relativeTo, relativePoint, x, y = self:GetPoint()
        SD_SavedVars.buttonPosition = {
            point = point,
            relativeTo = relativeTo and relativeTo:GetName() or "UIParent",
            relativePoint = relativePoint,
            x = x,
            y = y
        }
    end)
    
    -- Create backdrop using BackdropTemplate
    local backdrop = CreateFrame("Frame", nil, button, "BackdropTemplate")
    backdrop:SetAllPoints(button)
    backdrop:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    
    -- Set initial color based on Details visibility
    local isVisible = IsDetailsVisible()
    backdrop:SetBackdropColor(
        isVisible and 0.1 or 0.3,  -- Red component
        isVisible and 0.3 or 0.1,  -- Green component
        0.1,                       -- Blue component
        0.8                        -- Alpha
    )
    backdrop:SetBackdropBorderColor(0.7, 0.7, 0.7, 0.8)
    button.backdrop = backdrop
    
    -- Add the text (centered now that there's no icon)
    local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("CENTER", 0, 0)
    text:SetText(isVisible and "Hide" or "Show")
    button.text = text
    
    -- Setup button clicks
    button:RegisterForClicks("AnyUp")
    
    -- Handle clicks with separate handlers for each mouse button
    button:SetScript("OnClick", function(self, btnType)
        if btnType == "LeftButton" then
            ToggleDetailsVisibility()
        elseif btnType == "RightButton" then
            -- Show standalone options panel
            CreateOptionsFrame()
        end
    end)
    
    -- Add tooltip
    button:SetScript("OnEnter", function(self)
        -- Show tooltip
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("SneakyDetails")
        GameTooltip:AddLine("Left-click: Toggle Details! windows", 1, 1, 1)
        GameTooltip:AddLine("Right-click: Open settings panel", 1, 1, 1)
        GameTooltip:AddLine("Shift+drag: Move this button", 0.7, 0.7, 1)
        GameTooltip:Show()
        
        -- Fade in button if auto-fade is enabled
        if SD_SavedVars.fadeButton then
            FadeButton(true)
        end
    end)
    
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    -- Set initial visibility based on saved setting
    if not SD_SavedVars.showButton then
        button:Hide()
    else
        -- Set initial alpha based on fade setting
        if SD_SavedVars.fadeButton then
            button:SetAlpha(0)
        else
            button:SetAlpha(1)
        end
    end
    
    return button
end

-- Setup slash commands
local function SetupCommands()
    -- Create binding name
    _G["BINDING_NAME_SNEAKYDETAILS_TOGGLE"] = "Toggle Details! Visibility"
    
    -- Create slash command to toggle visibility
    SLASH_SNEAKYDETAILS1 = "/sdetails"
    SLASH_SNEAKYDETAILS2 = "/sd"
    SlashCmdList["SNEAKYDETAILS"] = function(msg)
        local cmd, arg = strsplit(" ", msg:lower(), 2)
        
        if cmd == "toggle" or cmd == "" then
            ToggleDetailsVisibility()
        elseif cmd == "show" then
            ToggleDetailsVisibility(true)
        elseif cmd == "hide" then
            ToggleDetailsVisibility(false)
        elseif cmd == "button" then
            if arg == "show" then
                SD_SavedVars.showButton = true
                UpdateButtonVisibility()
                PrintMessage("Button shown")
            elseif arg == "hide" then
                SD_SavedVars.showButton = false
                UpdateButtonVisibility()
                PrintMessage("Button hidden")
            elseif arg == "reset" then
                -- Reset button position to default
                local defaultPos = defaults.buttonPosition
                SDFrame.button:ClearAllPoints()
                SDFrame.button:SetPoint(defaultPos.point, defaultPos.relativeTo, defaultPos.relativePoint, defaultPos.x, defaultPos.y)
                SD_SavedVars.buttonPosition = {
                    point = defaultPos.point,
                    relativeTo = defaultPos.relativeTo,
                    relativePoint = defaultPos.relativePoint,
                    x = defaultPos.x,
                    y = defaultPos.y
                }
                PrintMessage("Button position reset")
            elseif arg == "fade" then
                SD_SavedVars.fadeButton = not SD_SavedVars.fadeButton
                PrintMessage("Button fading " .. (SD_SavedVars.fadeButton and "enabled" or "disabled"))
                
                -- Update button immediately
                if SDFrame.button then
                    if SD_SavedVars.fadeButton then
                        SDFrame.button:SetAlpha(0)
                    else
                        SDFrame.button:SetAlpha(1)
                    end
                end
                
                -- Update options frame if it's open
                if optionsFrame and optionsFrame:IsShown() and optionsFrame.fadeCheck then
                    optionsFrame.fadeCheck:SetChecked(SD_SavedVars.fadeButton)
                end
            else
                PrintMessage("Button options: show, hide, reset, fade")
            end
        elseif cmd == "combat" then
            SD_SavedVars.combatAutomation = not SD_SavedVars.combatAutomation
            PrintMessage("Combat automation " .. 
                (SD_SavedVars.combatAutomation and "enabled" or "disabled"))
            
            -- Update options frame if it's open
            if optionsFrame and optionsFrame:IsShown() and optionsFrame.combatCheck then
                optionsFrame.combatCheck:SetChecked(SD_SavedVars.combatAutomation)
            end
        elseif cmd == "delay" then
            local delay = tonumber(arg)
            if delay and delay >= 0 and delay <= 30 then
                SD_SavedVars.postCombatDelay = delay
                PrintMessage("Post-combat delay set to " .. delay .. " seconds")
                
                -- Update options frame if it's open
                if optionsFrame and optionsFrame:IsShown() then
                    if optionsFrame.delaySlider then
                        optionsFrame.delaySlider:SetValue(delay)
                    end
                    if optionsFrame.delayLabel then
                        optionsFrame.delayLabel:SetText("Post-Combat Delay: " .. delay .. "s")
                    end
                end
            else
                PrintMessage("Delay must be between 0 and 30 seconds")
            end
        elseif cmd == "instance" then
            SD_SavedVars.disableInInstance = not SD_SavedVars.disableInInstance
            PrintMessage("Always show in instances " .. 
                (SD_SavedVars.disableInInstance and "enabled" or "disabled"))
            
            -- Update options frame if it's open
            if optionsFrame and optionsFrame:IsShown() and optionsFrame.instanceCheck then
                optionsFrame.instanceCheck:SetChecked(SD_SavedVars.disableInInstance)
            end
        elseif cmd == "verbose" then
            SD_SavedVars.verbose = not SD_SavedVars.verbose
            -- Force print this message regardless of verbose setting
            print("|cFF00CCFF[SneakyDetails]|r Chat messages " .. 
                (SD_SavedVars.verbose and "enabled" or "disabled"))
            
            -- Update options frame if it's open
            if optionsFrame and optionsFrame:IsShown() and optionsFrame.verboseCheck then
                optionsFrame.verboseCheck:SetChecked(SD_SavedVars.verbose)
            end
        elseif cmd == "options" or cmd == "config" then
            -- Show options panel
            CreateOptionsFrame()
        elseif cmd == "help" then
            print("|cFF00CCFF[SneakyDetails]|r Commands:")
            print("  /sd - Toggle Details! visibility")
            print("  /sd show - Show Details!")
            print("  /sd hide - Hide Details!")
            print("  /sd button show/hide/reset/fade - Control the button")
            print("  /sd combat - Toggle combat automation")
            print("  /sd delay <seconds> - Set post-combat delay (0-30)")
            print("  /sd instance - Toggle always showing in instances")
            print("  /sd verbose - Toggle chat messages")
            print("  /sd options - Open options panel")
            print("  /sd help - Show this help message")
        end
    end
end

-- Helper function to ensure all saved variables exist
local function EnsureSavedVariables()
    -- Create missing fields with default values
    for key, value in pairs(defaults) do
        if SD_SavedVars[key] == nil then
            if type(value) == "table" then
                SD_SavedVars[key] = {}
                for k, v in pairs(value) do
                    SD_SavedVars[key][k] = v
                end
            else
                SD_SavedVars[key] = value
            end
        end
    end
end

-- Event handler function
local function OnEvent(self, event, arg1, ...)
    if event == "ADDON_LOADED" and arg1 == addonName then
        -- Initialize saved variables
        if not SneakyDetails_SavedVars then
            SneakyDetails_SavedVars = {}
            for k, v in pairs(defaults) do
                if type(v) == "table" then
                    SneakyDetails_SavedVars[k] = {}
                    for k2, v2 in pairs(v) do
                        SneakyDetails_SavedVars[k][k2] = v2
                    end
                else
                    SneakyDetails_SavedVars[k] = v
                end
            end
        end
        
        SD_SavedVars = SneakyDetails_SavedVars
        
        -- Make sure all needed saved variables exist
        EnsureSavedVariables()
        
        -- Create the button
        self.button = CreateButton()
        
        -- Setup commands
        SetupCommands()
        
        -- Register additional events now that we're initialized
        self:RegisterEvent("PLAYER_REGEN_DISABLED")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
        
        -- Print loaded message
        PrintMessage("Addon loaded. Type /sd help for available commands.")
    elseif event == "PLAYER_ENTERING_WORLD" then
        -- Check if player is in an instance
        local isInstance, instanceType = IsInInstance()
        inInstance = isInstance and (instanceType == "raid" or instanceType == "party")
        
        -- Set Details visibility based on saved state
        C_Timer.After(1, function()
            -- Slight delay to ensure Details has fully loaded
            if Details then
                if inInstance and SD_SavedVars.disableInInstance then
                    ToggleDetailsVisibility(true)
                else
                    ToggleDetailsVisibility(SD_SavedVars.lastDetailsState)
                end
            end
        end)
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        -- Check if player is in an instance
        local isInstance, instanceType = IsInInstance()
        inInstance = isInstance and (instanceType == "raid" or instanceType == "party")
        
        -- Update visibility based on instance settings
        if inInstance and SD_SavedVars.disableInInstance then
            ToggleDetailsVisibility(true)
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Player entered combat
        HandleCombatState(true)
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Player left combat
        HandleCombatState(false)
    end
end

-- Register event handler
SDFrame:SetScript("OnEvent", OnEvent)