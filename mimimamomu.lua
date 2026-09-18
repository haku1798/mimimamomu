--[[ test-object obsidian gui ]]

-- ============================================
-- SERVICES
-- ============================================
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local VirtualUser = game:GetService("VirtualUser")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
local pickUpItemRemote = Remotes and Remotes:FindFirstChild("Interaction") and Remotes.Interaction:FindFirstChild("PickUpItem")
local placeStructureRemote = Remotes and Remotes:FindFirstChild("Building") and Remotes.Building:FindFirstChild("PlaceStructure")
local buyItemRemote = Remotes and Remotes:FindFirstChild("Merchant") and Remotes.Merchant:FindFirstChild("BuyItem")
local addSuppressorRemote = Remotes and Remotes:FindFirstChild("Tools") and Remotes.Tools:FindFirstChild("AddSuppressor")
local adjustBackpackRemote = Remotes and Remotes:FindFirstChild("Tools") and Remotes.Tools:FindFirstChild("AdjustBackpack")
local resetRemote = Remotes and Remotes:FindFirstChild("Misc") and Remotes.Misc:FindFirstChild("Reset")

-- ============================================
-- UI
-- ============================================
local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Options = Library.Options
local Toggles = Library.Toggles

Library.ForceCheckbox = false
Library.ShowToggleFrameInKeybinds = true

local Window = Library:CreateWindow({
    Title = "test ",
    Footer = "tst",
    NotifySide = "Right",
    ShowCustomCursor = true,
})

local Tabs = {
    Visuals = Window:AddTab("Visuals", "eye"),
    Player = Window:AddTab("Player", "user"),
    Combat = Window:AddTab("Combat", "swords"),
    Exploits = Window:AddTab("Exploits", "zap"),
    AutoPickup = Window:AddTab("Auto Pickup", "magnet"),
    Keybinds = Window:AddTab("Keybinds", "key"),
    Misc = Window:AddTab("Misc", "settings"),
    ["UI Settings"] = Window:AddTab("UI Settings", "sliders-horizontal"),
}

-- ============================================
-- SHARED STATE NAMESPACE  (S)
-- ============================================
local S = {}

-- Folder refs
S.charactersFolder = nil
S.droppedItemsFolder = nil
S.structuresFolder = nil

-- Connections
S.connections = {}

-- ESP instances
S.mobESPInstances = {}
S.playerESPInstances = {}
S.structureESPInstances = {}
S.chestESPInstances = {}

-- ESP flags
S.mobOptions = { ESP = false, Chams = false, Name = false, Distance = false }
S.playerESPVars = { ESP = false, Chams = false, Name = false, Distance = false, Health = false }
S.structureESPVars = { ESP = false, Chams = false, Name = false, Distance = false }
S.chestESPVars = { ESP = false, Chams = false, Name = false, Distance = false }

-- ESP config
S.espConfig = { textSize = 10, fillTransparency = 0.4, outlineTransparency = 0.0 }

-- Active flags / handles
S.antiAFKConn = nil
S.autoSprintActive = false
S.killAuraConn = nil
S.aimbotConn = nil
S.aimbotTarget = nil
S.fovCircle = nil
S.killAuraIndicatorLine = nil
S.killAuraIndicatorCircle = nil
S.repairAuraConn = nil
S.bhopActive = false
S.bhopConn = nil
S.remoteSpyEnabled = false
S.remoteSpyLogs = {}
S.remoteSpyConnections = {}
S.oldFireServer = nil
S.oldInvokeServer = nil

-- Object Identifier
S.objectIDActive = false
S.objectIDHighlight = nil
S.objectIDMouseConn = nil
S.objectIDGui = nil
S.objectIDInfoText = nil
S.objectIDLogText = nil
S.objectIDLastObject = nil
S.objectIDLogs = {}
S.objectIDMaxLogs = 10

-- Lighting / Fog backups
S.originalLighting = { stored = false }
S.originalFog = { stored = false }
S.fogOriginalStates = {}
S.fogObjects = {}
S.fogFEConns = {}

-- Bring Pickup Item
S.bringPickupActive = false
S.bringPickupThread = nil

-- Auto TP Item
S.autoTPItemActive = false
S.autoTPItemThread = nil

-- Auto Pickup
S.autoPickupActive = false
S.autoPickupThread = nil
S.autoPickupAttempts = {}

-- Auto Shoot / Reload
S.autoShootActive = false
S.autoShootConn = nil
S.lastShootTime = 0
S.autoReloadActive = false
S.autoReloadConn = nil
S.lastReloadTime = 0
S.isReloading = false
S.lastShootTimePerSlot = { [0]=0, [1]=0, [2]=0, [3]=0, [4]=0 }
S.remoteArsenalShotCounter = 0
S.remoteArsenalSlotCache = setmetatable({}, {__mode = "k"})

-- Kill Aura
S.killAuraLastSwing = 0
S.killAuraCurrentTarget = nil
S.killAuraTargetDistance = nil

-- Noclip
S.noclipLastCFrame = nil

-- Funny Dance
S.funnyDanceTrack = nil
S.funnyDanceConn = nil

-- Listener flags
S.mobListenersSetup = false
S.structureListenersSetup = false
S.chestListenersSetup = false

-- Mob names
S.mobNames = {"Runner","Crawler","Elemental","Phaser","Hazmat","Electrified","Riot","Zombie","Brute","Spitter","Rebel","Bandit","Gunner","Sniper","Heavy Rebel","Butcher","Bloater","Screamer","Armored Zombie","Emforcer Riot","Acidic Bloater","Blitzer Runner","Blighted Spitter","Tank Muscle","Nuclear Hazmat","Aberrant Screamer","Shadow Muscle","Electrified Muscle","Specter Phaser","Frost Elemental","Muscle","Infested Zombie","Infested Runner","Infested Crawler","Infested Riot","Infested Screamer","Infested Muscle","Exterminator","Night Hunter","Experiment","Infested Brute","Cyborg","Infested Brute"}

-- ============================================
-- SHARED ACCESSORS
-- ============================================
function S.getLocalCharacter()
    if LocalPlayer.Character and LocalPlayer.Character.Parent then
        return LocalPlayer.Character
    end
    if S.charactersFolder then
        local myChar = S.charactersFolder:FindFirstChild(LocalPlayer.Name)
        if myChar then return myChar end
    end
    return nil
end

function S.getEquippedTool()
    local char = S.getLocalCharacter()
    if not char then return nil end
    return char:FindFirstChildOfClass("Tool")
end

function S.getItemMainPart(item)
    if item.PrimaryPart then return item.PrimaryPart end
    for _, child in ipairs(item:GetChildren()) do
        if child:IsA("BasePart") then return child end
    end
    return nil
end

function S.getDistanceColor(dist)
    if dist > 250 then return Color3.fromRGB(255, 80, 80)
    elseif dist > 150 then return Color3.fromRGB(255, 180, 80)
    elseif dist > 100 then return Color3.fromRGB(255, 255, 80)
    else return Color3.fromRGB(220, 220, 220) end
end

function S.getHealthColor(pct)
    if pct > 0.6 then return Color3.fromRGB(80, 255, 80)
    elseif pct > 0.3 then return Color3.fromRGB(255, 230, 50)
    else return Color3.fromRGB(255, 60, 60) end
end

function S.discoverFolders()
    S.charactersFolder = Workspace:FindFirstChild("Characters")
    S.droppedItemsFolder = Workspace:FindFirstChild("DroppedItems")
    S.structuresFolder = Workspace:FindFirstChild("Structures")
        or Workspace:FindFirstChild("PlayerStructures")
        or Workspace:FindFirstChild("Buildings")
end
S.discoverFolders()

-- Forward declarations
S.refreshMobESP = nil
S.refreshPlayerESP = nil
S.refreshStructureESP = nil
S.refreshChestESP = nil
S.removeMobESP = nil
S.removePlayerESP = nil
S.removeStructureESP = nil
S.removeChestESP = nil
S.startChestESP = nil
S.stopChestESP = nil
S.setupCategoryListeners = nil
S.stopObjectIdentifier = nil
S.createObjectIDGUI = nil
S.setupObjectIDMouse = nil
S.setupObjectIDKeyboard = nil
S.startAutoShoot = nil
S.stopAutoShoot = nil
S.startAutoReload = nil
S.stopAutoReload = nil
S.startAutoPickup = nil
S.stopAutoPickup = nil
S.startRepairAura = nil
S.stopRepairAura = nil
S.startAutoSprint = nil
S.stopAutoSprint = nil
S.startKillAura = nil
S.stopKillAura = nil
S.startAimbot = nil
S.stopAimbot = nil
S.startSilentAim = nil
S.stopSilentAim = nil
S.startBhop = nil
S.stopBhop = nil
S.startFunnyDance = nil
S.stopFunnyDance = nil
S.startRemoteSpy = nil
S.stopRemoteSpy = nil
S.startAntiAFK = nil
S.stopAntiAFK = nil
S.enableFullbright = nil
S.disableFullbright = nil
S.enableRemoveFog = nil
S.disableRemoveFog = nil
S.serverHop = nil
S.rejoinServer = nil
S.espSystems = {}

-- ============================================
-- OBJECT IDENTIFIER
-- ============================================
do
    local function addLog(message)
        local timestamp = os.date("%H:%M:%S")
        table.insert(S.objectIDLogs, string.format("[%s] %s", timestamp, message))
        if #S.objectIDLogs > S.objectIDMaxLogs then table.remove(S.objectIDLogs, 1) end
        if S.objectIDLogText then S.objectIDLogText.Text = table.concat(S.objectIDLogs, "\n") end
        print("[ObjectID] " .. message)
    end

    local function updateInfo(object)
        if not object or not S.objectIDInfoText then
            if S.objectIDInfoText then S.objectIDInfoText.Text = "No object selected" end
            return
        end
        local info = {}
        table.insert(info, string.format("📌 Name: %s", object.Name))
        table.insert(info, string.format("📂 Class: %s", object.ClassName))
        table.insert(info, "")
        local path = object:GetFullName()
        if #path > 55 then path = "..." .. string.sub(path, #path - 52) end
        table.insert(info, string.format("🔗 Path: %s", path))
        table.insert(info, "")
        if object:IsA("BasePart") then
            table.insert(info, "⚙️ Properties:")
            table.insert(info, string.format("  Position: (%.1f, %.1f, %.1f)", object.Position.X, object.Position.Y, object.Position.Z))
            table.insert(info, string.format("  Size: (%.1f, %.1f, %.1f)", object.Size.X, object.Size.Y, object.Size.Z))
        elseif object:IsA("Model") then
            local parts = 0
            for _, d in ipairs(object:GetDescendants()) do if d:IsA("BasePart") then parts = parts + 1 end end
            table.insert(info, "🏗️ Structure Info:")
            table.insert(info, string.format("  Parts: %d", parts))
            table.insert(info, string.format("  Children: %d", #object:GetChildren()))
        elseif object:IsA("Tool") then
            table.insert(info, "🔧 Tool Info:")
            if object.Handle then table.insert(info, string.format("  Handle: %s", object.Handle.Name)) end
        end
        local children = object:GetChildren()
        if #children > 0 then
            table.insert(info, "")
            table.insert(info, string.format("📑 Children (%d):", #children))
            local count = 0
            for _, child in ipairs(children) do
                if count >= 6 then table.insert(info, string.format("  ... and %d more", #children - count)); break end
                local icon = child:IsA("Model") and "📁" or child:IsA("BasePart") and "🧱" or child:IsA("Tool") and "🔧" or "📄"
                table.insert(info, string.format("  %s %s (%s)", icon, child.Name, child.ClassName))
                count = count + 1
            end
        end
        S.objectIDInfoText.Text = table.concat(info, "\n")
    end

    local function highlightObject(object)
        if S.objectIDHighlight then S.objectIDHighlight:Destroy(); S.objectIDHighlight = nil end
        if not object then return end
        local highlight = Instance.new("Highlight")
        highlight.Name = "ObjectIDHighlight"
        highlight.Adornee = object
        highlight.FillColor = Color3.fromRGB(180, 80, 255)
        highlight.FillTransparency = 0.2
        highlight.OutlineColor = Color3.fromRGB(200, 100, 255)
        highlight.OutlineTransparency = 0.1
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Parent = object
        S.objectIDHighlight = highlight
        game:GetService("Debris"):AddItem(highlight, 5)
    end

    local function identify(object)
        if not object then addLog("No object detected!"); return end
        local rootObject = object
        if object:IsA("BasePart") and object.Parent then
            if object.Parent:IsA("Model") then rootObject = object.Parent end
            local gp = object.Parent.Parent
            if gp and gp:IsA("Model") then rootObject = gp end
        end
        S.objectIDLastObject = rootObject
        updateInfo(rootObject)
        highlightObject(rootObject)
        addLog(string.format("🎯 Identified: %s (%s)", rootObject.Name, rootObject.ClassName))
    end

    function S.createObjectIDGUI()
        if S.objectIDGui then S.objectIDGui:Destroy(); S.objectIDGui = nil end
        local screenGui = Instance.new("ScreenGui")
        screenGui.Name = "ObjectIdentifierGUI"
        screenGui.ResetOnSpawn = false
        screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
        S.objectIDGui = screenGui
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 380, 0, 320)
        frame.Position = UDim2.new(0.5, -190, 0.5, -160)
        frame.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
        frame.BackgroundTransparency = 0.05
        frame.BorderSizePixel = 1
        frame.BorderColor3 = Color3.fromRGB(60, 60, 70)
        frame.ClipsDescendants = true
        frame.Parent = screenGui
        local titleBar = Instance.new("Frame")
        titleBar.Size = UDim2.new(1, 0, 0, 30)
        titleBar.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
        titleBar.BorderSizePixel = 0
        titleBar.Parent = frame
        local dragging, dragStart, startPos = false, nil, nil
        titleBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging, dragStart, startPos = true, input.Position, frame.Position
            end
        end)
        titleBar.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
        end)
        titleBar.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                local d = input.Position - dragStart
                frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end)
        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -60, 1, 0); title.Position = UDim2.new(0, 8, 0, 0)
        title.BackgroundTransparency = 1
        title.Text = "🔍 Object Identifier"
        title.TextColor3 = Color3.fromRGB(180, 80, 255)
        title.TextSize = 14; title.Font = Enum.Font.GothamBold
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.TextYAlignment = Enum.TextYAlignment.Center
        title.Parent = titleBar
        local closeBtn = Instance.new("TextButton")
        closeBtn.Size = UDim2.new(0, 30, 1, 0); closeBtn.Position = UDim2.new(1, -30, 0, 0)
        closeBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 45); closeBtn.BorderSizePixel = 0
        closeBtn.Text = "✕"; closeBtn.TextColor3 = Color3.fromRGB(255, 80, 80); closeBtn.TextSize = 14
        closeBtn.Parent = titleBar
        closeBtn.MouseButton1Click:Connect(function()
            if Toggles.ObjectIdentifier then Toggles.ObjectIdentifier:SetValue(false) end
            if S.objectIDGui then S.objectIDGui:Destroy(); S.objectIDGui = nil end
            S.objectIDActive = false
        end)
        local infoText = Instance.new("TextLabel")
        infoText.Size = UDim2.new(1, -16, 0, 180); infoText.Position = UDim2.new(0, 8, 0, 35)
        infoText.BackgroundTransparency = 1
        infoText.Text = "Click on any object to identify it..."
        infoText.TextColor3 = Color3.fromRGB(230, 230, 235); infoText.TextSize = 12
        infoText.TextXAlignment = Enum.TextXAlignment.Left
        infoText.TextYAlignment = Enum.TextYAlignment.Top
        infoText.TextWrapped = true
        infoText.Parent = frame
        S.objectIDInfoText = infoText
        local divider = Instance.new("Frame")
        divider.Size = UDim2.new(1, -16, 0, 1); divider.Position = UDim2.new(0, 8, 0, 220)
        divider.BackgroundColor3 = Color3.fromRGB(60, 60, 70); divider.BorderSizePixel = 0
        divider.Parent = frame
        local logText = Instance.new("TextLabel")
        logText.Size = UDim2.new(1, -16, 0, 80); logText.Position = UDim2.new(0, 8, 0, 225)
        logText.BackgroundTransparency = 1
        logText.Text = "● Ready - Click objects to identify them"
        logText.TextColor3 = Color3.fromRGB(150, 150, 160); logText.TextSize = 11
        logText.TextXAlignment = Enum.TextXAlignment.Left
        logText.TextYAlignment = Enum.TextYAlignment.Top
        logText.TextWrapped = true
        logText.Parent = frame
        S.objectIDLogText = logText
        local hint = Instance.new("TextLabel")
        hint.Size = UDim2.new(1, -16, 0, 20); hint.Position = UDim2.new(0, 8, 1, -24)
        hint.BackgroundTransparency = 1
        hint.Text = "Drag title bar to move | Press H to toggle highlight"
        hint.TextColor3 = Color3.fromRGB(100, 100, 120); hint.TextSize = 10
        hint.TextXAlignment = Enum.TextXAlignment.Left
        hint.TextYAlignment = Enum.TextYAlignment.Center
        hint.Parent = frame
    end

    function S.setupObjectIDMouse()
        local mouse = LocalPlayer:GetMouse()
        if S.objectIDMouseConn then S.objectIDMouseConn:Disconnect(); S.objectIDMouseConn = nil end
        S.objectIDMouseConn = mouse.Button1Down:Connect(function()
            if not S.objectIDActive or not S.objectIDGui then return end
            if Library.KeybindFrame and Library.KeybindFrame.Visible then return end
            local target = mouse.Target
            if not target then addLog("Clicked on empty space"); return end
            if target:IsA("GuiObject") or target:IsA("ScreenGui") or target:IsA("TextButton")
                or target:IsA("ImageButton") or target:IsA("TextLabel") or target:IsA("Frame") then return end
            identify(target)
        end)
    end

    function S.setupObjectIDKeyboard()
        UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed or not S.objectIDActive then return end
            if input.KeyCode == Enum.KeyCode.H then
                if S.objectIDHighlight then
                    S.objectIDHighlight:Destroy(); S.objectIDHighlight = nil
                    addLog("Highlight disabled")
                else
                    if S.objectIDLastObject then
                        highlightObject(S.objectIDLastObject)
                        addLog("Highlight enabled")
                    else
                        addLog("No object to highlight")
                    end
                end
            end
        end)
    end

    function S.stopObjectIdentifier()
        S.objectIDActive = false
        if S.objectIDGui then S.objectIDGui:Destroy(); S.objectIDGui = nil end
        if S.objectIDHighlight then S.objectIDHighlight:Destroy(); S.objectIDHighlight = nil end
        if S.objectIDMouseConn then S.objectIDMouseConn:Disconnect(); S.objectIDMouseConn = nil end
        S.objectIDLastObject = nil
        S.objectIDLogs = {}
        S.objectIDInfoText = nil
        S.objectIDLogText = nil
    end
end

-- ============================================
-- ITEM / MOB / STRUCTURE / PLAYER ESP
-- ============================================
do
    local espDefinitions = {
        { key="Gun", displayName="Gun ESP", items={"AA-12","AK-47","Assault Rifle","Desert Eagle","Double Barrel","Flamethrower","Grenade Launcher","LMG","MediGun","Pistol","Ray Gun","Revolver","Rifle","Shotgun","Sniper","SVD","Uzi"},
          colors={fill=Color3.fromRGB(255,30,30),outline=Color3.fromRGB(255,255,255),text=Color3.fromRGB(255,120,120)} },
        { key="Melee", displayName="Melee ESP", items={"Bat","Chainsaw","Crowbar","Fire Axe","Hatchet","Katana","Knife","Riot Shield","Scythe","Sledgehammer","Spear","Spiked Bat"},
          colors={fill=Color3.fromRGB(255,140,0),outline=Color3.fromRGB(255,255,255),text=Color3.fromRGB(255,200,100)} },
        { key="Medical", displayName="Medical ESP", items={"Bandage","Compound H","Compound I","Compound R","Compound S","Medkit"},
          colors={fill=Color3.fromRGB(0,255,80),outline=Color3.fromRGB(255,255,255),text=Color3.fromRGB(150,255,150)} },
        { key="Armor", displayName="Armor ESP", items={"Power Armor","Light Armor","Medium Armor","Heavy Armor"},
          colors={fill=Color3.fromRGB(0,100,255),outline=Color3.fromRGB(255,255,255),text=Color3.fromRGB(160,200,255)} },
        { key="Food", displayName="Food ESP", items={"Chips","Carrot","Bloxiade","Beans","MRE","Bloxy Cola"},
          colors={fill=Color3.fromRGB(190,255,0),outline=Color3.fromRGB(255,255,255),text=Color3.fromRGB(210,255,150)} },
        { key="Resource", displayName="Resources ESP", items={"AC","Battery","Battery Pack","Bucket","Dumbell","Exhaust Pipe","Reactor Component","Refined Metal","Satellite Dish","Scrap","Screws","Spatula","Tray","TV","Watch","Zombie Heart"},
          colors={fill=Color3.fromRGB(0,220,255),outline=Color3.fromRGB(255,255,255),text=Color3.fromRGB(180,240,255)} },
        { key="Carpart", displayName="Cart Parts ESP", items={"Basic Turret","Heavy Turret","Minigun Turret","Plow","Self-Repair Device","Steel Plating","Vehicle Storage"},
          colors={fill=Color3.fromRGB(0,220,255),outline=Color3.fromRGB(255,255,255),text=Color3.fromRGB(180,240,255)} },
        { key="Fuel", displayName="Fuel ESP", items={"Nuclear Fuel","Refined Fuel","Fuel"},
          colors={fill=Color3.fromRGB(255,220,0),outline=Color3.fromRGB(255,255,255),text=Color3.fromRGB(255,240,160)} },
        { key="Ammunition", displayName="Ammunition ESP", items={"Ammo Box","Long Ammo","Medium Ammo","Pistol Ammo","Shells"},
          colors={fill=Color3.fromRGB(255,220,0),outline=Color3.fromRGB(255,255,255),text=Color3.fromRGB(255,240,160)} },
        { key="Ability", displayName="Abilities ESP", items={"Airstrike","Attack Order","Call of the Dead","Summon Brute","Summon Zombies","Taunt","The Future","The Past","The Present"},
          colors={fill=Color3.fromRGB(180,0,255),outline=Color3.fromRGB(255,255,255),text=Color3.fromRGB(220,150,255)} },
    }

    local itemNames = {}
    for _, def in ipairs(espDefinitions) do
        local sys = {
            key = def.key, displayName = def.displayName, colors = def.colors,
            items = def.items, itemList = {},
            vars = { ESP = false, Chams = false, Name = false, Distance = false },
            instances = {}, listenersSetup = false,
        }
        for _, name in ipairs(def.items) do sys.itemList[name] = true; table.insert(itemNames, name) end
        S.espSystems[def.key] = sys
    end
    local extra = {
        Ammo = {"Ammo Box","Long Ammo","Medium Ammo","Pistol Ammo","Shells"},
        Structures = {"Ammo Crate","Barbed Wire","Bear Trap","Boost Pad","Electric Fence","Farm Plot","Fence","Floodlight","Gate","Landmine","Map","Repair Drone","Shelf","Teleporter","Time Machine","Turret","Wall","Watchtower"},
        Consumables = {"Grenade","Molotov"},
        Backpacks = {"Basic Backpack","Good Backpack","Great Backpack"},
        MiscItems = {"Emerald","Gas Mask","Power Armor Arm","Power Armor Core","Radio Tower Part","Blueprint","Military Keycard","Repair Hammer","Suppressor"},
    }
    for _, catItems in pairs(extra) do
        for _, name in ipairs(catItems) do table.insert(itemNames, name) end
    end
    table.sort(itemNames)
    S.itemNames = itemNames
    S.pickupItemNames = itemNames

    local structureNames = {
        "Ammo Crate","Barbed Wire","Bear Trap","Boost Pad","Electric Fence",
        "Farm Plot","Fence","Floodlight","Gate","Landmine","Map","Repair Drone",
        "Shelf","Teleporter","Time Machine","Turret","Wall","Watchtower"
    }
    S.structureNames = structureNames

    local espConfig = S.espConfig
    local mobOptions = S.mobOptions
    local playerESPVars = S.playerESPVars
    local structureESPVars = S.structureESPVars

    local function createCategoryESP(sys, item)
        if not item:IsA("Model") then return end
        if sys.instances[item] then return end
        local mainPart = S.getItemMainPart(item)
        if not mainPart then return end
        local espTable = { MainPart = mainPart }
        if sys.vars.Chams then
            local h = Instance.new("Highlight")
            h.Name = sys.key .. "ESP_Highlight"; h.Adornee = item
            h.FillColor = sys.colors.fill; h.FillTransparency = espConfig.fillTransparency
            h.OutlineColor = sys.colors.outline; h.OutlineTransparency = espConfig.outlineTransparency
            h.Parent = item; espTable.Highlight = h
        end
        if sys.vars.Name or sys.vars.Distance then
            local bb = Instance.new("BillboardGui")
            bb.Name = sys.key .. "ESP_NameDistance"; bb.Adornee = mainPart
            bb.Size = UDim2.new(0, 220, 0, 50); bb.StudsOffset = Vector3.new(0, 2, 0)
            bb.AlwaysOnTop = true; bb.Parent = item
            local fr = Instance.new("Frame"); fr.Size = UDim2.new(1,0,1,0); fr.BackgroundTransparency = 1; fr.Parent = bb
            local nl = Instance.new("TextLabel")
            nl.Size = UDim2.new(1,0,0.5,0); nl.Position = UDim2.new(0,0,0,0)
            nl.BackgroundTransparency = 1; nl.Text = "[" .. sys.key .. "] " .. item.Name
            nl.TextColor3 = sys.colors.text; nl.TextStrokeTransparency = 0.2; nl.TextStrokeColor3 = Color3.new(0,0,0)
            nl.Font = Enum.Font.GothamBold; nl.TextSize = espConfig.textSize
            nl.Visible = sys.vars.Name; nl.Parent = fr
            local dl = Instance.new("TextLabel")
            dl.Size = UDim2.new(1,0,0.5,0); dl.Position = UDim2.new(0,0,0.5,0)
            dl.BackgroundTransparency = 1; dl.Text = "0m"
            dl.TextColor3 = Color3.fromRGB(220,220,220); dl.TextStrokeTransparency = 0.2; dl.TextStrokeColor3 = Color3.new(0,0,0)
            dl.Font = Enum.Font.GothamBold; dl.TextSize = math.max(espConfig.textSize - 2, 8)
            dl.Visible = sys.vars.Distance; dl.Parent = fr
            espTable.Billboard, espTable.NameLabel, espTable.DistLabel = bb, nl, dl
        end
        local conn = RunService.Heartbeat:Connect(function()
            if not item or not item.Parent then conn:Disconnect(); return end
            local myChar = S.getLocalCharacter()
            local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if not myRoot then return end
            local dist = (myRoot.Position - mainPart.Position).Magnitude
            local maxDist = Options.ESPMaxDistance and Options.ESPMaxDistance.Value or 99999
            local visible = dist <= maxDist
            if sys.vars.Chams and (not espTable.Highlight or not espTable.Highlight.Parent) then
                local h = Instance.new("Highlight")
                h.Name = sys.key .. "ESP_Highlight"; h.Adornee = item
                h.FillColor = sys.colors.fill; h.FillTransparency = espConfig.fillTransparency
                h.OutlineColor = sys.colors.outline; h.OutlineTransparency = espConfig.outlineTransparency
                h.Enabled = visible; h.Parent = item; espTable.Highlight = h
            elseif espTable.Highlight and espTable.Highlight.Parent then
                espTable.Highlight.Enabled = visible
            end
            if espTable.Billboard and espTable.Billboard.Parent then
                espTable.Billboard.Enabled = visible
                if espTable.DistLabel and sys.vars.Distance then
                    espTable.DistLabel.Text = math.floor(dist) .. "m"
                    espTable.DistLabel.TextColor3 = S.getDistanceColor(dist)
                end
            end
        end)
        espTable.DistanceConnection = conn
        sys.instances[item] = espTable
    end

    local function removeCategoryESP(sys, item)
        local esp = sys.instances[item]
        if esp then
            if esp.Highlight then esp.Highlight:Destroy() end
            if esp.Billboard then esp.Billboard:Destroy() end
            if esp.DistanceConnection then esp.DistanceConnection:Disconnect() end
            sys.instances[item] = nil
        end
    end

    local function refreshCategoryESP(sys)
        for item, _ in pairs(sys.instances) do removeCategoryESP(sys, item) end
        if not sys.vars.ESP or not S.droppedItemsFolder then return end
        for _, child in ipairs(S.droppedItemsFolder:GetChildren()) do
            if sys.itemList[child.Name] then createCategoryESP(sys, child) end
        end
    end

    local function setupCategoryListeners(sys)
        if not S.droppedItemsFolder or sys.listenersSetup then return end
        sys.listenersSetup = true
        table.insert(S.connections, S.droppedItemsFolder.ChildAdded:Connect(function(child)
            if sys.vars.ESP and sys.itemList[child.Name] then task.wait(0.2); createCategoryESP(sys, child) end
        end))
        table.insert(S.connections, S.droppedItemsFolder.ChildRemoved:Connect(function(child)
            removeCategoryESP(sys, child)
        end))
    end

    for _, sys in pairs(S.espSystems) do
        sys.remove = function(item) removeCategoryESP(sys, item) end
        sys.refresh = function() refreshCategoryESP(sys) end
        sys.setupListeners = function() setupCategoryListeners(sys) end
        setupCategoryListeners(sys)
    end

    -- Mob ESP
    local MOB_RED = { fill = Color3.fromRGB(255,30,30), outline = Color3.fromRGB(255,120,120) }
    local mobTypeColors = { Zombie=MOB_RED, Runner=MOB_RED, Crawler=MOB_RED, Brute=MOB_RED, Spitter=MOB_RED, Riot=MOB_RED, Boss=MOB_RED }

    local function createMobESP(char)
        if not char:IsA("Model") or S.mobESPInstances[char] then return end
        local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
        if not root then return end
        local espTable = { Root = root }
        local mobColors = mobTypeColors[char.Name] or {fill=Color3.fromRGB(220,0,0), outline=Color3.fromRGB(255,185,185)}
        if mobOptions.Chams then
            local h = Instance.new("Highlight"); h.Name = "MobESP_Highlight"; h.Adornee = char
            h.FillColor = mobColors.fill; h.FillTransparency = espConfig.fillTransparency
            h.OutlineColor = mobColors.outline; h.OutlineTransparency = espConfig.outlineTransparency
            h.Parent = char; espTable.Highlight = h
        end
        local bb, nl, dl
        if mobOptions.Name or mobOptions.Distance then
            bb = Instance.new("BillboardGui"); bb.Name = "MobESP_NameDistance"; bb.Adornee = root
            bb.Size = UDim2.new(0,220,0,50); bb.StudsOffset = Vector3.new(0,3,0); bb.AlwaysOnTop = true; bb.Parent = char
            local fr = Instance.new("Frame"); fr.Size = UDim2.new(1,0,1,0); fr.BackgroundTransparency = 1; fr.Parent = bb
            nl = Instance.new("TextLabel"); nl.Size = UDim2.new(1,0,0.5,0); nl.BackgroundTransparency = 1
            nl.Text = char.Name; nl.TextColor3 = mobColors.outline; nl.TextStrokeTransparency = 0.2; nl.TextStrokeColor3 = Color3.new(0,0,0)
            nl.Font = Enum.Font.GothamBold; nl.TextSize = espConfig.textSize; nl.Visible = mobOptions.Name; nl.Parent = fr
            dl = Instance.new("TextLabel"); dl.Size = UDim2.new(1,0,0.5,0); dl.Position = UDim2.new(0,0,0.5,0)
            dl.BackgroundTransparency = 1; dl.Text = "0m"; dl.TextColor3 = Color3.fromRGB(220,220,220)
            dl.TextStrokeTransparency = 0.2; dl.TextStrokeColor3 = Color3.new(0,0,0)
            dl.Font = Enum.Font.GothamBold; dl.TextSize = math.max(espConfig.textSize - 2, 8)
            dl.Visible = mobOptions.Distance; dl.Parent = fr
            espTable.Billboard, espTable.NameLabel, espTable.DistLabel = bb, nl, dl
        end
        local conn
        conn = RunService.Heartbeat:Connect(function()
            if not char or not char.Parent then conn:Disconnect(); return end
            local myChar = S.getLocalCharacter()
            local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if not myRoot then return end
            local dist = (myRoot.Position - root.Position).Magnitude
            local maxDist = Options.ESPMaxDistance and Options.ESPMaxDistance.Value or 99999
            local visible = dist <= maxDist
            local mc = mobTypeColors[char.Name] or {fill=Color3.fromRGB(220,0,0), outline=Color3.fromRGB(255,185,185)}
            if mobOptions.Chams and (not espTable.Highlight or not espTable.Highlight.Parent) then
                local h = Instance.new("Highlight"); h.Name = "MobESP_Highlight"; h.Adornee = char
                h.FillColor = mc.fill; h.FillTransparency = espConfig.fillTransparency
                h.OutlineColor = mc.outline; h.OutlineTransparency = espConfig.outlineTransparency
                h.Enabled = visible; h.Parent = char; espTable.Highlight = h
            elseif espTable.Highlight and espTable.Highlight.Parent then
                espTable.Highlight.Enabled = visible
            end
            if bb and bb.Parent then
                bb.Enabled = visible
                if nl and mobOptions.Name then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum then nl.Text = char.Name .. " [" .. math.floor(hum.Health) .. "/" .. math.floor(hum.MaxHealth) .. "]" end
                end
                if dl and mobOptions.Distance then
                    dl.Text = math.floor(dist) .. "m"; dl.TextColor3 = S.getDistanceColor(dist)
                end
            end
        end)
        espTable.DistanceConnection = conn
        table.insert(S.connections, conn)
        S.mobESPInstances[char] = espTable
    end

    local function removeMobESP(char)
        local esp = S.mobESPInstances[char]
        if esp then
            if esp.Highlight then esp.Highlight:Destroy() end
            if esp.Billboard then esp.Billboard:Destroy() end
            if esp.DistanceConnection then esp.DistanceConnection:Disconnect() end
            S.mobESPInstances[char] = nil
        end
    end

    local function refreshMobESP()
        for char, _ in pairs(S.mobESPInstances) do removeMobESP(char) end
        if not mobOptions.ESP or not S.charactersFolder then return end
        local playerCharSet = {}
        for _, p in ipairs(Players:GetPlayers()) do if p.Character then playerCharSet[p.Character] = true end end
        for _, child in ipairs(S.charactersFolder:GetChildren()) do
            if child:IsA("Model") and not playerCharSet[child] then createMobESP(child) end
        end
    end

    S.createMobESP = createMobESP
    S.removeMobESP = removeMobESP
    S.refreshMobESP = refreshMobESP

    -- Structure ESP
    local function createStructureESP(structure)
        if not structure:IsA("Model") or S.structureESPInstances[structure] then return end
        local mainPart = structure.PrimaryPart or S.getItemMainPart(structure)
        if not mainPart then return end
        local espTable = { MainPart = mainPart }
        if structureESPVars.Chams then
            local h = Instance.new("Highlight"); h.Name = "StructESP_Highlight"; h.Adornee = structure
            h.FillColor = Color3.fromRGB(0,200,150); h.FillTransparency = espConfig.fillTransparency
            h.OutlineColor = Color3.fromRGB(100,255,200); h.OutlineTransparency = espConfig.outlineTransparency
            h.Parent = structure; espTable.Highlight = h
        end
        local bb, nl, dl
        if structureESPVars.Name or structureESPVars.Distance then
            bb = Instance.new("BillboardGui"); bb.Name = "StructESP_Info"; bb.Adornee = mainPart
            bb.Size = UDim2.new(0,250,0,50); bb.StudsOffset = Vector3.new(0,3,0); bb.AlwaysOnTop = true; bb.Parent = structure
            local fr = Instance.new("Frame"); fr.Size = UDim2.new(1,0,1,0); fr.BackgroundTransparency = 1; fr.Parent = bb
            nl = Instance.new("TextLabel"); nl.Size = UDim2.new(1,0,0.5,0); nl.BackgroundTransparency = 1
            nl.Text = "[STRUCTURE] " .. structure.Name; nl.TextColor3 = Color3.fromRGB(0,255,200)
            nl.TextStrokeTransparency = 0.2; nl.TextStrokeColor3 = Color3.new(0,0,0)
            nl.Font = Enum.Font.GothamBold; nl.TextSize = espConfig.textSize; nl.Visible = structureESPVars.Name; nl.Parent = fr
            dl = Instance.new("TextLabel"); dl.Size = UDim2.new(1,0,0.5,0); dl.Position = UDim2.new(0,0,0.5,0)
            dl.BackgroundTransparency = 1; dl.Text = "0m"; dl.TextColor3 = Color3.fromRGB(200,220,220)
            dl.TextStrokeTransparency = 0.2; dl.TextStrokeColor3 = Color3.new(0,0,0)
            dl.Font = Enum.Font.GothamBold; dl.TextSize = math.max(espConfig.textSize - 2, 8)
            dl.Visible = structureESPVars.Distance; dl.Parent = fr
            espTable.Billboard, espTable.NameLabel, espTable.DistLabel = bb, nl, dl
        end
        local conn
        conn = RunService.Heartbeat:Connect(function()
            if not structure or not structure.Parent then conn:Disconnect(); return end
            local myChar = S.getLocalCharacter()
            local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if not myRoot then return end
            local dist = (myRoot.Position - mainPart.Position).Magnitude
            local maxDist = Options.ESPMaxDistance and Options.ESPMaxDistance.Value or 99999
            local visible = dist <= maxDist
            if structureESPVars.Chams and (not espTable.Highlight or not espTable.Highlight.Parent) then
                local h = Instance.new("Highlight"); h.Name = "StructESP_Highlight"; h.Adornee = structure
                h.FillColor = Color3.fromRGB(0,200,150); h.FillTransparency = espConfig.fillTransparency
                h.OutlineColor = Color3.fromRGB(100,255,200); h.OutlineTransparency = espConfig.outlineTransparency
                h.Enabled = visible; h.Parent = structure; espTable.Highlight = h
            elseif espTable.Highlight and espTable.Highlight.Parent then
                espTable.Highlight.Enabled = visible
            end
            if bb and bb.Parent then
                bb.Enabled = visible
                if dl and structureESPVars.Distance then dl.Text = math.floor(dist) .. "m"; dl.TextColor3 = S.getDistanceColor(dist) end
            end
        end)
        espTable.DistanceConnection = conn
        table.insert(S.connections, conn)
        S.structureESPInstances[structure] = espTable
    end

    local function removeStructureESP(structure)
        local esp = S.structureESPInstances[structure]
        if esp then
            if esp.Highlight then esp.Highlight:Destroy() end
            if esp.Billboard then esp.Billboard:Destroy() end
            if esp.DistanceConnection then esp.DistanceConnection:Disconnect() end
            S.structureESPInstances[structure] = nil
        end
    end

    local function refreshStructureESP()
        for s, _ in pairs(S.structureESPInstances) do removeStructureESP(s) end
        if not structureESPVars.ESP or not S.structuresFolder then return end
        for _, child in ipairs(S.structuresFolder:GetDescendants()) do
            if child:IsA("Model") and table.find(structureNames, child.Name) then createStructureESP(child) end
        end
    end

    S.createStructureESP = createStructureESP
    S.removeStructureESP = removeStructureESP
    S.refreshStructureESP = refreshStructureESP

    -- Player ESP
    local function createPlayerESP(player)
        if player == LocalPlayer or S.playerESPInstances[player] then return end
        local char = player.Character or (S.charactersFolder and S.charactersFolder:FindFirstChild(player.Name))
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local espTable = {}
        if playerESPVars.Chams then
            local h = Instance.new("Highlight"); h.Name = "PlayerESP_Highlight"; h.Adornee = char
            h.FillColor = Color3.fromRGB(0,100,255); h.FillTransparency = espConfig.fillTransparency
            h.OutlineColor = Color3.fromRGB(100,180,255); h.OutlineTransparency = espConfig.outlineTransparency
            h.Parent = char; espTable.Highlight = h
        end
        local bb, nl, tl, hl, dl
        if playerESPVars.Name or playerESPVars.Distance or playerESPVars.Health then
            bb = Instance.new("BillboardGui"); bb.Name = "PlayerESP_Info"; bb.Adornee = root
            bb.Size = UDim2.new(0,220,0,70); bb.StudsOffset = Vector3.new(0,3,0); bb.AlwaysOnTop = true; bb.Parent = char
            local fr = Instance.new("Frame"); fr.Size = UDim2.new(1,0,1,0); fr.BackgroundTransparency = 1; fr.Parent = bb
            nl = Instance.new("TextLabel"); nl.Size = UDim2.new(1,0,0.3,0); nl.BackgroundTransparency = 1
            nl.Text = player.DisplayName .. " (@" .. player.Name .. ")"; nl.TextColor3 = Color3.fromRGB(150,200,255)
            nl.TextStrokeTransparency = 0.2; nl.TextStrokeColor3 = Color3.new(0,0,0)
            nl.Font = Enum.Font.GothamBold; nl.TextSize = espConfig.textSize; nl.Visible = playerESPVars.Name; nl.Parent = fr
            tl = Instance.new("TextLabel"); tl.Size = UDim2.new(1,0,0.25,0); tl.Position = UDim2.new(0,0,0.3,0)
            tl.BackgroundTransparency = 1; tl.Text = ""; tl.TextColor3 = Color3.fromRGB(180,180,255)
            tl.TextStrokeTransparency = 0.2; tl.TextStrokeColor3 = Color3.new(0,0,0)
            tl.Font = Enum.Font.Gotham; tl.TextSize = math.max(espConfig.textSize - 2, 8)
            tl.Visible = playerESPVars.Name; tl.Parent = fr
            hl = Instance.new("TextLabel"); hl.Size = UDim2.new(1,0,0.2,0); hl.Position = UDim2.new(0,0,0.55,0)
            hl.BackgroundTransparency = 1; hl.Text = "100 HP"; hl.TextColor3 = Color3.fromRGB(100,255,100)
            hl.TextStrokeTransparency = 0.2; hl.TextStrokeColor3 = Color3.new(0,0,0)
            hl.Font = Enum.Font.GothamBold; hl.TextSize = math.max(espConfig.textSize - 2, 8)
            hl.Visible = playerESPVars.Health; hl.Parent = fr
            dl = Instance.new("TextLabel"); dl.Size = UDim2.new(1,0,0.2,0); dl.Position = UDim2.new(0,0,0.78,0)
            dl.BackgroundTransparency = 1; dl.Text = "0m"; dl.TextColor3 = Color3.fromRGB(220,220,220)
            dl.TextStrokeTransparency = 0.2; dl.TextStrokeColor3 = Color3.new(0,0,0)
            dl.Font = Enum.Font.GothamBold; dl.TextSize = math.max(espConfig.textSize - 2, 8)
            dl.Visible = playerESPVars.Distance; dl.Parent = fr
            espTable.Billboard, espTable.NameLabel, espTable.ToolLabel, espTable.HealthLabel, espTable.DistLabel = bb, nl, tl, hl, dl
        end
        local conn
        conn = RunService.Heartbeat:Connect(function()
            if not player or not player.Parent then conn:Disconnect(); return end
            local c = player.Character or (S.charactersFolder and S.charactersFolder:FindFirstChild(player.Name))
            if not c or not c.Parent then return end
            local r = c:FindFirstChild("HumanoidRootPart")
            if not r then return end
            local myChar = S.getLocalCharacter()
            local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if not myRoot then return end
            local dist = (myRoot.Position - r.Position).Magnitude
            local maxDist = Options.ESPMaxDistance and Options.ESPMaxDistance.Value or 99999
            local visible = dist <= maxDist
            if playerESPVars.Chams and (not espTable.Highlight or not espTable.Highlight.Parent) then
                local h = Instance.new("Highlight"); h.Name = "PlayerESP_Highlight"; h.Adornee = c
                h.FillColor = Color3.fromRGB(0,100,255); h.FillTransparency = espConfig.fillTransparency
                h.OutlineColor = Color3.fromRGB(100,180,255); h.OutlineTransparency = espConfig.outlineTransparency
                h.Parent = c; espTable.Highlight = h
            elseif espTable.Highlight and espTable.Highlight.Parent then
                espTable.Highlight.Enabled = visible
            end
            if bb and bb.Parent then
                bb.Enabled = visible
                if tl and playerESPVars.Name then
                    local tool = c:FindFirstChildOfClass("Tool")
                    tl.Text = tool and ("[ " .. tool.Name .. " ]") or ""
                end
                if hl and playerESPVars.Health then
                    local hum = c:FindFirstChildOfClass("Humanoid")
                    if hum then hl.Text = math.floor(hum.Health) .. " HP"; hl.TextColor3 = S.getHealthColor(hum.Health / hum.MaxHealth) end
                end
                if dl and playerESPVars.Distance then
                    dl.Text = math.floor(dist) .. "m"; dl.TextColor3 = S.getDistanceColor(dist)
                end
            end
        end)
        espTable.DistanceConnection = conn
        table.insert(S.connections, conn)
        local charAddedConn = player.CharacterAdded:Connect(function()
            if playerESPVars.ESP then task.wait(1); removePlayerESP(player); createPlayerESP(player) end
        end)
        espTable.CharAddedConn = charAddedConn
        table.insert(S.connections, charAddedConn)
        S.playerESPInstances[player] = espTable
    end

    local function removePlayerESP(player)
        local esp = S.playerESPInstances[player]
        if esp then
            if esp.Highlight then esp.Highlight:Destroy() end
            if esp.Billboard then esp.Billboard:Destroy() end
            if esp.DistanceConnection then esp.DistanceConnection:Disconnect() end
            if esp.CharAddedConn then esp.CharAddedConn:Disconnect() end
            S.playerESPInstances[player] = nil
        end
    end

    local function refreshPlayerESP()
        for p, _ in pairs(S.playerESPInstances) do removePlayerESP(p) end
        if not playerESPVars.ESP then return end
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                if player.Character or (S.charactersFolder and S.charactersFolder:FindFirstChild(player.Name)) then
                    createPlayerESP(player)
                else
                    local conn = player.CharacterAdded:Connect(function()
                        conn:Disconnect()
                        if playerESPVars.ESP then task.wait(1); createPlayerESP(player) end
                    end)
                    table.insert(S.connections, conn)
                end
            end
        end
    end

    S.createPlayerESP = createPlayerESP
    S.removePlayerESP = removePlayerESP
    S.refreshPlayerESP = refreshPlayerESP

    -- Folder listeners
    local function setupMobListeners()
        if not S.charactersFolder or S.mobListenersSetup then return end
        S.mobListenersSetup = true
        table.insert(S.connections, S.charactersFolder.ChildAdded:Connect(function(child)
            if mobOptions.ESP and child:IsA("Model") then
                local playerCharSet = {}
                for _, p in ipairs(Players:GetPlayers()) do if p.Character then playerCharSet[p.Character] = true end end
                if not playerCharSet[child] then task.wait(0.2); createMobESP(child) end
            end
        end))
        table.insert(S.connections, S.charactersFolder.ChildRemoved:Connect(function(child) removeMobESP(child) end))
    end
    setupMobListeners()

    local function setupStructureListeners()
        if not S.structuresFolder or S.structureListenersSetup then return end
        S.structureListenersSetup = true
        table.insert(S.connections, S.structuresFolder.DescendantAdded:Connect(function(child)
            if structureESPVars.ESP and child:IsA("Model") and table.find(structureNames, child.Name) then
                task.wait(0.2); createStructureESP(child)
            end
        end))
        table.insert(S.connections, S.structuresFolder.DescendantRemoving:Connect(function(child) removeStructureESP(child) end))
    end
    setupStructureListeners()

    -- Respawn / join / leave
    table.insert(S.connections, Players.PlayerAdded:Connect(function(player)
        if playerESPVars.ESP then task.wait(2); createPlayerESP(player) end
    end))
    table.insert(S.connections, Players.PlayerRemoving:Connect(function(player) removePlayerESP(player) end))

    -- Folder re-discovery loop
    task.spawn(function()
        while not Library.Unloaded do
            task.wait(5)
            local prevChars, prevItems, prevStructs = S.charactersFolder, S.droppedItemsFolder, S.structuresFolder
            S.discoverFolders()
            if S.charactersFolder ~= prevChars and S.charactersFolder then
                refreshMobESP(); if not S.mobListenersSetup then setupMobListeners() end
            end
            if S.droppedItemsFolder ~= prevItems and S.droppedItemsFolder then
                for _, sys in pairs(S.espSystems) do sys.refresh() end
                for _, sys in pairs(S.espSystems) do if not sys.listenersSetup then sys.setupListeners() end end
            end
            if S.structuresFolder ~= prevStructs and S.structuresFolder then
                refreshStructureESP(); if not S.structureListenersSetup then setupStructureListeners() end
            end
        end
    end)
end

-- ============================================
-- CHEST ESP
-- ============================================
do
    local chestESPVars = S.chestESPVars
    local espConfig = S.espConfig
    local CHEST_COLORS = {
        Default = { fill=Color3.fromRGB(255,215,0), outline=Color3.fromRGB(255,200,50), text=Color3.fromRGB(255,215,0) },
        Super   = { fill=Color3.fromRGB(255,0,255), outline=Color3.fromRGB(255,100,255), text=Color3.fromRGB(255,100,255) },
        Emerald = { fill=Color3.fromRGB(0,255,0),   outline=Color3.fromRGB(100,255,100), text=Color3.fromRGB(100,255,100) },
    }
    local CHEST_NAMES = { "default", "super", "emerald" }

    local function isChestLike(model)
        if not model or not model:IsA("Model") then return false end
        local n = model.Name:lower()
        for _, a in ipairs(CHEST_NAMES) do if n == a then return true end end
        return false
    end

    local function getChestMainPart(chest)
        if chest.PrimaryPart then return chest.PrimaryPart end
        for _, c in ipairs(chest:GetChildren()) do if c:IsA("BasePart") then return c end end
        return nil
    end

    local function getChestType(chest)
        local n = chest.Name:lower()
        if n == "super" then return "Super" end
        if n == "emerald" then return "Emerald" end
        return "Default"
    end

    local function removeChestESP(chest)
        local esp = S.chestESPInstances[chest]
        if esp then
            if esp.Highlight then esp.Highlight:Destroy() end
            if esp.Billboard then esp.Billboard:Destroy() end
            if esp.DistanceConnection then esp.DistanceConnection:Disconnect() end
            S.chestESPInstances[chest] = nil
        end
    end

    local function createChestESP(chest)
        if not chest or not chest:IsA("Model") or S.chestESPInstances[chest] then return end
        local mainPart = getChestMainPart(chest)
        if not mainPart then return end
        local chestType = getChestType(chest)
        local colors = CHEST_COLORS[chestType] or CHEST_COLORS.Default
        local espTable = { MainPart = mainPart }
        if chestESPVars.Chams then
            local h = Instance.new("Highlight"); h.Name = "ChestESP_Highlight"; h.Adornee = chest
            h.FillColor = colors.fill; h.FillTransparency = espConfig.fillTransparency
            h.OutlineColor = colors.outline; h.OutlineTransparency = espConfig.outlineTransparency
            h.Parent = chest; espTable.Highlight = h
        end
        if chestESPVars.Name or chestESPVars.Distance then
            local bb = Instance.new("BillboardGui"); bb.Name = "ChestESP_Info"; bb.Adornee = mainPart
            bb.Size = UDim2.new(0,200,0,50); bb.StudsOffset = Vector3.new(0,3,0); bb.AlwaysOnTop = true; bb.Parent = chest
            local fr = Instance.new("Frame"); fr.Size = UDim2.new(1,0,1,0); fr.BackgroundTransparency = 1; fr.Parent = bb
            local nl = Instance.new("TextLabel"); nl.Size = UDim2.new(1,0,0.5,0); nl.BackgroundTransparency = 1
            nl.Text = string.format("📦 %s", chestType); nl.TextColor3 = colors.text
            nl.TextStrokeTransparency = 0.2; nl.TextStrokeColor3 = Color3.new(0,0,0)
            nl.Font = Enum.Font.GothamBold; nl.TextSize = espConfig.textSize; nl.Visible = chestESPVars.Name; nl.Parent = fr
            local dl = Instance.new("TextLabel"); dl.Size = UDim2.new(1,0,0.5,0); dl.Position = UDim2.new(0,0,0.5,0)
            dl.BackgroundTransparency = 1; dl.Text = "0m"; dl.TextColor3 = Color3.fromRGB(220,220,220)
            dl.TextStrokeTransparency = 0.2; dl.TextStrokeColor3 = Color3.new(0,0,0)
            dl.Font = Enum.Font.GothamBold; dl.TextSize = math.max(espConfig.textSize - 2, 8)
            dl.Visible = chestESPVars.Distance; dl.Parent = fr
            espTable.Billboard, espTable.NameLabel, espTable.DistLabel = bb, nl, dl
        end
        local conn
        conn = RunService.Heartbeat:Connect(function()
            if not chest or not chest.Parent then conn:Disconnect(); return end
            local myChar = S.getLocalCharacter()
            local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if not myRoot then return end
            local dist = (myRoot.Position - mainPart.Position).Magnitude
            local maxDist = Options.ESPMaxDistance and Options.ESPMaxDistance.Value or 99999
            local visible = dist <= maxDist
            if chestESPVars.Chams and (not espTable.Highlight or not espTable.Highlight.Parent) then
                local h = Instance.new("Highlight"); h.Name = "ChestESP_Highlight"; h.Adornee = chest
                h.FillColor = colors.fill; h.FillTransparency = espConfig.fillTransparency
                h.OutlineColor = colors.outline; h.OutlineTransparency = espConfig.outlineTransparency
                h.Enabled = visible; h.Parent = chest; espTable.Highlight = h
            elseif espTable.Highlight and espTable.Highlight.Parent then
                espTable.Highlight.Enabled = visible
            end
            if espTable.Billboard and espTable.Billboard.Parent then
                espTable.Billboard.Enabled = visible
                if espTable.DistLabel and chestESPVars.Distance then
                    espTable.DistLabel.Text = math.floor(dist) .. "m"
                    espTable.DistLabel.TextColor3 = S.getDistanceColor(dist)
                end
            end
        end)
        espTable.DistanceConnection = conn
        table.insert(S.connections, conn)
        S.chestESPInstances[chest] = espTable
    end

    S.removeChestESP = removeChestESP
    S.createChestESP = createChestESP

    function S.refreshChestESP()
        for chest, _ in pairs(S.chestESPInstances) do removeChestESP(chest) end
        if not chestESPVars.ESP then return end
        local map = Workspace:FindFirstChild("Map")
        if not map then Library:Notify({Title="Chest ESP",Description="Map not found",Time=3}); return end
        local crates = map:FindFirstChild("Crates")
        if not crates then Library:Notify({Title="Chest ESP",Description="Crates not found",Time=3}); return end
        for _, d in ipairs(crates:GetDescendants()) do if d:IsA("Model") and isChestLike(d) then createChestESP(d) end end
        for _, c in ipairs(map:GetChildren()) do if c:IsA("Model") and isChestLike(c) then createChestESP(c) end end
    end

    local function setupChestListeners()
        if S.chestListenersSetup then return end
        local map = Workspace:FindFirstChild("Map"); if not map then return end
        local crates = map:FindFirstChild("Crates"); if not crates then return end
        S.chestListenersSetup = true
        table.insert(S.connections, crates.DescendantAdded:Connect(function(child)
            if chestESPVars.ESP and child:IsA("Model") and isChestLike(child) then task.wait(0.2); createChestESP(child) end
        end))
        table.insert(S.connections, crates.DescendantRemoving:Connect(function(child) if child then removeChestESP(child) end end))
        table.insert(S.connections, map.DescendantAdded:Connect(function(child)
            if chestESPVars.ESP and child:IsA("Model") and isChestLike(child) then task.wait(0.2); createChestESP(child) end
        end))
    end

    function S.startChestESP()
        chestESPVars.ESP = true
        S.refreshChestESP(); setupChestListeners()
        local count = 0; for _ in pairs(S.chestESPInstances) do count = count + 1 end
        Library:Notify({Title="Chest ESP",Description="Enabled - "..count.." chests",Time=2})
    end

    function S.stopChestESP()
        chestESPVars.ESP = false
        for c, _ in pairs(S.chestESPInstances) do removeChestESP(c) end
        Library:Notify({Title="Chest ESP",Description="Disabled",Time=2})
    end
end

-- ============================================
-- NOCLIP / FULLBRIGHT / FOG / SPRINT / ANTIAFK
-- ============================================
do
    -- Noclip
    table.insert(S.connections, RunService.Heartbeat:Connect(function()
        if not Toggles.NoClip or not Toggles.NoClip.Value then S.noclipLastCFrame = nil; return end
        local char = S.getLocalCharacter(); if not char then S.noclipLastCFrame = nil; return end
        local root = char:FindFirstChild("HumanoidRootPart"); if not root then S.noclipLastCFrame = nil; return end
        local currentCF = root.CFrame
        if S.noclipLastCFrame then
            local delta = (currentCF.Position - S.noclipLastCFrame.Position).Magnitude
            if delta > 8 then root.CFrame = S.noclipLastCFrame; currentCF = S.noclipLastCFrame end
        end
        S.noclipLastCFrame = currentCF
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
        end
    end))

    function S.enableFullbright()
        if not S.originalLighting.stored then
            S.originalLighting.Brightness = Lighting.Brightness
            S.originalLighting.Ambient = Lighting.Ambient
            S.originalLighting.OutdoorAmbient = Lighting.OutdoorAmbient
            S.originalLighting.ClockTime = Lighting.ClockTime
            S.originalLighting.FogEnd = Lighting.FogEnd
            S.originalLighting.FogStart = Lighting.FogStart
            S.originalLighting.GlobalShadows = Lighting.GlobalShadows
            S.originalLighting.stored = true
        end
        Lighting.Brightness = 2; Lighting.Ambient = Color3.fromRGB(178,178,178)
        Lighting.OutdoorAmbient = Color3.fromRGB(178,178,178); Lighting.ClockTime = 14
        Lighting.FogEnd = 100000; Lighting.FogStart = 0; Lighting.GlobalShadows = false
    end

    function S.disableFullbright()
        if S.originalLighting.stored then
            Lighting.Brightness = S.originalLighting.Brightness
            Lighting.Ambient = S.originalLighting.Ambient
            Lighting.OutdoorAmbient = S.originalLighting.OutdoorAmbient
            Lighting.ClockTime = S.originalLighting.ClockTime
            Lighting.FogEnd = S.originalLighting.FogEnd
            Lighting.FogStart = S.originalLighting.FogStart
            Lighting.GlobalShadows = S.originalLighting.GlobalShadows
        end
    end

    local function makeFogInvisible(obj)
        pcall(function()
            local st = {}
            if obj:IsA("BasePart") then
                st.Transparency = obj.Transparency; st.Material = obj.Material
                obj.Transparency = 1; obj.Material = Enum.Material.Air
                S.fogOriginalStates[obj] = st
            elseif obj:IsA("ParticleEmitter") or obj:IsA("Beam") or obj:IsA("Trail")
                or obj:IsA("Smoke") or obj:IsA("Fire") or obj:IsA("Sparkles")
                or obj:IsA("Light") or obj:IsA("Highlight") then
                st.Enabled = obj.Enabled; obj.Enabled = false; S.fogOriginalStates[obj] = st
            elseif obj:IsA("Explosion") then st.Visible = obj.Visible; obj.Visible = false; S.fogOriginalStates[obj] = st
            elseif obj:IsA("Decal") or obj:IsA("Texture") then st.Transparency = obj.Transparency; obj.Transparency = 1; S.fogOriginalStates[obj] = st
            elseif obj:IsA("Folder") or obj:IsA("Model") then
                for _, c in ipairs(obj:GetDescendants()) do makeFogInvisible(c) end
            end
        end)
    end

    local function restoreFogObject(obj)
        if S.fogOriginalStates[obj] then
            pcall(function()
                local st = S.fogOriginalStates[obj]
                if obj:IsA("BasePart") then obj.Transparency = st.Transparency; obj.Material = st.Material
                elseif obj:IsA("Explosion") then obj.Visible = st.Visible
                elseif obj:IsA("Decal") or obj:IsA("Texture") then obj.Transparency = st.Transparency
                else obj.Enabled = st.Enabled end
            end)
        end
    end

    function S.enableRemoveFog()
        if not S.originalFog.stored then
            S.originalFog.FogEnd = Lighting.FogEnd
            S.originalFog.FogStart = Lighting.FogStart
            S.originalFog.stored = true
        end
        Lighting.FogEnd = 100000; Lighting.FogStart = 0
        local atm = Lighting:FindFirstChildOfClass("Atmosphere")
        if atm then
            if S.originalFog.AtmDensity == nil then
                S.originalFog.AtmDensity = atm.Density
                S.originalFog.AtmHaze = atm.Haze
                S.originalFog.AtmGlare = atm.Glare
            end
            atm.Density = 0; atm.Haze = 0; atm.Glare = 0
        end
        for _, conn in ipairs(S.fogFEConns) do pcall(function() conn:Disconnect() end) end
        S.fogFEConns = {}
        table.insert(S.fogFEConns, Lighting.Changed:Connect(function(prop)
            if not (Toggles.RemoveFog and Toggles.RemoveFog.Value) then return end
            if prop == "FogEnd" then Lighting.FogEnd = 100000 end
            if prop == "FogStart" then Lighting.FogStart = 0 end
        end))
        if atm then
            table.insert(S.fogFEConns, atm.Changed:Connect(function(prop)
                if not (Toggles.RemoveFog and Toggles.RemoveFog.Value) then return end
                if prop == "Density" then atm.Density = 0 end
                if prop == "Haze" then atm.Haze = 0 end
                if prop == "Glare" then atm.Glare = 0 end
            end))
        end
        local fogFolder = Workspace:FindFirstChild("Fog")
        if fogFolder then
            S.fogOriginalStates = {}; S.fogObjects = {}
            for _, c in ipairs(fogFolder:GetChildren()) do table.insert(S.fogObjects, c); makeFogInvisible(c) end
            for _, d in ipairs(fogFolder:GetDescendants()) do if not S.fogOriginalStates[d] then makeFogInvisible(d) end end
            table.insert(S.fogFEConns, fogFolder.ChildAdded:Connect(function(child)
                if not (Toggles.RemoveFog and Toggles.RemoveFog.Value) then return end
                makeFogInvisible(child)
                for _, d in ipairs(child:GetDescendants()) do makeFogInvisible(d) end
            end))
        end
    end

    function S.disableRemoveFog()
        for _, conn in ipairs(S.fogFEConns) do pcall(function() conn:Disconnect() end) end
        S.fogFEConns = {}
        if S.originalFog.stored then
            Lighting.FogEnd = S.originalFog.FogEnd
            Lighting.FogStart = S.originalFog.FogStart
        end
        local atm = Lighting:FindFirstChildOfClass("Atmosphere")
        if atm and S.originalFog.AtmDensity ~= nil then
            atm.Density = S.originalFog.AtmDensity
            atm.Haze = S.originalFog.AtmHaze
            atm.Glare = S.originalFog.AtmGlare
            S.originalFog.AtmDensity = nil; S.originalFog.AtmHaze = nil; S.originalFog.AtmGlare = nil
        end
        for obj, _ in pairs(S.fogOriginalStates) do restoreFogObject(obj) end
        S.fogOriginalStates = {}; S.fogObjects = {}
    end

    function S.startAutoSprint()
        if S.autoSprintActive then return end
        S.autoSprintActive = true
        pcall(function() game:GetService("VirtualInputManager"):SendKeyEvent(true, Enum.KeyCode.LeftShift, false, game) end)
    end

    function S.stopAutoSprint()
        if not S.autoSprintActive then return end
        S.autoSprintActive = false
        pcall(function() game:GetService("VirtualInputManager"):SendKeyEvent(false, Enum.KeyCode.LeftShift, false, game) end)
    end

    function S.startAntiAFK()
        S.stopAntiAFK()
        S.antiAFKConn = LocalPlayer.Idled:Connect(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
        table.insert(S.connections, S.antiAFKConn)
    end

    function S.stopAntiAFK()
        if S.antiAFKConn then S.antiAFKConn:Disconnect(); S.antiAFKConn = nil end
    end
end

-- ============================================
-- KILL AURA
-- ============================================
do
    local weaponSwingSpeeds = {
        ["Knife"]=0.25,["Katana"]=0.3,["Crowbar"]=0.35,["Bat"]=0.45,["Spiked Bat"]=0.45,
        ["Hatchet"]=0.4,["Scythe"]=0.4,["Spear"]=0.4,["Fire Axe"]=0.55,["Sledgehammer"]=0.6,
        ["Chainsaw"]=0.35,["Riot Shield"]=0.5,
    }

    local function getWeaponSwingSpeed()
        local tool = S.getEquippedTool(); if not tool then return 0.5 end
        if weaponSwingSpeeds[tool.Name] then return weaponSwingSpeeds[tool.Name] end
        for wName, sp in pairs(weaponSwingSpeeds) do
            if string.find(tool.Name:lower(), wName:lower()) then return sp end
        end
        return 0.5
    end

    local function findTargetsInRange(range)
        local char = S.getLocalCharacter(); if not char then return {} end
        local hrp = char:FindFirstChild("HumanoidRootPart"); if not hrp or not S.charactersFolder then return {} end
        local playerCharSet = {}
        for _, p in ipairs(Players:GetPlayers()) do if p.Character then playerCharSet[p.Character] = true end end
        local targets = {}
        local myPos = hrp.Position
        for _, mob in ipairs(S.charactersFolder:GetChildren()) do
            if mob ~= char and not playerCharSet[mob] then
                local mobHRP = mob:FindFirstChild("HumanoidRootPart")
                local mobHum = mob:FindFirstChildOfClass("Humanoid")
                if mobHRP and mobHum and mobHum.Health > 0 then
                    local dist = (mobHRP.Position - myPos).Magnitude
                    if dist <= range then table.insert(targets, {mob=mob, dist=dist, health=mobHum.Health}) end
                end
            end
        end
        local priority = Options.KillAuraPriority and Options.KillAuraPriority.Value or "Nearest"
        if priority == "Nearest" then table.sort(targets, function(a,b) return a.dist < b.dist end)
        elseif priority == "Lowest HP" then table.sort(targets, function(a,b) return a.health < b.health end)
        elseif priority == "Highest HP" then table.sort(targets, function(a,b) return a.health > b.health end) end
        return targets
    end

    local function autoEquipWeapon()
        local char = S.getLocalCharacter(); if not char then return false end
        if char:FindFirstChildOfClass("Tool") then return true end
        local bp = LocalPlayer:FindFirstChild("Backpack"); if not bp then return false end
        local bestTool, bestSpeed = nil, math.huge
        for _, tool in ipairs(bp:GetChildren()) do
            if tool:IsA("Tool") and (tool:FindFirstChild("Swing") or tool:FindFirstChild("HitTargets") or tool:FindFirstChild("RemoteClick")) then
                local speed = weaponSwingSpeeds[tool.Name] or 0.5
                for wName, s in pairs(weaponSwingSpeeds) do if string.find(tool.Name:lower(), wName:lower()) then speed = s; break end end
                if speed < bestSpeed then bestSpeed = speed; bestTool = tool end
            end
        end
        if bestTool then pcall(function() bestTool.Parent = char end); return true end
        return false
    end

    function S.stopKillAura()
        if S.killAuraConn then S.killAuraConn:Disconnect(); S.killAuraConn = nil end
        S.killAuraLastSwing = 0; S.killAuraCurrentTarget = nil; S.killAuraTargetDistance = nil
        if S.killAuraIndicatorLine then S.killAuraIndicatorLine.Visible = false end
        if S.killAuraIndicatorCircle then S.killAuraIndicatorCircle.Visible = false end
        pcall(function() if setsimulationradius then setsimulationradius(50, 300) end end)
    end

    function S.startKillAura()
        S.stopKillAura()
        if not S.killAuraIndicatorLine then
            S.killAuraIndicatorLine = Drawing.new("Line")
            S.killAuraIndicatorLine.Thickness = 1.5
            S.killAuraIndicatorLine.Color = Color3.fromRGB(255,55,55)
            S.killAuraIndicatorLine.Transparency = 0.65
            S.killAuraIndicatorLine.Visible = false
        end
        if not S.killAuraIndicatorCircle then
            S.killAuraIndicatorCircle = Drawing.new("Circle")
            S.killAuraIndicatorCircle.Thickness = 1.5
            S.killAuraIndicatorCircle.Color = Color3.fromRGB(255,55,55)
            S.killAuraIndicatorCircle.Transparency = 0.55
            S.killAuraIndicatorCircle.Filled = false
            S.killAuraIndicatorCircle.Visible = false
        end
        pcall(function() if setsimulationradius then setsimulationradius(1000, 1000) end end)
        S.killAuraConn = RunService.Heartbeat:Connect(function()
            if not Toggles.KillAura or not Toggles.KillAura.Value then
                S.killAuraCurrentTarget = nil
                if S.killAuraIndicatorLine then S.killAuraIndicatorLine.Visible = false end
                if S.killAuraIndicatorCircle then S.killAuraIndicatorCircle.Visible = false end
                return
            end
            local ok, err = pcall(function()
                local char = S.getLocalCharacter(); if not char then return end
                local hrp = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
                local tool = S.getEquippedTool()
                if not tool and Toggles.KillAuraAutoEquip and Toggles.KillAuraAutoEquip.Value then autoEquipWeapon(); tool = S.getEquippedTool() end
                if not tool then
                    S.killAuraCurrentTarget = nil
                    if S.killAuraIndicatorLine then S.killAuraIndicatorLine.Visible = false end
                    if S.killAuraIndicatorCircle then S.killAuraIndicatorCircle.Visible = false end
                    return
                end
                local swing = tool:FindFirstChild("Swing")
                local hitTargets = tool:FindFirstChild("HitTargets")
                local remoteClick = tool:FindFirstChild("RemoteClick")
                local baseRange = Options.KillAuraRange and Options.KillAuraRange.Value or 6
                local extRange = Toggles.KillAuraExtendedRange and Toggles.KillAuraExtendedRange.Value
                local attackRange = extRange and (baseRange + 2) or baseRange
                local targets = findTargetsInRange(attackRange)
                S.killAuraCurrentTarget = targets[1] and targets[1].mob or nil
                S.killAuraTargetDistance = targets[1] and targets[1].dist or nil
                if Toggles.KillAuraShowIndicator and Toggles.KillAuraShowIndicator.Value and S.killAuraCurrentTarget then
                    local camera = Workspace.CurrentCamera
                    if camera then
                        local tHRP = S.killAuraCurrentTarget:FindFirstChild("HumanoidRootPart")
                        if tHRP then
                            local sp, onScreen = camera:WorldToViewportPoint(tHRP.Position)
                            if onScreen and sp.Z > 0 then
                                local vp = camera.ViewportSize
                                S.killAuraIndicatorLine.From = Vector2.new(vp.X/2, vp.Y)
                                S.killAuraIndicatorLine.To = Vector2.new(sp.X, sp.Y)
                                S.killAuraIndicatorLine.Visible = true
                                local r = math.clamp(1200 / math.max(S.killAuraTargetDistance, 1), 8, 40)
                                S.killAuraIndicatorCircle.Position = Vector2.new(sp.X, sp.Y)
                                S.killAuraIndicatorCircle.Radius = r
                                S.killAuraIndicatorCircle.Visible = true
                            else
                                S.killAuraIndicatorLine.Visible = false; S.killAuraIndicatorCircle.Visible = false
                            end
                        end
                    end
                else
                    if S.killAuraIndicatorLine then S.killAuraIndicatorLine.Visible = false end
                    if S.killAuraIndicatorCircle then S.killAuraIndicatorCircle.Visible = false end
                end
                if #targets == 0 then return end
                local weaponSpeed = getWeaponSwingSpeed()
                local userRate = Options.KillAuraSwingRate and Options.KillAuraSwingRate.Value or weaponSpeed
                local effective = math.max(weaponSpeed, userRate)
                local now = tick()
                if now - S.killAuraLastSwing < effective then return end
                local mobs = {}
                for _, t in ipairs(targets) do table.insert(mobs, t.mob) end
                if swing and hitTargets then
                    if pcall(function() swing:FireServer() end) then
                        S.killAuraLastSwing = now
                        pcall(function() hitTargets:FireServer(mobs) end)
                    end
                elseif remoteClick then
                    if pcall(function() remoteClick:FireServer(targets[1].mob) end) then S.killAuraLastSwing = now end
                end
            end)
            if not ok then warn("[KillAura] " .. tostring(err)) end
        end)
    end
end

-- ============================================
-- AIMBOT
-- ============================================
do
    function S.stopAimbot()
        if S.aimbotConn then S.aimbotConn:Disconnect(); S.aimbotConn = nil end
        S.aimbotTarget = nil
        if S.fovCircle then S.fovCircle.Visible = false end
    end

    local function getAimbotTarget()
        local char = S.getLocalCharacter(); if not char then return nil end
        local myRoot = char:FindFirstChild("HumanoidRootPart"); if not myRoot then return nil end
        local camera = Workspace.CurrentCamera; if not camera then return nil end
        local vp = camera.ViewportSize
        local center = Vector2.new(vp.X/2, vp.Y/2)
        local fov = Options.AimbotFOV and Options.AimbotFOV.Value or 100
        local maxRange = Options.AimbotRange and Options.AimbotRange.Value or 500
        local mode = Options.AimbotTarget and Options.AimbotTarget.Value or "Mobs"
        local best, bestScore = nil, math.huge
        local function check(tChar, tRoot)
            if not tChar or not tRoot or tChar == char then return end
            local dist = (tRoot.Position - myRoot.Position).Magnitude
            if dist > maxRange then return end
            local hum = tChar:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health <= 0 then return end
            local sp, on = camera:WorldToViewportPoint(tRoot.Position)
            if not on then return end
            local fovDist = (Vector2.new(sp.X, sp.Y) - center).Magnitude
            if fovDist > fov then return end
            local score = (Options.AimbotPriority and Options.AimbotPriority.Value == "FOV") and fovDist or dist
            if score < bestScore then bestScore = score; best = {character=tChar, rootPart=tRoot} end
        end
        if mode == "Mobs" or mode == "Both" then
            if S.charactersFolder then
                for _, mob in ipairs(S.charactersFolder:GetChildren()) do
                    if table.find(S.mobNames, mob.Name) then
                        check(mob, mob:FindFirstChild("HumanoidRootPart") or mob:FindFirstChild("Torso") or mob:FindFirstChild("UpperTorso"))
                    end
                end
            end
        end
        if mode == "Players" or mode == "Both" then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer then
                    local pc = p.Character or (S.charactersFolder and S.charactersFolder:FindFirstChild(p.Name))
                    if pc then check(pc, pc:FindFirstChild("HumanoidRootPart")) end
                end
            end
        end
        return best
    end

    function S.startAimbot()
        S.stopAimbot()
        S.aimbotConn = RunService.RenderStepped:Connect(function()
            if not Toggles.Aimbot or not Toggles.Aimbot.Value then
                if S.fovCircle then S.fovCircle.Visible = false end
                return
            end
            local char = S.getLocalCharacter(); if not char then return end
            local camera = Workspace.CurrentCamera; if not camera then return end
            local target = getAimbotTarget()
            S.aimbotTarget = target
            if not S.fovCircle then
                S.fovCircle = Drawing.new("Circle")
                S.fovCircle.Filled = false; S.fovCircle.NumSides = 64
                S.fovCircle.Thickness = 1.5; S.fovCircle.Transparency = 1
            end
            if Toggles.AimbotFOVCircle and Toggles.AimbotFOVCircle.Value then
                local vp = camera.ViewportSize
                S.fovCircle.Position = Vector2.new(vp.X/2, vp.Y/2)
                S.fovCircle.Radius = Options.AimbotFOV and Options.AimbotFOV.Value or 100
                S.fovCircle.Color = Color3.fromRGB(255,255,255)
                S.fovCircle.Visible = true
            else
                S.fovCircle.Visible = false
            end
            if not target then return end
            local aimPartName = Options.AimbotPart and Options.AimbotPart.Value or "Head"
            local targetPart = target.character:FindFirstChild(aimPartName)
            if not targetPart or not targetPart:IsA("BasePart") then targetPart = target.rootPart end
            if not targetPart then return end
            local targetPos = targetPart.Position
            if Toggles.AimbotPrediction and Toggles.AimbotPrediction.Value then
                local vel = targetPart.AssemblyLinearVelocity
                local amt = Options.AimbotPredictionAmount and Options.AimbotPredictionAmount.Value or 0.1
                targetPos = targetPos + (vel * amt)
            end
            local myRoot = char:FindFirstChild("HumanoidRootPart"); if not myRoot then return end
            if not char:FindFirstChild("Head") then return end
            local aimPos = targetPos
            if aimPartName == "Head" then aimPos = targetPos + Vector3.new(-0.3, 0.1, 0) end
            local smooth = Options.AimbotSmoothness and Options.AimbotSmoothness.Value or 0.5
            local factor = 1 - (smooth * 0.95)
            local currentPos = camera.CFrame.Position
            local targetCF = CFrame.lookAt(currentPos, aimPos)
            if smooth > 0 then targetCF = camera.CFrame:Lerp(targetCF, factor) end
            camera.CFrame = targetCF
        end)
    end
end

-- ============================================
-- SILENT AIM
-- ============================================
do
    local silentAimConn       = nil
    local silentAimTarget     = nil
    local oldBulletHitscan    = nil
    local oldCreateProjectile = nil
    local BulletMod            = nil
    local ProjectileMod        = nil
    local silentAimRayParams  = nil

    local function refreshRayParams()
        local myChar = S.getLocalCharacter()
        silentAimRayParams = RaycastParams.new()
        silentAimRayParams.FilterType = Enum.RaycastFilterType.Exclude
        silentAimRayParams.IgnoreWater = true
        silentAimRayParams.FilterDescendantsInstances = myChar and { myChar } or {}
    end

    local function isVisible(part)
        local camera = Workspace.CurrentCamera
        if not camera then return false end
        refreshRayParams()
        local origin = camera.CFrame.Position
        local hit = Workspace:Raycast(origin, part.Position - origin, silentAimRayParams)
        if not hit then return true end
        return hit.Instance:IsDescendantOf(part.Parent)
    end

    local function getSilentAimTarget()
        local char = S.getLocalCharacter(); if not char then return nil end
        local myRoot = char:FindFirstChild("HumanoidRootPart"); if not myRoot then return nil end
        local camera = Workspace.CurrentCamera; if not camera then return nil end

        local mouse     = UserInputService:GetMouseLocation()
        local fov       = Options.SilentAimFOV and Options.SilentAimFOV.Value or 150
        local maxRange  = Options.SilentAimRange and Options.SilentAimRange.Value or 500
        local mode      = Options.SilentAimTarget and Options.SilentAimTarget.Value or "Mobs"
        local aimPart   = Options.SilentAimPart and Options.SilentAimPart.Value or "Head"
        local priority  = Options.SilentAimPriority and Options.SilentAimPriority.Value or "Nearest"

        local candidates = {}

        local function check(tChar)
            if not tChar or tChar == char then return end
            local part = tChar:FindFirstChild(aimPart) or tChar:FindFirstChild("HumanoidRootPart")
            if not part then return end
            local hum = tChar:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health <= 0 then return end
            local dist = (part.Position - myRoot.Position).Magnitude
            if dist > maxRange then return end
            local sp, onScreen = camera:WorldToViewportPoint(part.Position)
            if not onScreen or sp.Z <= 0 then return end
            local fovDist = (Vector2.new(sp.X, sp.Y) - mouse).Magnitude
            if fovDist > fov then return end
            if not isVisible(part) then return end
            table.insert(candidates, {
                part = part,
                dist = dist,
                health = hum and hum.Health or math.huge,
                fovDist = fovDist,
            })
        end

        if mode == "Mobs" or mode == "Both" then
            if S.charactersFolder then
                for _, mob in ipairs(S.charactersFolder:GetChildren()) do
                    if table.find(S.mobNames, mob.Name) then check(mob) end
                end
            end
        end
        if mode == "Players" or mode == "Both" then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer then
                    local pc = p.Character or (S.charactersFolder and S.charactersFolder:FindFirstChild(p.Name))
                    if pc then check(pc) end
                end
            end
        end

        if #candidates == 0 then return nil end

        if priority == "Nearest" then
            table.sort(candidates, function(a,b) return a.dist < b.dist end)
        elseif priority == "Farthest" then
            table.sort(candidates, function(a,b) return a.dist > b.dist end)
        elseif priority == "Lowest HP" then
            table.sort(candidates, function(a,b) return a.health < b.health end)
        elseif priority == "Highest HP" then
            table.sort(candidates, function(a,b) return a.health > b.health end)
        elseif priority == "FOV" then
            table.sort(candidates, function(a,b) return a.fovDist < b.fovDist end)
        end

        return candidates[1].part
    end

    function S.stopSilentAim()
        if silentAimConn then silentAimConn:Disconnect(); silentAimConn = nil end
        if BulletMod and oldBulletHitscan then
            pcall(function() BulletMod.BulletHitscan = oldBulletHitscan end)
        end
        if ProjectileMod and oldCreateProjectile then
            pcall(function() ProjectileMod.CreateProjectile = oldCreateProjectile end)
        end
        oldBulletHitscan = nil
        oldCreateProjectile = nil
        silentAimTarget = nil
    end

    function S.startSilentAim()
        S.stopSilentAim()

        local modules = ReplicatedStorage:FindFirstChild("Modules")
        local combat   = modules and modules:FindFirstChild("Combat")
        local bulletScript     = combat and combat:FindFirstChild("Bullet")
        local projectileScript = combat and combat:FindFirstChild("Projectile")

        if not bulletScript then
            Library:Notify({ Title = "Silent Aim", Description = "Bullet module not found", Time = 4 })
            if Toggles.SilentAim then Toggles.SilentAim:SetValue(false) end
            return
        end

        local okB, Bullet = pcall(require, bulletScript)
        if not okB or not Bullet or not Bullet.BulletHitscan then
            Library:Notify({ Title = "Silent Aim", Description = "Failed to require Bullet", Time = 4 })
            if Toggles.SilentAim then Toggles.SilentAim:SetValue(false) end
            return
        end
        BulletMod = Bullet

        oldBulletHitscan = Bullet.BulletHitscan
        Bullet.BulletHitscan = function(origin, direction, config)
            local t = silentAimTarget
            if t and t.Parent then
                direction = t.Position
            end
            return oldBulletHitscan(origin, direction, config)
        end

        if projectileScript then
            local okP, Projectile = pcall(require, projectileScript)
            if okP and Projectile and Projectile.CreateProjectile then
                ProjectileMod = Projectile
                oldCreateProjectile = Projectile.CreateProjectile
                Projectile.CreateProjectile = function(origin, size, velocity, callback, config)
                    local t = silentAimTarget
                    if t and t.Parent then
                        local speed = velocity.Magnitude
                        if speed > 0 then
                            velocity = (t.Position - origin).Unit * speed
                        end
                    end
                    return oldCreateProjectile(origin, size, velocity, callback, config)
                end
            end
        end

        silentAimConn = RunService.RenderStepped:Connect(function()
            silentAimTarget = getSilentAimTarget()
        end)

        Library:Notify({ Title = "Silent Aim", Description = "Enabled", Time = 2 })
    end
end

-- ============================================
-- AUTO SHOOT / AUTO RELOAD
-- ============================================
do
    local lastShootTimePerSlot = S.lastShootTimePerSlot

    S.raSlotReloading = S.raSlotReloading or { [1]=false, [2]=false, [3]=false, [4]=false }

    local function isRemoteArsenal(tool)
        if not tool then return false end
        return tool:FindFirstChild("SetWeaponsClient") ~= nil
            and tool:FindFirstChild("SyncAmmo") ~= nil
            and tool:FindFirstChild("Shoot") ~= nil
    end
    S.isRemoteArsenal = isRemoteArsenal

    local function getRemoteArsenalSlots(arsenal)
        if not arsenal then return nil end
        local cached = S.remoteArsenalSlotCache[arsenal]
        if cached then
            local valid = true
            for _, s in ipairs(cached) do
                if not s.object or not s.object.Parent then valid = false; break end
            end
            if valid then return cached end
        end
        local hover = arsenal:FindFirstChild("HoverModel")
        local gm = hover and hover:FindFirstChild("GunModels")
        if not gm then return nil end
        local slots = {}
        for i = 1, 4 do
            local obj = gm:FindFirstChild(tostring(i))
            if obj then
                slots[#slots + 1] = { index = i, object = obj, stats = obj:FindFirstChild("Stats") }
            end
        end
        if #slots == 0 then return nil end
        S.remoteArsenalSlotCache[arsenal] = slots
        return slots
    end
    S.getRemoteArsenalSlots = getRemoteArsenalSlots

    local function getRemoteArsenalSlot(slotIndex, arsenal)
        local slots = getRemoteArsenalSlots(arsenal)
        if not slots then return nil end
        for _, s in ipairs(slots) do
            if s.index == slotIndex then return s end
        end
        return nil
    end

    local function getRemoteArsenalAmmo(slotData)
        if not slotData or not slotData.object then return nil end
        local a = slotData.object:GetAttribute("Ammo")
        if a ~= nil then return a end
        local sub = slotData.object:FindFirstChildOfClass("Tool")
        if sub then a = sub:GetAttribute("Ammo"); if a ~= nil then return a end end
        if slotData.stats then a = slotData.stats:GetAttribute("Ammo"); if a ~= nil then return a end end
        return nil
    end
    S.getRemoteArsenalAmmo = getRemoteArsenalAmmo

    local function setRemoteArsenalAmmo(slotData, value)
        if not slotData or not slotData.object then return end
        local obj = slotData.object
        if obj:GetAttribute("Ammo") ~= nil then
            pcall(function() obj:SetAttribute("Ammo", value) end); return
        end
        local sub = obj:FindFirstChildOfClass("Tool")
        if sub and sub:GetAttribute("Ammo") ~= nil then
            pcall(function() sub:SetAttribute("Ammo", value) end); return
        end
        if slotData.stats and slotData.stats:GetAttribute("Ammo") ~= nil then
            pcall(function() slotData.stats:SetAttribute("Ammo", value) end)
        end
    end

    local function getRemoteArsenalSlotFireRate(slotData, arsenal)
        if not slotData then return nil end
        local rpm
        if slotData.stats then rpm = slotData.stats:GetAttribute("FireRate") end
        if not rpm then rpm = slotData.object:GetAttribute("FireRate") end
        if not rpm or rpm <= 0 then return nil end
        local charMod = 1
        local char = S.getLocalCharacter()
        if char then charMod = 1 + (char:GetAttribute("FireRate") or 0) end
        local arsenalMod = 1
        if arsenal then
            local aStats = arsenal:FindFirstChild("Stats")
            if aStats then arsenalMod = aStats:GetAttribute("FireRate") or 1 end
        end
        return 60 / (rpm * charMod * arsenalMod)
    end

    local function getPelletsForRA(slotData)
        if not slotData then return 1 end
        if slotData.stats then
            local p = slotData.stats:GetAttribute("Pellets")
            if typeof(p) == "number" and p >= 1 then return math.floor(p) end
        end
        if slotData.object then
            local p = slotData.object:GetAttribute("Pellets")
            if typeof(p) == "number" and p >= 1 then return math.floor(p) end
        end
        return 1
    end

    local function getAmmoValue(tool)
        if not tool then return nil end
        local a = tool:GetAttribute("Ammo"); if typeof(a) == "number" then return a end
        for _, n in ipairs({"CurrentAmmo","Clip","Bullets","Mag","Magazine","LoadedAmmo"}) do
            local v = tool:GetAttribute(n); if typeof(v) == "number" then return v end
        end
        return nil
    end
    S.getAmmoValue = getAmmoValue

    local function getWeaponFireRate(tool)
        if not tool then return 0.15 end
        local stats = tool:FindFirstChild("Stats")
        if stats then
            local r = stats:GetAttribute("FireRate")
                or stats:GetAttribute("RateOfFire")
                or stats:GetAttribute("RPM")
            if typeof(r) == "number" and r > 0 then return r > 10 and (60 / r) or r end
        end
        local a = tool:GetAttribute("FireRate") or tool:GetAttribute("Cooldown")
        if typeof(a) == "number" and a > 0 then return a end
        return 0.15
    end
    S.getWeaponFireRate = getWeaponFireRate

    local function getToolReloadTime(tool)
        if not tool then return 1.5 end
        local stats = tool:FindFirstChild("Stats")
        if stats then
            local r = stats:GetAttribute("ReloadTime")
            if typeof(r) == "number" and r > 0 then return r end
        end
        local r = tool:GetAttribute("ReloadTime")
        if typeof(r) == "number" and r > 0 then return r end
        return 1.5
    end

    local function getPelletsForNormal(tool)
        if not tool then return 1 end
        local stats = tool:FindFirstChild("Stats")
        if stats then
            local p = stats:GetAttribute("Pellets")
            if typeof(p) == "number" and p >= 1 then return math.floor(p) end
        end
        local p = tool:GetAttribute("Pellets")
        if typeof(p) == "number" and p >= 1 then return math.floor(p) end
        return 1
    end

    local function getShootRemote()
        local ps = LocalPlayer:FindFirstChild("Shoot")
        if ps and (ps:IsA("RemoteEvent") or ps:IsA("RemoteFunction")) then return ps end
        local tool = S.getEquippedTool()
        if tool then
            local sh = tool:FindFirstChild("Shoot")
            if sh and (sh:IsA("RemoteEvent") or sh:IsA("RemoteFunction")) then return sh end
        end
        return nil
    end

    local losParams = RaycastParams.new()
    losParams.FilterType = Enum.RaycastFilterType.Exclude
    losParams.IgnoreWater  = true

    local function hasLineOfSight(fromPos, toPart, targetChar, myChar)
        losParams.FilterDescendantsInstances = { myChar, targetChar }
        local result = Workspace:Raycast(fromPos, toPart.Position - fromPos, losParams)
        return result == nil
    end

    local function getTargetForAutoShoot()
        local char = S.getLocalCharacter(); if not char then return nil end
        local myRoot = char:FindFirstChild("HumanoidRootPart"); if not myRoot then return nil end
        local range = Options.AutoShootRange and Options.AutoShootRange.Value or 300
        local mode = Options.AutoShootTarget and Options.AutoShootTarget.Value or "Mobs"
        local aimPart = Options.AutoShootPart and Options.AutoShootPart.Value or "Head"
        local priority = Options.AutoShootPriority and Options.AutoShootPriority.Value or "Nearest"

        local camera  = Workspace.CurrentCamera
        local head    = char:FindFirstChild("Head")
        local fromPos = (camera and camera.CFrame.Position) or (head and head.Position) or myRoot.Position

        local candidates = {}

        local function check(tChar)
            if not tChar or tChar == char then return end
            local part = tChar:FindFirstChild(aimPart) or tChar:FindFirstChild("HumanoidRootPart")
            if not part then return end
            local dist = (part.Position - myRoot.Position).Magnitude
            if dist > range then return end
            local hum = tChar:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health <= 0 then return end
            if not hasLineOfSight(fromPos, part, tChar, char) then return end
            table.insert(candidates, {
                character = tChar,
                part = part,
                dist = dist,
                health = hum and hum.Health or math.huge,
            })
        end

        if mode == "Mobs" or mode == "Both" then
            if S.charactersFolder then
                for _, mob in ipairs(S.charactersFolder:GetChildren()) do
                    if table.find(S.mobNames, mob.Name) then check(mob) end
                end
            end
        end
        if mode == "Players" or mode == "Both" then
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer then
                    local pc = p.Character or (S.charactersFolder and S.charactersFolder:FindFirstChild(p.Name))
                    if pc then check(pc) end
                end
            end
        end

        if #candidates == 0 then return nil end

        if priority == "Nearest" then
            table.sort(candidates, function(a, b) return a.dist < b.dist end)
        elseif priority == "Farthest" then
            table.sort(candidates, function(a, b) return a.dist > b.dist end)
        elseif priority == "Lowest HP" then
            table.sort(candidates, function(a, b) return a.health < b.health end)
        elseif priority == "Highest HP" then
            table.sort(candidates, function(a, b) return a.health > b.health end)
        end

        return candidates[1]
    end

    local MAX_RICOCHET_HOPS = 10

    local function hasToolInInventory(name)
        local char = S.getLocalCharacter()
        if not char then return false end
        if char:FindFirstChild(name) then return true end
        local bp = LocalPlayer:FindFirstChild("Backpack")
        if bp and bp:FindFirstChild(name) then return true end
        return false
    end

    function S.isRicochetEligible()
        local char = S.getLocalCharacter()
        if not char then return false end

        for _, attrName in ipairs({ "Perk", "Class", "ClassName", "Role", "PlayerClass" }) do
            local v = char:GetAttribute(attrName)
            if typeof(v) == "string" and v:lower() == "outlaw" then return true end
        end

        if hasToolInInventory("Heavy Revolver") then return true end
        if hasToolInInventory("Quickdraw") then return true end

        local maxR = char:GetAttribute("RicochetMax")
        if typeof(maxR) == "number" and maxR > 0 then return true end
        local chance = char:GetAttribute("RicochetChance")
        if typeof(chance) == "number" and chance > 0 then return true end

        return false
    end

    function S.getRicochetMax()
        return MAX_RICOCHET_HOPS
    end

    local function collectRicochetTargets(maxCount)
        local char = S.getLocalCharacter()
        if not char then return {} end
        local myRoot = char:FindFirstChild("HumanoidRootPart")
        if not myRoot then return {} end
        if not S.charactersFolder then return {} end

        local range = Options.AutoShootRange and Options.AutoShootRange.Value or 300
        local myPos = myRoot.Position
        local list  = {}

        for _, m in ipairs(S.charactersFolder:GetChildren()) do
            if m:IsA("Model") and m ~= char then
                local hum = m:FindFirstChildOfClass("Humanoid")
                local hrp = m:FindFirstChild("HumanoidRootPart")
                if hum and hrp and hum.Health > 0 then
                    local d = (hrp.Position - myPos).Magnitude
                    if d <= range then
                        table.insert(list, { mob = m, dist = d })
                    end
                end
            end
        end
        table.sort(list, function(a, b) return a.dist < b.dist end)

        local out = {}
        for i = 1, math.min(maxCount, #list) do out[i] = list[i].mob end
        return out
    end

    local function pickPartForRicochet(mob, forceHead)
        if forceHead then
            local head = mob:FindFirstChild("Head")
            if head then return head end
        end
        return mob:FindFirstChild("Head")
            or mob:FindFirstChild("Torso")
            or mob:FindFirstChild("HumanoidRootPart")
            or mob:FindFirstChildWhichIsA("BasePart")
    end

    local function buildRicochetPayload(target, originPos)
        local maxHops = S.getRicochetMax()
        local mobs    = collectRicochetTargets(maxHops)
        if #mobs < 2 then return nil end

        local chain = {}
        local primaryMob = target and target.character
        local usedSet = {}

        if primaryMob and primaryMob.Parent then
            table.insert(chain, { mob = primaryMob, part = pickPartForRicochet(primaryMob, true) })
            usedSet[primaryMob] = true
        end

        for _, m in ipairs(mobs) do
            if #chain >= maxHops then break end
            if not usedSet[m] then
                table.insert(chain, {
                    mob  = m,
                    part = pickPartForRicochet(m, #chain == 0),
                })
                usedSet[m] = true
            end
        end

        if #chain < 2 then return nil end

        local hitData       = {}
        local effectResults = {}
        local prevEnd       = originPos

        for i, hop in ipairs(chain) do
            local pos = hop.part.Position
            local entry = {
                HitChar = hop.mob,
                HitPos  = pos,
                HitPart = hop.part,
            }
            if i > 1 then entry.Ricochet = true end
            hitData[i] = entry

            effectResults[i] = { Origin = prevEnd, End = pos }
            prevEnd = pos
        end

        local pellet = {
            Target        = chain[#chain].part.Position,
            HitData       = hitData,
            EffectResults = effectResults,
        }
        return originPos, { pellet }
    end

    local function buildShotPayload(target, pelletCount)
        local char = S.getLocalCharacter(); if not char then return nil end
        local originPart = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
        if not originPart then return nil end
        local camera = Workspace.CurrentCamera
        local targetPos = target.part.Position
        local originPos = camera and camera.CFrame.Position or originPart.Position

        local n = pelletCount and math.max(1, math.floor(pelletCount)) or 1

        local hitTable = {}
        for i = 1, n do
            hitTable[i] = {
                Target = targetPos,
                HitData = {
                    {
                        HitChar = target.character,
                        HitPos  = targetPos,
                        HitPart = target.part,
                    }
                },
                EffectResults = {
                    {
                        Origin = originPos,
                        End    = targetPos,
                    }
                },
            }
        end
        return originPos, hitTable
    end

    local function fireShootRemote(shootRemote, originPos, hitTable, slot, counter)
        return pcall(function()
            if shootRemote:IsA("RemoteEvent") then
                shootRemote:FireServer(originPos, hitTable, slot, counter)
            elseif shootRemote:IsA("RemoteFunction") then
                shootRemote:InvokeServer(originPos, hitTable, slot, counter)
            end
        end)
    end

    local function reloadRaSlot(arsenal, slot)
        if S.raSlotReloading[slot] then return end
        local slotData = getRemoteArsenalSlot(slot, arsenal)
        if not slotData then return end

        local reloadRemote = arsenal:FindFirstChild("Reload")
        if not reloadRemote then return end

        local ammo = getRemoteArsenalAmmo(slotData)
        if ammo == nil or ammo > 0 then return end

        S.raSlotReloading[slot] = true

        task.spawn(function()
            local deadline = tick() + 5.0

            pcall(function()
                if reloadRemote:IsA("RemoteFunction") then
                    local done, result = false, nil
                    task.spawn(function()
                        local ok, r = pcall(function() return reloadRemote:InvokeServer(nil, slot) end)
                        if ok then result = r end
                        done = true
                    end)
                    while not done and tick() < deadline do
                        task.wait(0.05)
                    end
                    if typeof(result) == "number" then
                        setRemoteArsenalAmmo(slotData, result)
                    end
                elseif reloadRemote:IsA("RemoteEvent") then
                    reloadRemote:FireServer(nil, slot)
                end
            end)

            while tick() < deadline do
                if not arsenal.Parent then break end
                local nowAmmo = getRemoteArsenalAmmo(slotData)
                if nowAmmo and nowAmmo > 0 then break end
                task.wait(0.05)
            end

            S.raSlotReloading[slot] = false
            lastShootTimePerSlot[slot] = 0
        end)
    end

    local function reloadNormalWeapon(tool)
        local reloadRemote = tool:FindFirstChild("Reload")
        if not reloadRemote then return end

        S.isReloading = true
        local duration = getToolReloadTime(tool)
        task.spawn(function()
            pcall(function()
                if reloadRemote:IsA("RemoteFunction") then reloadRemote:InvokeServer()
                elseif reloadRemote:IsA("RemoteEvent") then reloadRemote:FireServer() end
            end)
            task.wait(duration)
            S.isReloading = false
            for s = 0, 4 do lastShootTimePerSlot[s] = 0 end
        end)
    end

    local function triggerReload()
        local char = Workspace.Characters:FindFirstChild(LocalPlayer.Name) or LocalPlayer.Character
        if not char then return false end
        local tool = char:FindFirstChildOfClass("Tool"); if not tool then return false end

        if isRemoteArsenal(tool) then
            local slots = getRemoteArsenalSlots(tool); if not slots then return false end
            for _, slotData in ipairs(slots) do
                local ammo = getRemoteArsenalAmmo(slotData)
                if ammo and ammo <= 0 then
                    reloadRaSlot(tool, slotData.index)
                end
            end
            return true
        end

        reloadNormalWeapon(tool)
        return true
    end

    S.raThreads = {}
    S.raActiveArsenal = nil

    local function stopRaThreads()
        for _, t in pairs(S.raThreads) do
            pcall(function() task.cancel(t) end)
        end
        S.raThreads = {}
        S.raActiveArsenal = nil
        S.raSlotReloading = { [1]=false, [2]=false, [3]=false, [4]=false }
    end
    S.stopRaThreads = stopRaThreads

    local function raSlotLoop(arsenal, slot)
        local offsetOpt = Options.AutoShootOffset
        while Toggles.AutoShoot and Toggles.AutoShoot.Value do
            if not arsenal or not arsenal.Parent then
                local grace = tick() + 0.5
                while tick() < grace and (not arsenal or not arsenal.Parent) do
                    task.wait(0.05)
                end
                if not arsenal or not arsenal.Parent then break end
            end

            local ok, err = pcall(function()
                if S.raSlotReloading[slot] then task.wait(0.05); return end

                local slotData = getRemoteArsenalSlot(slot, arsenal)
                if not slotData then task.wait(0.1); return end

                local ammo = getRemoteArsenalAmmo(slotData)
                if ammo ~= nil and ammo <= 0 then
                    if Toggles.AutoReload and Toggles.AutoReload.Value then
                        reloadRaSlot(arsenal, slot)
                    end
                    task.wait(0.1)
                    return
                end

                local target = getTargetForAutoShoot()
                if not target or not target.part or not target.part.Parent then
                    task.wait(0.05); return
                end

                local pelletCount = getPelletsForRA(slotData)
                local originPos, hitTable = buildShotPayload(target, pelletCount)
                if not originPos then task.wait(0.05); return end

                local shootRemote = arsenal:FindFirstChild("Shoot")
                if not shootRemote then task.wait(0.1); return end

                local rate = getRemoteArsenalSlotFireRate(slotData, arsenal) or 0.15
                local offset = (offsetOpt and typeof(offsetOpt.Value) == "number") and offsetOpt.Value or 0.05
                local interval = rate + offset

                local now = tick()
                if now - lastShootTimePerSlot[slot] >= interval then
                    S.remoteArsenalShotCounter = S.remoteArsenalShotCounter + 1
                    local counter = S.remoteArsenalShotCounter
                    local fired = fireShootRemote(shootRemote, originPos, hitTable, slot, counter)
                    if fired then
                        lastShootTimePerSlot[slot] = now
                        if ammo ~= nil then
                            setRemoteArsenalAmmo(slotData, math.max(0, ammo - 1))
                        end
                    end
                end
                task.wait(interval)
            end)

            if not ok then
                warn(("[RA Slot %d] iteration error: %s"):format(slot, tostring(err)))
                task.wait(0.1)
            end
        end
        S.raThreads[slot] = nil
    end

    local function startRaThreads(arsenal)
        stopRaThreads()
        S.raActiveArsenal = arsenal
        local slots = getRemoteArsenalSlots(arsenal)
        if not slots then return end
        for _, slotData in ipairs(slots) do
            local slot = slotData.index
            S.raThreads[slot] = task.spawn(function()
                raSlotLoop(arsenal, slot)
            end)
        end
    end
    S.startRaThreads = startRaThreads

    local function fireNormalWeapon(tool, shootRemote)
        local currentAmmo = tool:GetAttribute("Ammo") or getAmmoValue(tool)
        if currentAmmo and currentAmmo <= 0 then return end

        local target = getTargetForAutoShoot()
        if not target then return end

        local pelletCount = getPelletsForNormal(tool)
        local originPos, hitTable = buildShotPayload(target, pelletCount)
        if not originPos then return end

        local offsetOpt = Options.AutoShootOffset
        local offset = (offsetOpt and typeof(offsetOpt.Value) == "number") and offsetOpt.Value or 0.05
        local rate = getWeaponFireRate(tool) + offset

        local slot = 0
        local now = tick()
        if now - lastShootTimePerSlot[slot] < rate then return end

        S.remoteArsenalShotCounter = S.remoteArsenalShotCounter + 1
        local counter = S.remoteArsenalShotCounter

        if S.debugRicochet then
            local hops = hitTable[1] and hitTable[1].HitData and #hitTable[1].HitData or 0
            print(string.format("[Ricochet] fireNormalWeapon slot=%d counter=%d hops=%d ricochet=%s",
                slot, counter, hops, tostring(hops > 1)))
        end

        local ok = fireShootRemote(shootRemote, originPos, hitTable, slot, counter)
        if ok then
            lastShootTimePerSlot[slot] = now
            if currentAmmo then
                tool:SetAttribute("Ammo", math.max(0, currentAmmo - 1))
            end
        end
    end

    function S.stopAutoShoot()
        if S.autoShootConn then S.autoShootConn:Disconnect(); S.autoShootConn = nil end
        stopRaThreads()
        S.autoShootActive = false
        S.lastShootTime = 0
        for s = 0, 4 do lastShootTimePerSlot[s] = 0 end
    end

    function S.stopAutoReload()
        if S.autoReloadConn then S.autoReloadConn:Disconnect(); S.autoReloadConn = nil end
        S.autoReloadActive = false
        S.isReloading = false
        S.raSlotReloading = { [1]=false, [2]=false, [3]=false, [4]=false }
    end

    function S.startAutoReload()
        S.stopAutoReload()
        S.autoReloadActive = true
        S.autoReloadConn = RunService.Heartbeat:Connect(function()
            if not Toggles.AutoReload or not Toggles.AutoReload.Value then return end

            local char = Workspace.Characters:FindFirstChild(LocalPlayer.Name) or LocalPlayer.Character
            if not char then return end
            local tool = char:FindFirstChildOfClass("Tool"); if not tool then return end

            if isRemoteArsenal(tool) then
                local slots = getRemoteArsenalSlots(tool)
                if slots then
                    for _, slotData in ipairs(slots) do
                        local ammo = getRemoteArsenalAmmo(slotData)
                        if ammo and ammo <= 0 and not S.raSlotReloading[slotData.index] then
                            reloadRaSlot(tool, slotData.index)
                        end
                    end
                end
                return
            end

            if S.isReloading then return end
            local ammo = tool:GetAttribute("Ammo") or getAmmoValue(tool)
            if ammo and ammo <= 0 then
                if triggerReload() then S.lastReloadTime = tick() end
            end
        end)
    end

    function S.startAutoShoot()
        S.stopAutoShoot()
        S.autoShootActive = true
        pcall(function() if setsimulationradius then setsimulationradius(2048, 2048) end end)

        S.autoShootConn = RunService.Heartbeat:Connect(function()
            if not Toggles.AutoShoot or not Toggles.AutoShoot.Value then return end

            local tool = S.getEquippedTool()
            if not tool then
                if next(S.raThreads) then stopRaThreads() end
                return
            end

            if isRemoteArsenal(tool) then
                if S.raActiveArsenal ~= tool then
                    startRaThreads(tool)
                else
                    local slots = getRemoteArsenalSlots(tool)
                    if slots then
                        for _, slotData in ipairs(slots) do
                            local slot = slotData.index
                            if not S.raThreads[slot] then
                                S.raThreads[slot] = task.spawn(function()
                                    raSlotLoop(tool, slot)
                                end)
                            end
                        end
                    end
                end
            else
                if next(S.raThreads) then stopRaThreads() end
                if S.isReloading then return end
                local shootRemote = getShootRemote()
                if shootRemote then fireNormalWeapon(tool, shootRemote) end
            end
        end)
    end
end

-- ============================================
-- INSTANT PROXIMITY PROMPT
-- ============================================
do
    S.instantPromptConn = nil

    function S.startInstantPrompt()
        S.stopInstantPrompt()
        local ProximityPromptService = game:GetService("ProximityPromptService")
        S.instantPromptConn = ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
            pcall(function() prompt:InputHoldEnd() end)
            pcall(function() fireproximityprompt(prompt) end)
        end)
        Library:Notify({ Title = "Instant Prompt", Description = "Enabled", Time = 2 })
    end

    function S.stopInstantPrompt()
        if S.instantPromptConn then
            S.instantPromptConn:Disconnect()
            S.instantPromptConn = nil
        end
    end
end

-- ============================================
-- AUTO PICKUP
-- ============================================
do
    function S.stopAutoPickup()
        S.autoPickupActive = false
        if S.autoPickupThread then pcall(function() task.cancel(S.autoPickupThread) end); S.autoPickupThread = nil end
        pcall(function() if setsimulationradius then setsimulationradius(50, 300) end end)
        S.autoPickupAttempts = {}
    end

    function S.startAutoPickup()
        S.stopAutoPickup()
        S.autoPickupActive = true
        pcall(function() if setsimulationradius then setsimulationradius(2048, 2048) end end)
        S.autoPickupThread = task.spawn(function()
            while S.autoPickupActive and Toggles.AutoPickup and Toggles.AutoPickup.Value do
                local char = S.getLocalCharacter()
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if not hrp or not S.droppedItemsFolder then task.wait(0.5); continue end
                local myPos = hrp.Position
                local radius = Options.AutoPickupRadius and Options.AutoPickupRadius.Value or 20
                local allItems = Toggles.AutoPickupAll and Toggles.AutoPickupAll.Value
                local whitelist = Options.AutoPickupWhitelist and Options.AutoPickupWhitelist.Value or {}
                local blacklist = Options.AutoPickupBlacklist and Options.AutoPickupBlacklist.Value or {}
                local useCat = Toggles.UseCategoryFilter and Toggles.UseCategoryFilter.Value or false
                local catAllowed = {}
                if useCat then
                    if Toggles.PickupAmmo and Toggles.PickupAmmo.Value then
                        for _, n in ipairs(S.espSystems.Ammunition.items) do catAllowed[n] = true end
                    end
                    if Toggles.PickupResource and Toggles.PickupResource.Value then
                        for _, n in ipairs(S.espSystems.Resource.items) do catAllowed[n] = true end
                    end
                    if Toggles.PickupFuel and Toggles.PickupFuel.Value then
                        for _, n in ipairs(S.espSystems.Fuel.items) do catAllowed[n] = true end
                    end
                    if Toggles.PickupMedical and Toggles.PickupMedical.Value then
                        for _, n in ipairs(S.espSystems.Medical.items) do catAllowed[n] = true end
                    end
                    if Toggles.PickupCarpart and Toggles.PickupCarpart.Value then
                        for _, n in ipairs(S.espSystems.Carpart.items) do catAllowed[n] = true end
                    end
                    if Toggles.PickupMisc and Toggles.PickupMisc.Value then
                        for _, n in ipairs({
                            "Emerald", "Gas Mask",
                            "Power Armor Arm", "Power Armor Core",
                            "Radio Tower Part", "Blueprint",
                            "Military Keycard", "Repair Hammer", "Suppressor",
                        }) do catAllowed[n] = true end
                    end
                    if Toggles.PickupConsumables and Toggles.PickupConsumables.Value then
                        for _, n in ipairs({ "Grenade", "Molotov" }) do catAllowed[n] = true end
                    end
                end
                local centerTile = Workspace:FindFirstChild("Map") and Workspace.Map:FindFirstChild("Tiles") and Workspace.Map.Tiles:FindFirstChild("Center")
                local skip = false
                if centerTile then
                    local ok, cf, size = pcall(function() return centerTile:GetBoundingBox() end)
                    if ok and cf and size then
                        local lp = cf:PointToObjectSpace(myPos)
                        if math.abs(lp.X) <= size.X/2 and math.abs(lp.Z) <= size.Z/2 then skip = true end
                    end
                end
                if skip then task.wait(0.5); continue end

                local useRemote = not Toggles.AutoPickupMethodRemote or Toggles.AutoPickupMethodRemote.Value
                local useTouch = not Toggles.AutoPickupMethodTouch or Toggles.AutoPickupMethodTouch.Value
                local usePrompt = not Toggles.AutoPickupMethodPrompt or Toggles.AutoPickupMethodPrompt.Value

                for _, item in ipairs(S.droppedItemsFolder:GetChildren()) do
                    if not S.autoPickupActive or not item.Parent then continue end
                    if not allItems then
                        if useCat then if not catAllowed[item.Name] then continue end
                        else if not whitelist[item.Name] then continue end end
                    end
                    local mainPart = item.PrimaryPart or S.getItemMainPart(item)
                    if not mainPart then continue end
                    local dist = (mainPart.Position - myPos).Magnitude
                    if dist > radius then continue end
                    local now = tick()
                    if S.autoPickupAttempts[item] and (now - S.autoPickupAttempts[item]) < 0.35 then continue end
                    S.autoPickupAttempts[item] = now
                    if useRemote then
                        if not blacklist[item.Name] then pcall(function() if pickUpItemRemote then pickUpItemRemote:FireServer(item) end end) end
                        pcall(function() if adjustBackpackRemote then adjustBackpackRemote:FireServer(item) end end)
                    end
                    if useTouch then
                        pcall(function()
                            if firetouchinterest then
                                firetouchinterest(hrp, mainPart, 0)
                                firetouchinterest(hrp, mainPart, 1)
                            end
                        end)
                    end
                    if usePrompt then
                        pcall(function()
                            if fireproximityprompt then
                                local pr = item:FindFirstChildWhichIsA("ProximityPrompt", true)
                                if pr then fireproximityprompt(pr) end
                            end
                        end)
                    end
                    task.wait()
                end
                for itemRef in pairs(S.autoPickupAttempts) do
                    if not itemRef.Parent then S.autoPickupAttempts[itemRef] = nil end
                end
                task.wait(0.1)
            end
            S.autoPickupActive = false
            pcall(function() if setsimulationradius then setsimulationradius(50, 300) end end)
        end)
    end
end

-- ============================================
-- BRING PICKUP ITEM
-- ============================================
do
    function S.stopBringPickup()
        S.bringPickupActive = false
        if S.bringPickupThread then
            pcall(function() task.cancel(S.bringPickupThread) end)
            S.bringPickupThread = nil
        end
    end

    function S.startBringPickup()
        S.stopBringPickup()
        S.bringPickupActive = true

        S.bringPickupThread = task.spawn(function()
            local MAX_TIMEOUTS = 3
            local consecutiveTimeouts = 0

            while S.bringPickupActive
              and Toggles.BringPickupItem
              and Toggles.BringPickupItem.Value do

                local char = S.getLocalCharacter()
                local rootPart = char and char:FindFirstChild("HumanoidRootPart")
                if not rootPart then task.wait(0.5); continue end
                if not S.droppedItemsFolder then task.wait(1); continue end

                local playerPos = rootPart.Position
                local allSelected = Toggles.BringAllPickup and Toggles.BringAllPickup.Value
                local whitelist = Options.BringPickupWhitelist and Options.BringPickupWhitelist.Value or {}

                local targets = {}
                for _, item in ipairs(S.droppedItemsFolder:GetChildren()) do
                    local mp = item.PrimaryPart or S.getItemMainPart(item)
                    if not mp then continue end
                    local d = (mp.Position - playerPos).Magnitude
                    if not allSelected then
                        if not whitelist[item.Name] then continue end
                    end
                    table.insert(targets, { item = item, part = mp, dist = d })
                end

                if #targets == 0 then task.wait(0.5); continue end

                local sortOrder = Options.BringPickupSortOrder and Options.BringPickupSortOrder.Value or "Nearest First"
                if sortOrder == "Nearest First" then
                    table.sort(targets, function(a, b) return a.dist < b.dist end)
                elseif sortOrder == "Farthest First" then
                    table.sort(targets, function(a, b) return a.dist > b.dist end)
                elseif sortOrder == "Alphabetical" then
                    table.sort(targets, function(a, b) return a.item.Name < b.item.Name end)
                elseif sortOrder == "Reverse Alphabetical" then
                    table.sort(targets, function(a, b) return a.item.Name > b.item.Name end)
                end

                for _, target in ipairs(targets) do
                    if not S.bringPickupActive then break end
                    if not target.item.Parent then continue end

                    local itemRef = target.item
                    local partRef = target.part
                    local targetCF = CFrame.new(partRef.Position + Vector3.new(0, 2, 0))
                    local deadline = tick() + 2.0

                    while tick() < deadline and itemRef.Parent and S.bringPickupActive do
                        rootPart.CFrame = targetCF
                        pcall(function()
                            if pickUpItemRemote then
                                pickUpItemRemote:FireServer(itemRef)
                            end
                        end)
                        task.wait(0.05)
                    end

                    if itemRef.Parent == nil then
                        consecutiveTimeouts = 0
                    else
                        consecutiveTimeouts = consecutiveTimeouts + 1
                        if consecutiveTimeouts >= MAX_TIMEOUTS then
                            S.bringPickupActive = false
                            task.defer(function()
                                if Toggles.BringPickupItem then
                                    Toggles.BringPickupItem:SetValue(false)
                                end
                                Library:Notify({
                                    Title = "Bring Pickup Item",
                                    Description = "Backpack full – auto disabled.",
                                    Time = 4,
                                })
                            end)
                            return
                        end
                    end
                end
            end

            S.bringPickupActive = false
        end)
    end
end

-- ============================================
-- MINIMAP RADAR
-- ============================================
do
    local radarConn  = nil
    local drawings   = nil
    local MAX_DOTS   = 400

    local CATEGORY_KEYS = {
        "Gun", "Melee", "Medical", "Armor", "Food",
        "Resource", "Carpart", "Fuel", "Ammunition", "Ability",
    }

    local function ensureDrawings()
        if drawings then return drawings end
        drawings = {
            background = Drawing.new("Circle"),
            border     = Drawing.new("Circle"),
            ring1      = Drawing.new("Circle"),
            ring2      = Drawing.new("Circle"),
            ring3      = Drawing.new("Circle"),
            centerDot  = Drawing.new("Circle"),
            cone       = Drawing.new("Triangle"),
            dots       = {},
        }
        drawings.background.Filled = true
        drawings.background.NumSides = 64
        drawings.background.Color = Color3.fromRGB(12, 12, 18)
        drawings.background.Thickness = 0
        drawings.background.Visible = false

        drawings.border.Filled = false
        drawings.border.NumSides = 64
        drawings.border.Color = Color3.fromRGB(90, 90, 110)
        drawings.border.Thickness = 1.5
        drawings.border.Visible = false

        for _, ring in ipairs({drawings.ring1, drawings.ring2, drawings.ring3}) do
            ring.Filled = false
            ring.NumSides = 48
            ring.Color = Color3.fromRGB(70, 70, 90)
            ring.Transparency = 0.55
            ring.Thickness = 1
            ring.Visible = false
        end

        drawings.centerDot.Filled = true
        drawings.centerDot.NumSides = 16
        drawings.centerDot.Color = Color3.fromRGB(120, 220, 255)
        drawings.centerDot.Radius = 3
        drawings.centerDot.Visible = false

        drawings.cone.Filled = true
        drawings.cone.Color = Color3.fromRGB(120, 220, 255)
        drawings.cone.Transparency = 0.35
        drawings.cone.Visible = false

        for i = 1, MAX_DOTS do
            local d = Drawing.new("Circle")
            d.Filled = true
            d.NumSides = 8
            d.Radius = 3
            d.Transparency = 1
            d.Visible = false
            drawings.dots[i] = d
        end
        return drawings
    end

    local function hideAll()
        if not drawings then return end
        drawings.background.Visible = false
        drawings.border.Visible     = false
        drawings.ring1.Visible      = false
        drawings.ring2.Visible      = false
        drawings.ring3.Visible      = false
        drawings.centerDot.Visible  = false
        drawings.cone.Visible       = false
        for _, d in ipairs(drawings.dots) do d.Visible = false end
    end

    local function getEnabledCategories()
        local enabled = {}
        for _, key in ipairs(CATEGORY_KEYS) do
            local t = Toggles["Radar" .. key]
            if t and t.Value then enabled[key] = true end
        end
        return enabled
    end

    local function collectTargets(myPos, range)
        local out = {}
        local r2 = range * range

        local enabled = getEnabledCategories()
        local anyEnabled = next(enabled) ~= nil
        if anyEnabled and S.droppedItemsFolder then
            for _, item in ipairs(S.droppedItemsFolder:GetChildren()) do
                local matchedKey = nil
                for key, _ in pairs(enabled) do
                    local sys = S.espSystems[key]
                    if sys and sys.itemList[item.Name] then matchedKey = key; break end
                end
                if matchedKey then
                    local mp = item.PrimaryPart or S.getItemMainPart(item)
                    if mp then
                        local dx, dz = mp.Position.X - myPos.X, mp.Position.Z - myPos.Z
                        if dx*dx + dz*dz <= r2 then
                            local col = S.espSystems[matchedKey].colors.fill
                            table.insert(out, { pos = mp.Position, color = col, size = 2.5 })
                        end
                    end
                end
            end
        end

        if Toggles.RadarChests and Toggles.RadarChests.Value then
            local map = Workspace:FindFirstChild("Map")
            local crates = map and map:FindFirstChild("Crates")
            if crates then
                for _, c in ipairs(crates:GetDescendants()) do
                    if c:IsA("Model") then
                        local n = c.Name:lower()
                        if n == "default" or n == "super" or n == "emerald" then
                            local mp = c.PrimaryPart
                            if not mp then
                                for _, ch in ipairs(c:GetChildren()) do
                                    if ch:IsA("BasePart") then mp = ch; break end
                                end
                            end
                            if mp then
                                local dx, dz = mp.Position.X - myPos.X, mp.Position.Z - myPos.Z
                                if dx*dx + dz*dz <= r2 then
                                    local col = Color3.fromRGB(255, 215, 0)
                                    if n == "super" then col = Color3.fromRGB(255, 0, 255)
                                    elseif n == "emerald" then col = Color3.fromRGB(0, 255, 80) end
                                    table.insert(out, { pos = mp.Position, color = col, size = 5 })
                                end
                            end
                        end
                    end
                end
            end
        end

        if Toggles.RadarStructures and Toggles.RadarStructures.Value and S.structuresFolder then
            for _, s in ipairs(S.structuresFolder:GetChildren()) do
                if s:IsA("Model") then
                    local mp = s.PrimaryPart or S.getItemMainPart(s)
                    if mp then
                        local dx, dz = mp.Position.X - myPos.X, mp.Position.Z - myPos.Z
                        if dx*dx + dz*dz <= r2 then
                            table.insert(out, { pos = mp.Position, color = Color3.fromRGB(0, 200, 150), size = 3 })
                        end
                    end
                end
            end
        end

        return out
    end

    local function updateRadar()
        if not (Toggles.Radar and Toggles.Radar.Value) then
            hideAll()
            return
        end

        local d = ensureDrawings()
        local char = S.getLocalCharacter()
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local camera = Workspace.CurrentCamera
        if not hrp or not camera then hideAll(); return end

        local radarSize    = Options.RadarSize and Options.RadarSize.Value or 150
        local range        = Options.RadarRange and Options.RadarRange.Value or 300
        local offX         = Options.RadarOffsetX and Options.RadarOffsetX.Value or 180
        local offY         = Options.RadarOffsetY and Options.RadarOffsetY.Value or 180
        local transparency = Options.RadarTransparency and Options.RadarTransparency.Value or 0.7
        local rotate       = Toggles.RadarRotate and Toggles.RadarRotate.Value
        local rings        = Toggles.RadarShowRings and Toggles.RadarShowRings.Value

        local center = Vector2.new(offX, offY)
        local radarRadius = radarSize
        local scale = radarRadius / range

        local look = camera.CFrame.LookVector
        local camLx, camLz = look.X, look.Z
        local hMag = math.sqrt(camLx*camLx + camLz*camLz)
        if hMag > 0.001 then camLx, camLz = camLx/hMag, camLz/hMag else camLx, camLz = 0, -1 end

        local bFwdX, bFwdZ, bRightX, bRightZ
        if rotate then
            bFwdX, bFwdZ = camLx, camLz
            bRightX, bRightZ = -camLz, camLx
        else
            bFwdX, bFwdZ = 0, -1
            bRightX, bRightZ = 1, 0
        end

        d.background.Position = center
        d.background.Radius = radarRadius
        d.background.Transparency = transparency
        d.background.Visible = true

        d.border.Position = center
        d.border.Radius = radarRadius
        d.border.Visible = true

        if rings then
            local rs = { d.ring1, d.ring2, d.ring3 }
            for i = 1, 3 do
                rs[i].Position = center
                rs[i].Radius = radarRadius * (i / 4)
                rs[i].Visible = true
            end
        else
            d.ring1.Visible = false; d.ring2.Visible = false; d.ring3.Visible = false
        end

        d.centerDot.Position = center
        d.centerDot.Visible = true

        local fwdSX = camLx * bRightX + camLz * bRightZ
        local fwdSY = -(camLx * bFwdX + camLz * bFwdZ)
        local fLen = math.sqrt(fwdSX*fwdSX + fwdSY*fwdSY)
        if fLen > 0.001 then fwdSX, fwdSY = fwdSX/fLen, fwdSY/fLen end

        local coneLen = radarRadius * 0.35
        local spread = math.rad(28)
        local cs, sn = math.cos(spread), math.sin(spread)
        local ax = fwdSX * cs - fwdSY * sn
        local ay = fwdSX * sn + fwdSY * cs
        local bx = fwdSX * cs + fwdSY * sn
        local by = -fwdSX * sn + fwdSY * cs

        d.cone.PointA = center
        d.cone.PointB = center + Vector2.new(ax, ay) * coneLen
        d.cone.PointC = center + Vector2.new(bx, by) * coneLen
        d.cone.Visible = true

        local targets = collectTargets(hrp.Position, range)
        local poolIdx = 1
        local myX, myZ = hrp.Position.X, hrp.Position.Z
        local r2 = radarRadius * radarRadius

        for _, t in ipairs(targets) do
            if poolIdx > MAX_DOTS then break end
            local dx, dz = t.pos.X - myX, t.pos.Z - myZ
            local sx = dx * bRightX + dz * bRightZ
            local sy = -(dx * bFwdX + dz * bFwdZ)
            local px = center.X + sx * scale
            local py = center.Y + sy * scale
            local ddx, ddy = px - center.X, py - center.Y
            if ddx*ddx + ddy*ddy <= r2 then
                local dot = d.dots[poolIdx]
                dot.Position = Vector2.new(px, py)
                dot.Color = t.color
                dot.Radius = t.size or 3
                dot.Visible = true
                poolIdx = poolIdx + 1
            end
        end
        for i = poolIdx, MAX_DOTS do
            if d.dots[i].Visible then d.dots[i].Visible = false end
        end
    end

    function S.stopRadar()
        if radarConn then radarConn:Disconnect(); radarConn = nil end
        hideAll()
    end

    function S.startRadar()
        S.stopRadar()
        ensureDrawings()
        radarConn = RunService.RenderStepped:Connect(updateRadar)
    end
end

-- ============================================
-- REPAIR AURA
-- ============================================
do
    function S.stopRepairAura()
        if S.repairAuraConn then S.repairAuraConn:Disconnect(); S.repairAuraConn = nil end
    end

    function S.startRepairAura()
        S.stopRepairAura()
        local lastFire = 0
        S.repairAuraConn = RunService.Heartbeat:Connect(function()
            if not Toggles.RepairAura or not Toggles.RepairAura.Value then return end
            local rate = Options.RepairAuraRate and Options.RepairAuraRate.Value or 1
            local interval = 1 / rate
            local now = tick()
            if now - lastFire < interval then return end
            local tool = S.getEquippedTool()
            if not tool or tool.Name ~= "Repair Hammer" then return end
            local repairRemote = tool:FindFirstChild("Repair"); if not repairRemote then return end
            local char = S.getLocalCharacter(); if not char then return end
            local hrp = char:FindFirstChild("HumanoidRootPart"); if not hrp then return end
            local myPos = hrp.Position
            local maxDist = Options.RepairAuraRange and Options.RepairAuraRange.Value or 30
            if not S.structuresFolder then return end
            local nearest, nearestDist = nil, math.huge
            for _, child in ipairs(S.structuresFolder:GetDescendants()) do
                if child:IsA("Model") then
                    local part = child.PrimaryPart or S.getItemMainPart(child)
                    if part then
                        local d = (myPos - part.Position).Magnitude
                        if d <= maxDist and d < nearestDist then nearestDist = d; nearest = child end
                    end
                end
            end
            if nearest then
                lastFire = now
                pcall(function() repairRemote:FireServer(nearest) end)
            end
        end)
    end
end

-- ============================================
-- BUNNY HOP
-- ============================================
do
    function S.stopBhop()
        if S.bhopConn then S.bhopConn:Disconnect(); S.bhopConn = nil end
        S.bhopActive = false
    end

    function S.startBhop()
        S.stopBhop()
        S.bhopActive = true
        S.bhopConn = RunService.RenderStepped:Connect(function()
            if not Toggles.BunnyHop or not Toggles.BunnyHop.Value then return end
            local char = S.getLocalCharacter(); if not char then return end
            local humanoid = char:FindFirstChildOfClass("Humanoid")
            local root = char:FindFirstChild("HumanoidRootPart")
            if not humanoid or not root then return end
            if humanoid.MoveDirection.Magnitude > 0.1 then
                local st = humanoid:GetState()
                if st == Enum.HumanoidStateType.Running or st == Enum.HumanoidStateType.RunningNoPhysics then
                    humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end
        end)
    end
end

-- ============================================
-- FUNNY DANCE
-- ============================================
do
    local DANCE_ANIM_IDS = { 507770723, 507772104, 507771281 }

    function S.stopFunnyDance()
        if S.funnyDanceConn then S.funnyDanceConn:Disconnect(); S.funnyDanceConn = nil end
        if S.funnyDanceTrack then
            if S.funnyDanceTrack ~= "PHYS" then pcall(function() S.funnyDanceTrack:Stop(0.3) end) end
            S.funnyDanceTrack = nil
        end
    end

    function S.startFunnyDance()
        S.stopFunnyDance()
        local selectedIdx = Options.DanceStyle and Options.DanceStyle.Value or 1
        local selectedId = DANCE_ANIM_IDS[selectedIdx] or DANCE_ANIM_IDS[1]
        local physDanceConn = nil
        local function stopPhys()
            if physDanceConn then physDanceConn:Disconnect(); physDanceConn = nil end
        end
        local function startPhys(char)
            stopPhys()
            local t = 0
            local spinDir = (selectedIdx % 2 == 0) and 1 or -1
            physDanceConn = RunService.Heartbeat:Connect(function(dt)
                if not Toggles.FunnyDance or not Toggles.FunnyDance.Value then stopPhys(); return end
                local c = char or S.getLocalCharacter(); if not c then return end
                local root = c:FindFirstChild("HumanoidRootPart"); if not root then return end
                local hum = c:FindFirstChildOfClass("Humanoid")
                if not hum or hum.Health <= 0 then return end
                t = t + dt
                local spin = CFrame.Angles(0, spinDir * dt * (2.5 + selectedIdx * 0.4), 0)
                local bob = Vector3.new(0, math.sin(t * 4) * 0.08, 0)
                root.CFrame = CFrame.new(root.Position + bob) * (root.CFrame - root.CFrame.Position) * spin
            end)
            S.funnyDanceTrack = "PHYS"
        end
        local function applyDance(char)
            char = char or S.getLocalCharacter(); if not char then return end
            local humanoid = char:FindFirstChildOfClass("Humanoid"); if not humanoid then return end
            local animator = humanoid:FindFirstChildOfClass("Animator")
            if not animator then animator = Instance.new("Animator"); animator.Parent = humanoid end
            if S.funnyDanceTrack then
                if S.funnyDanceTrack == "PHYS" then stopPhys()
                else pcall(function() S.funnyDanceTrack:Stop(0) end) end
                S.funnyDanceTrack = nil
            end
            local function findNative()
                local an = char:FindFirstChild("Animate"); if not an then return nil end
                local variants = {
                    { "dance", "dance2", "dance3" },
                    { "Dance", "Dance2", "Dance3" },
                    { "emote", "emote2", "emote3" },
                    { "Emote", "Emote2", "Emote3" },
                }
                for _, v in ipairs(variants) do
                    local fn = v[selectedIdx] or v[1]
                    local f = an:FindFirstChild(fn)
                    if f then local a = f:FindFirstChildOfClass("Animation"); if a then return a end end
                end
                for _, d in ipairs(an:GetDescendants()) do if d:IsA("Animation") then return d end end
                return nil
            end
            local native = findNative()
            if native then
                local ok, track = pcall(function() return animator:LoadAnimation(native) end)
                if ok and track then
                    track.Priority = Enum.AnimationPriority.Action4
                    track.Looped = true; track:Play(0.15)
                    S.funnyDanceTrack = track; return
                end
            end
            local ok2, res = pcall(function() return game:GetObjects("rbxassetid://" .. tostring(selectedId)) end)
            if ok2 and res and res[1] and res[1]:IsA("Animation") then
                local ok3, track = pcall(function() return animator:LoadAnimation(res[1]) end)
                if ok3 and track then
                    track.Priority = Enum.AnimationPriority.Action4
                    track.Looped = true; track:Play(0.15)
                    S.funnyDanceTrack = track; return
                end
            end
            Library:Notify({ Title = "Funny Dance", Description = "Using physics dance (animation blocked)", Time = 3 })
            startPhys(char)
        end
        applyDance()
        S.funnyDanceConn = LocalPlayer.CharacterAdded:Connect(function(newChar)
            task.delay(0.5, function()
                if Toggles.FunnyDance and Toggles.FunnyDance.Value then
                    selectedIdx = Options.DanceStyle and Options.DanceStyle.Value or 1
                    selectedId = DANCE_ANIM_IDS[selectedIdx] or DANCE_ANIM_IDS[1]
                    if physDanceConn then stopPhys() end
                    applyDance(newChar)
                end
            end)
        end)
    end
end

-- ============================================
-- SERVER HOP / REJOIN
-- ============================================
function S.serverHop()
    local placeId = game.PlaceId
    local servers = {}
    local req = syn and syn.request or http_request or request or httprequest
    if req then
        local sortOrder = math.random(0, 1) == 0 and "Asc" or "Desc"
        local cursor = ""
        for _ = 1, 3 do
            local url = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=" .. sortOrder .. "&limit=100"
                .. (cursor ~= "" and ("&cursor=" .. cursor) or "")
            local ok, response = pcall(req, { Url = url, Method = "GET" })
            if not ok or not response or not response.Body then break end
            local ok2, data = pcall(function() return HttpService:JSONDecode(response.Body) end)
            if not ok2 or not data or not data.data then break end
            for _, server in ipairs(data.data) do
                if server.id ~= game.JobId and server.playing < server.maxPlayers then table.insert(servers, server.id) end
            end
            local nc = data.nextPageCursor
            if not nc or nc == "" or nc == "null" then break end
            cursor = tostring(nc)
        end
    end
    if #servers > 0 then
        for i = #servers, 2, -1 do
            local j = math.random(1, i)
            servers[i], servers[j] = servers[j], servers[i]
        end
        TeleportService:TeleportToPlaceInstance(placeId, servers[1], LocalPlayer)
        Library:Notify({ Title = "Server Hop", Description = "Joining 1 of " .. #servers .. " servers...", Time = 3 })
    else
        TeleportService:Teleport(placeId, LocalPlayer)
        Library:Notify({ Title = "Server Hop", Description = "No other servers, re-matchmaking...", Time = 3 })
    end
end

function S.rejoinServer()
    local placeId = game.PlaceId
    local jobId = game.JobId
    if not jobId or jobId == "" then
        pcall(function() TeleportService:Teleport(placeId, LocalPlayer) end)
        Library:Notify({ Title = "Rejoin", Description = "Rejoining via matchmaking...", Time = 3 })
        return
    end
    local ok1 = pcall(function()
        local opts = Instance.new("TeleportOptions")
        opts.ServerInstanceId = jobId
        TeleportService:TeleportAsync(placeId, { LocalPlayer }, opts)
    end)
    if ok1 then return end
    local ok2 = pcall(function() TeleportService:TeleportToPlaceInstance(placeId, jobId, LocalPlayer) end)
    if ok2 then return end
    pcall(function() TeleportService:Teleport(placeId, LocalPlayer) end)
end

-- ============================================
-- REMOTE SPY
-- ============================================
function S.stopRemoteSpy()
    S.remoteSpyEnabled = false
    S.oldFireServer = nil; S.oldInvokeServer = nil
    for _, conn in ipairs(S.remoteSpyConnections) do if conn then pcall(function() conn:Disconnect() end) end end
    S.remoteSpyConnections = {}
    Library:Notify({ Title = "Remote Spy", Description = "Disabled", Time = 2 })
end

function S.startRemoteSpy()
    S.stopRemoteSpy()
    S.remoteSpyEnabled = true
    S.remoteSpyLogs = {}
    Library:Notify({ Title = "Remote Spy", Description = "Enabled - check console", Time = 3 })
    local function logCall(remote, method, args)
        if not S.remoteSpyEnabled then return end
        local ok, name = pcall(function() return remote.Name end)
        local ok2, path = pcall(function() return remote:GetFullName() end)
        local ok3, cls = pcall(function() return remote.ClassName end)
        table.insert(S.remoteSpyLogs, { Type=ok3 and cls or "?", Method=method, Name=ok and name or "?", Path=ok2 and path or "?", Args=args, Time=os.date("%H:%M:%S") })
        if #S.remoteSpyLogs > 100 then table.remove(S.remoteSpyLogs, 1) end
        print(string.format("[RemoteSpy] %s.%s", ok and name or "?", method))
    end
    if hookmetamethod then
        local ok = pcall(function()
            local orig
            orig = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
                local m = getnamecallmethod()
                if S.remoteSpyEnabled and (m == "FireServer" or m == "InvokeServer") then logCall(self, m, {...}) end
                return orig(self, ...)
            end))
            S.oldFireServer = orig
        end)
        if ok then return end
    end
    if hookfunction then
        local ok = pcall(function()
            local tR = Instance.new("RemoteEvent")
            local tF = Instance.new("RemoteFunction")
            S.oldFireServer = hookfunction(tR.FireServer, function(self, ...)
                if S.remoteSpyEnabled then logCall(self, "FireServer", {...}) end
                return S.oldFireServer(self, ...)
            end)
            S.oldInvokeServer = hookfunction(tF.InvokeServer, function(self, ...)
                if S.remoteSpyEnabled then logCall(self, "InvokeServer", {...}) end
                return S.oldInvokeServer(self, ...)
            end)
            tR:Destroy(); tF:Destroy()
        end)
        if ok then return end
    end
    Library:Notify({ Title = "Remote Spy", Description = "Passive mode", Time = 4 })
end

-- ============================================
-- BUILDING REVEAL
-- ============================================
do
    S.buildingRevealActive = {}

    local BUILDINGS = {
        { name = "Upgrader",        path = { "Map", "Tiles", "Upgrader" } },
        { name = "Nuclear Reactor", path = { "Map", "Tiles", "Nuclear Reactor" } },
        { name = "Military Base",   path = { "Map", "Tiles", "Military Base" } },
    }
    S.buildingDefs = BUILDINGS

    local function findBuilding(pathParts)
        local cur = Workspace
        for _, p in ipairs(pathParts) do
            cur = cur and cur:FindFirstChild(p)
            if not cur then return nil end
        end
        return cur
    end

    local function makeIndicator()
        local ind = {}
        ind.line = Drawing.new("Line")
        ind.line.Thickness = 2
        ind.line.Color = Color3.fromRGB(0, 255, 200)
        ind.line.Transparency = 0.9
        ind.line.Visible = false

        ind.label = Drawing.new("Text")
        ind.label.Size = 14
        ind.label.Center = true
        ind.label.Outline = true
        ind.label.Color = Color3.fromRGB(0, 255, 200)
        ind.label.Visible = false
        return ind
    end

        local function destroyReveal(name)
        local data = S.buildingRevealActive[name]
        if not data then return end
        if data.highlight then pcall(function() data.highlight:Destroy() end) end
        if data.billboard then pcall(function() data.billboard:Destroy() end) end
        if data.conn then pcall(function() data.conn:Disconnect() end) end
        if data.indicator then
            pcall(function() data.indicator.line:Remove() end)
            pcall(function() data.indicator.label:Remove() end)
        end
        if data.anchor and data.anchor.Parent then
            pcall(function() data.anchor:Destroy() end)
        end
        S.buildingRevealActive[name] = nil
    end

        function S.revealBuilding(buildingName, duration)
        duration = duration or 10

        local def
        for _, b in ipairs(BUILDINGS) do
            if b.name == buildingName then def = b; break end
        end
        if not def then return end

        local building = findBuilding(def.path)
        if not building then
            Library:Notify({ Title = "Building Reveal", Description = buildingName .. " not found in Map.Tiles", Time = 3 })
            return
        end

        -- ---- Get position from WorldPivot (no BasePart needed) ----
        local pivotCF
        if building:IsA("Model") then
            pivotCF = building:GetPivot()
        elseif building:IsA("BasePart") then
            pivotCF = building.CFrame
        else
            -- Fallback: any descendant part
            local anyPart = building:FindFirstChildWhichIsA("BasePart", true)
            if anyPart then pivotCF = anyPart.CFrame end
        end

        if not pivotCF then
            Library:Notify({ Title = "Building Reveal", Description = buildingName .. " has no position", Time = 3 })
            return
        end

        -- Clean previous instance of this building
        destroyReveal(buildingName)

        local anchorPos = pivotCF.Position

        -- ---- Invisible anchor part (Workspace-parented) for BillboardGui ----
        local anchor = Instance.new("Part")
        anchor.Name = "BuildingReveal_Anchor"
        anchor.Anchored = true
        anchor.CanCollide = false
        anchor.CanQuery = false
        anchor.CanTouch = false
        anchor.CastShadow = false
        anchor.Transparency = 1
        anchor.Size = Vector3.new(1, 1, 1)
        anchor.CFrame = CFrame.new(anchorPos + Vector3.new(0, 25, 0))
        anchor.Parent = Workspace

        -- ---- Highlight (works directly on a Model) ----
        local highlight = Instance.new("Highlight")
        highlight.Name = "BuildingReveal_HL"
        highlight.Adornee = building
        highlight.FillColor = Color3.fromRGB(0, 255, 200)
        highlight.FillTransparency = 0.55
        highlight.OutlineColor = Color3.fromRGB(0, 255, 255)
        highlight.OutlineTransparency = 0
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Parent = building

        -- ---- BillboardGui (name + live distance) ----
        local bb = Instance.new("BillboardGui")
        bb.Name = "BuildingReveal_BB"
        bb.Adornee = anchor
        bb.Size = UDim2.new(0, 260, 0, 60)
        bb.StudsOffset = Vector3.new(0, 0, 0)
        bb.AlwaysOnTop = true
        bb.Parent = anchor

        local fr = Instance.new("Frame")
        fr.Size = UDim2.new(1, 0, 1, 0)
        fr.BackgroundTransparency = 1
        fr.Parent = bb

        local nl = Instance.new("TextLabel")
        nl.Size = UDim2.new(1, 0, 0.55, 0)
        nl.BackgroundTransparency = 1
        nl.Text = "🏢 " .. buildingName
        nl.TextColor3 = Color3.fromRGB(0, 255, 200)
        nl.TextStrokeTransparency = 0.2
        nl.TextStrokeColor3 = Color3.new(0, 0, 0)
        nl.Font = Enum.Font.GothamBold
        nl.TextSize = 14
        nl.Parent = fr

        local dl = Instance.new("TextLabel")
        dl.Size = UDim2.new(1, 0, 0.45, 0)
        dl.Position = UDim2.new(0, 0, 0.55, 0)
        dl.BackgroundTransparency = 1
        dl.Text = "0m"
        dl.TextColor3 = Color3.fromRGB(200, 255, 240)
        dl.TextStrokeTransparency = 0.2
        dl.TextStrokeColor3 = Color3.new(0, 0, 0)
        dl.Font = Enum.Font.GothamBold
        dl.TextSize = 12
        dl.Parent = fr

        -- ---- Direction indicator ----
        local indicator = makeIndicator()

        local conn = RunService.RenderStepped:Connect(function()
            if not building or not building.Parent then return end
            local char = S.getLocalCharacter()
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local camera = Workspace.CurrentCamera
            if not hrp or not camera then return end

            -- Keep anchor at the (possibly moving) building pivot
            pcall(function()
                local cf = building:GetPivot()
                anchor.CFrame = CFrame.new(cf.Position + Vector3.new(0, 25, 0))
            end)

            local dist = (hrp.Position - anchorPos).Magnitude
            dl.Text = math.floor(dist) .. "m"

            local vp = camera.ViewportSize
            local sp, onScreen = camera:WorldToViewportPoint(anchorPos)
            local center = Vector2.new(vp.X / 2, vp.Y / 2)

            if onScreen and sp.Z > 0 then
                local target = Vector2.new(sp.X, sp.Y)
                local dir = target - center
                if dir.Magnitude > 5 then
                    local n = dir.Unit
                    local startP = center + n * 80
                    local endP   = center + n * math.min(200, dir.Magnitude)
                    indicator.line.From = startP
                    indicator.line.To   = endP
                    indicator.line.Visible = true

                    indicator.label.Position = endP + Vector2.new(8, -8)
                    indicator.label.Text = buildingName .. " [" .. math.floor(dist) .. "m]"
                    indicator.label.Visible = true
                else
                    indicator.line.Visible = false
                    indicator.label.Visible = false
                end
            else
                local dir2D = Vector2.new(sp.X - vp.X / 2, sp.Y - vp.Y / 2)
                if sp.Z < 0 then dir2D = -dir2D end
                if dir2D.Magnitude < 0.01 then dir2D = Vector2.new(0, -1) end

                local n = dir2D.Unit
                local radius = math.min(vp.X, vp.Y) * 0.38
                local edge   = center + n * radius
                local tail   = center + n * (radius - 55)

                indicator.line.From = tail
                indicator.line.To   = edge
                indicator.line.Visible = true

                indicator.label.Position = edge + n * 18
                indicator.label.Text = buildingName .. " [" .. math.floor(dist) .. "m]"
                indicator.label.Visible = true
            end
        end)

        S.buildingRevealActive[buildingName] = {
            building  = building,
            highlight = highlight,
            billboard = bb,
            conn      = conn,
            indicator = indicator,
            anchor    = anchor,
        }

        Library:Notify({ Title = "Building Reveal", Description = buildingName .. " revealed for " .. duration .. "s", Time = 3 })

        task.delay(duration, function()
            if S.buildingRevealActive[buildingName] then
                destroyReveal(buildingName)
                Library:Notify({ Title = "Building Reveal", Description = buildingName .. " reveal ended", Time = 2 })
            end
        end)
    end
end

-- ============================================
-- CHARACTER RESPAWN
-- ============================================
LocalPlayer.CharacterRemoving:Connect(function()
    if S.autoSprintActive then S.stopAutoSprint() end
end)

LocalPlayer.CharacterAdded:Connect(function(char)
    char:WaitForChild("HumanoidRootPart", 10)
    task.wait(0.5)
    if Toggles.AutoSprint and Toggles.AutoSprint.Value then S.startAutoSprint() end
    if Toggles.AutoPickup and Toggles.AutoPickup.Value then S.startAutoPickup() end
end)

-- ============================================
-- UI: VISUALS TAB
-- ============================================
do
    local espSettingsGroup = Tabs.Visuals:AddLeftGroupbox("ESP Settings", "settings")
    espSettingsGroup:AddSlider("ESPMaxDistance", {
        Text = "Max Distance", Default = 300, Min = 50, Max = 2000, Rounding = 0, Suffix = " studs",
        Callback = function()
            S.refreshMobESP(); S.refreshPlayerESP(); S.refreshStructureESP(); S.refreshChestESP()
            for _, sys in pairs(S.espSystems) do sys.refresh() end
        end,
    })

    local mobESPGroup = Tabs.Visuals:AddLeftGroupbox("Mob ESP", "eye")
    mobESPGroup:AddToggle("MobESP", { Text = "Mob ESP", Default = false, Callback = function(s) S.mobOptions.ESP = s; S.refreshMobESP() end })
    mobESPGroup:AddToggle("MobChams", { Text = "Chams", Default = false, Callback = function(s) S.mobOptions.Chams = s; S.refreshMobESP() end })
    mobESPGroup:AddDivider()
    mobESPGroup:AddToggle("MobShowNames", { Text = "Show Names", Default = false, Callback = function(s) S.mobOptions.Name = s; S.refreshMobESP() end })
    mobESPGroup:AddToggle("MobShowDistance", { Text = "Show Distance", Default = false, Callback = function(s) S.mobOptions.Distance = s; S.refreshMobESP() end })

    local playerESPGroup = Tabs.Visuals:AddLeftGroupbox("Player ESP", "users")
    playerESPGroup:AddToggle("PlayerESP", { Text = "Player ESP", Default = false, Callback = function(s) S.playerESPVars.ESP = s; S.refreshPlayerESP() end })
    playerESPGroup:AddToggle("PlayerChams", { Text = "Chams", Default = false, Callback = function(s) S.playerESPVars.Chams = s; S.refreshPlayerESP() end })
    playerESPGroup:AddToggle("PlayerHealth", { Text = "Show Health", Default = false, Callback = function(s) S.playerESPVars.Health = s; S.refreshPlayerESP() end })
    playerESPGroup:AddDivider()
    playerESPGroup:AddToggle("PlayerShowNames", { Text = "Show Names", Default = false, Callback = function(s) S.playerESPVars.Name = s; S.refreshPlayerESP() end })
    playerESPGroup:AddToggle("PlayerShowDistance", { Text = "Show Distance", Default = false, Callback = function(s) S.playerESPVars.Distance = s; S.refreshPlayerESP() end })

    -- Chest ESP moved to Left
    local chestESPGroup = Tabs.Visuals:AddLeftGroupbox("Chest ESP", "gift")
    chestESPGroup:AddToggle("ChestESP", { Text = "Chest ESP", Default = false, Callback = function(st) if st then S.startChestESP() else S.stopChestESP() end end })
    chestESPGroup:AddToggle("ChestChams", { Text = "Chams", Default = false, Callback = function(st) S.chestESPVars.Chams = st; S.refreshChestESP() end })
    chestESPGroup:AddDivider()
    chestESPGroup:AddToggle("ChestShowNames", { Text = "Show Names", Default = false, Callback = function(st) S.chestESPVars.Name = st; S.refreshChestESP() end })
    chestESPGroup:AddToggle("ChestShowDistance", { Text = "Show Distance", Default = false, Callback = function(st) S.chestESPVars.Distance = st; S.refreshChestESP() end })

    local itemESPGroup = Tabs.Visuals:AddRightGroupbox("Item ESP", "package")
    itemESPGroup:AddToggle("ItemShowNames", { Text = "Show Names (All Items)", Default = false, Callback = function(s) for _, sys in pairs(S.espSystems) do sys.vars.Name = s; sys.refresh() end end })
    itemESPGroup:AddToggle("ItemShowDistance", { Text = "Show Distance (All Items)", Default = false, Callback = function(s) for _, sys in pairs(S.espSystems) do sys.vars.Distance = s; sys.refresh() end end })
    itemESPGroup:AddDivider()
    itemESPGroup:AddToggle("ItemESPChams", { Text = "Chams (All Categories)", Default = false, Callback = function(s) for _, sys in pairs(S.espSystems) do sys.vars.Chams = s; sys.refresh() end end })
    itemESPGroup:AddDivider()

    local itemESPDefs = {
        { key="Gun", text="Gun ESP", tip="Guns (Red)" },
        { key="Melee", text="Melee ESP", tip="Melee (Orange)" },
        { key="Medical", text="Medical ESP", tip="Medical Items (Green)" },
        { key="Armor", text="Armor ESP", tip="Armor (Blue)" },
        { key="Food", text="Food ESP", tip="Food (Lime)" },
        { key="Resource", text="Resources ESP", tip="Resources (Cyan)" },
        { key="Carpart", text="Car part esp", tip="car parts (Cyan)" },
        { key="Fuel", text="Fuel ESP", tip="Fuel (Gold)" },
        { key="Ammunition", text="Ammunition ESP", tip="Ammo (Gold)" },
        { key="Ability", text="Abilities ESP", tip="Abilities (Purple)" },
    }
    for _, d in ipairs(itemESPDefs) do
        itemESPGroup:AddToggle(d.key .. "ESPEnabled", {
            Text = d.text, Default = false,
            Callback = function(s) S.espSystems[d.key].vars.ESP = s; S.espSystems[d.key].refresh() end,
        }):AddColorPicker(d.key .. "ESPColor", {
            Default = S.espSystems[d.key].colors.fill, Title = d.text .. " Color",
            Callback = function(c)
                S.espSystems[d.key].colors.fill = c
                for _, esp in pairs(S.espSystems[d.key].instances) do
                    if esp.Highlight and esp.Highlight.Parent then esp.Highlight.FillColor = c end
                    if esp.NameLabel then esp.NameLabel.TextColor3 = c end
                end
            end,
        })
    end

    itemESPGroup:AddDivider()
    itemESPGroup:AddLabel("Structures")
    itemESPGroup:AddToggle("StructureESP", { Text = "Structure ESP", Default = false, Callback = function(s) S.structureESPVars.ESP = s; S.refreshStructureESP() end })
    itemESPGroup:AddToggle("StructureChams", { Text = "Chams", Default = false, Callback = function(s) S.structureESPVars.Chams = s; S.refreshStructureESP() end })
    itemESPGroup:AddDivider()
    itemESPGroup:AddToggle("StructureShowNames", { Text = "Show Names", Default = false, Callback = function(s) S.structureESPVars.Name = s; S.refreshStructureESP() end })
    itemESPGroup:AddToggle("StructureShowDistance", { Text = "Show Distance", Default = false, Callback = function(s) S.structureESPVars.Distance = s; S.refreshStructureESP() end })
end

-- ============================================
-- UI: PLAYER TAB
-- ============================================
do
    local movementGroup = Tabs.Player:AddLeftGroupbox("Movement", "move")
    movementGroup:AddToggle("InfJump", { Text = "Inf Jump", Default = false })
    table.insert(S.connections, UserInputService.JumpRequest:Connect(function()
        if Toggles.InfJump.Value then
            local char = S.getLocalCharacter()
            if char then local h = char:FindFirstChildOfClass("Humanoid"); if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end end
        end
    end))
    movementGroup:AddToggle("NoClip", { Text = "NoClip", Default = false })
    movementGroup:AddToggle("AutoSprint", {
        Text = "Auto Sprint", Default = false,
        Callback = function(st) if st then S.startAutoSprint() else S.stopAutoSprint() end end,
    })
    movementGroup:AddToggle("BunnyHop", {
        Text = "Bunny Hop", Default = false,
        Callback = function(st) if st then S.startBhop() else S.stopBhop() end end,
    })

    local danceGroup = Tabs.Player:AddRightGroupbox("Funny Dance FE", "music")
    danceGroup:AddToggle("FunnyDance", {
        Text = "Funny Dance", Default = false,
        Callback = function(st) if st then S.startFunnyDance() else S.stopFunnyDance() end end,
    })
    danceGroup:AddDropdown("DanceStyle", { Values = { "Shuffle (1)", "Twist (2)", "Robot (3)" }, Default = 1, Text = "Dance Style" })

    local updateNoticeGroup = Tabs.Player:AddRightGroupbox("Update Notice", "info")
    updateNoticeGroup:AddLabel("Speed Hack, Fly, Bring Pickup Item")
    updateNoticeGroup:AddLabel("could not be made to work.")
end

-- ============================================
-- UI: COMBAT TAB
-- ============================================
do
    -- =========================================================
    -- LEFT COLUMN
    -- =========================================================

    -- ---------- KILL AURA ----------
    local killAuraBox = Tabs.Combat:AddLeftGroupbox("Kill Aura", "target")
    killAuraBox:AddToggle("KillAura", {
        Text = "Kill Aura", Default = false,
        Callback = function(st) if st then S.startKillAura() else S.stopKillAura() end end,
    })

    local killAuraTabs = killAuraBox:AddTabbox()
    local killAuraTargetTab = killAuraTabs:AddTab("Targeting", "crosshair")
    killAuraTargetTab:AddDropdown("KillAuraPriority", {
        Values = {"Nearest","Lowest HP","Highest HP"}, Default = 1, Text = "Target Priority",
    })
    killAuraTargetTab:AddSlider("KillAuraRange", {
        Text = "Base Range", Default = 6, Min = 1, Max = 20, Rounding = 0, Suffix = " studs",
    })
    killAuraTargetTab:AddToggle("KillAuraExtendedRange", { Text = "Extended Range (+2)", Default = true })

    local killAuraBehaviourTab = killAuraTabs:AddTab("Behaviour", "settings")
    killAuraBehaviourTab:AddToggle("KillAuraAutoEquip",     { Text = "Auto-Equip Weapon",     Default = false })
    killAuraBehaviourTab:AddToggle("KillAuraShowIndicator", { Text = "Show Target Indicator", Default = true  })
    killAuraBehaviourTab:AddSlider("KillAuraSwingRate", {
        Text = "Swing Delay", Default = 0.5, Min = 0.1, Max = 1.0, Rounding = 2, Suffix = " s",
    })

    -- ---------- AUTO SHOOT ----------
    local autoShootBox = Tabs.Combat:AddLeftGroupbox("Auto Shoot", "crosshair")
    autoShootBox:AddToggle("AutoShoot", {
        Text = "Auto Shoot", Default = false,
        Callback = function(st) if st then S.startAutoShoot() else S.stopAutoShoot() end end,
    })

    local autoShootTabs = autoShootBox:AddTabbox()
    local asTargetTab = autoShootTabs:AddTab("Targeting", "target")
    asTargetTab:AddDropdown("AutoShootPart", {
        Text = "Aim Part", Default = "Head",
        Values = {"Head","HumanoidRootPart","Torso","UpperTorso"},
    })
    asTargetTab:AddSlider("AutoShootRange", {
        Text = "Range", Default = 300, Min = 50, Max = 500, Rounding = 0, Suffix = " studs",
    })
    asTargetTab:AddDropdown("AutoShootPriority", {
        Text = "Target Priority", Default = "Nearest",
        Values = { "Nearest", "Farthest", "Lowest HP", "Highest HP" },
    })
    asTargetTab:AddDropdown("AutoShootTarget", {
        Text = "Target Mode", Default = "Mobs", Values = {"Mobs","Players","Both"},
    })

    local asFireTab = autoShootTabs:AddTab("Fire Rate", "zap")
    asFireTab:AddSlider("AutoShootOffset", {
        Text = "Fire Rate Offset", Default = 0.05, Min = 0.01, Max = 0.2, Rounding = 3, Suffix = " s",
    })
    asFireTab:AddLabel("Remote Arsenal: fires each slot at its own rate.", { DoesWrap = true })

    -- ---------- AUTO RELOAD ----------
    local autoReloadBox = Tabs.Combat:AddLeftGroupbox("Auto Reload", "refresh-cw")
    autoReloadBox:AddToggle("AutoReload", {
        Text = "Auto Reload", Default = false,
        Callback = function(st) if st then S.startAutoReload() else S.stopAutoReload() end end,
    })
    autoReloadBox:AddLabel("Handles Remote Arsenal per-slot.", { DoesWrap = true })


    -- =========================================================
    -- RIGHT COLUMN
    -- =========================================================

    -- ---------- AIMBOT ----------
    local aimbotBox = Tabs.Combat:AddRightGroupbox("Aimbot", "crosshair")
    aimbotBox:AddToggle("Aimbot", {
        Text = "Aimbot", Default = false,
        Callback = function(st) if st then S.startAimbot() else S.stopAimbot() end end,
    })

    local aimbotTabs = aimbotBox:AddTabbox()
    local abTargetTab = aimbotTabs:AddTab("Targeting", "target")
    abTargetTab:AddDropdown("AimbotTarget",   { Text = "Target Mode",     Default = "Mobs",     Values = {"Mobs","Players","Both"} })
    abTargetTab:AddDropdown("AimbotPart",     { Text = "Aim Part",        Default = "Head",     Values = {"Head","HumanoidRootPart","Torso","UpperTorso"} })
    abTargetTab:AddDropdown("AimbotPriority", { Text = "Target Priority", Default = "Distance", Values = {"Distance","FOV"} })
    abTargetTab:AddSlider("AimbotRange",      { Text = "Max Range",   Default = 200, Min = 50, Max = 1000, Rounding = 0 })
    abTargetTab:AddSlider("AimbotFOV",        { Text = "FOV Radius",  Default = 100, Min = 10, Max = 500,  Rounding = 0 })

    local abSmoothingTab = aimbotTabs:AddTab("Smoothing", "sliders-horizontal")
    abSmoothingTab:AddSlider("AimbotSmoothness", { Text = "Smoothness", Default = 0.3, Min = 0, Max = 1, Rounding = 2 })
    abSmoothingTab:AddToggle("AimbotPrediction", { Text = "Velocity Prediction", Default = false })
    abSmoothingTab:AddSlider("AimbotPredictionAmount", { Text = "Prediction Amount", Default = 0.15, Min = 0.05, Max = 0.5, Rounding = 2 })
    abSmoothingTab:AddDivider()
    abSmoothingTab:AddToggle("AimbotFOVCircle", { Text = "FOV Circle", Default = false })

    -- ---------- SILENT AIM ----------
    local silentAimBox = Tabs.Combat:AddRightGroupbox("Silent Aim", "crosshair")
    silentAimBox:AddToggle("SilentAim", {
        Text = "Silent Aim",
        Default = false,
        Tooltip = "Hooks BulletWeapon.fire. Redirects shots client-side without moving the camera.",
        Callback = function(st) if st then S.startSilentAim() else S.stopSilentAim() end end,
    })

    local silentAimTabs = silentAimBox:AddTabbox()
    local saTargetTab = silentAimTabs:AddTab("Targeting", "target")
    saTargetTab:AddDropdown("SilentAimTarget",   { Text = "Silent Target",   Default = "Mobs",    Values = {"Mobs","Players","Both"} })
    saTargetTab:AddDropdown("SilentAimPart",     { Text = "Silent Aim Part", Default = "Head",    Values = {"Head","HumanoidRootPart","Torso","UpperTorso"} })
    saTargetTab:AddDropdown("SilentAimPriority", { Text = "Silent Priority", Default = "Nearest", Values = {"Nearest","Farthest","Lowest HP","Highest HP","FOV"} })
    saTargetTab:AddSlider("SilentAimRange",      { Text = "Silent Range", Default = 300, Min = 50, Max = 1000, Rounding = 0 })
    saTargetTab:AddSlider("SilentAimFOV",        { Text = "Silent FOV",   Default = 150, Min = 10, Max = 500,  Rounding = 0 })

    local saPredictionTab = silentAimTabs:AddTab("Prediction", "trending-up")
    saPredictionTab:AddToggle("SilentAimPrediction", { Text = "Silent Prediction", Default = true })
    saPredictionTab:AddSlider("SilentAimPredictionAmount", { Text = "Silent Predict Amount", Default = 0.12, Min = 0.0, Max = 0.5, Rounding = 2 })
end

-- ============================================
-- UI: EXPLOITS TAB
-- ============================================
do
        local instantPromptGroup = Tabs.Exploits:AddGroupbox("Instant Prompt", "zap")
    instantPromptGroup:AddToggle("InstantPrompt", {
        Text = "Instant Proximity Prompt",
        Default = false,
        Tooltip = "Skips the hold-duration on ProximityPrompts (E-to-hold interactions).",
        Callback = function(st)
            if st then S.startInstantPrompt() else S.stopInstantPrompt() end
        end,
    })
    instantPromptGroup:AddLabel("Fires the prompt the instant you press E.", { DoesWrap = true })

    local repairAuraGroup = Tabs.Exploits:AddRightGroupbox("Repair Aura", "wrench")
    repairAuraGroup:AddToggle("RepairAura", {
        Text = "Repair Aura", Default = false,
        Callback = function(st) if st then S.startRepairAura() else S.stopRepairAura() end end,
    })
    repairAuraGroup:AddSlider("RepairAuraRange", { Text = "Range", Default = 30, Min = 5, Max = 30, Rounding = 0, Suffix = " studs" })
    repairAuraGroup:AddSlider("RepairAuraRate", { Text = "Rate", Default = 1, Min = 1, Max = 10, Rounding = 0, Suffix = "/s" })
    repairAuraGroup:AddLabel("Requires: Repair Hammer equipped", { DoesWrap = true })
end

-- ============================================
-- UI: AUTO PICKUP TAB
-- ============================================
do
    local pickupSettings = Tabs.AutoPickup:AddLeftGroupbox("Pickup Settings", "settings")
    pickupSettings:AddToggle("AutoPickup", {
        Text = "Auto Pickup", Default = false,
        Callback = function(st) if st then S.startAutoPickup() else S.stopAutoPickup() end end,
    })
    pickupSettings:AddSlider("AutoPickupRadius", { Text = "Radius", Default = 20, Min = 5, Max = 35, Rounding = 0, Suffix = " studs" })
    pickupSettings:AddToggle("AutoPickupAll", { Text = "All Items", Default = false })
    pickupSettings:AddDivider()
    pickupSettings:AddLabel("FE Methods", { DoesWrap = true })
    pickupSettings:AddToggle("AutoPickupMethodRemote", { Text = "A – Remote", Default = true })
    pickupSettings:AddToggle("AutoPickupMethodTouch", { Text = "B – Touch", Default = true })
    pickupSettings:AddToggle("AutoPickupMethodPrompt", { Text = "C – ProximityPrompt", Default = true })
    pickupSettings:AddDivider()
    pickupSettings:AddDropdown("AutoPickupWhitelist", {
        Values = S.pickupItemNames, Default = 1, Multi = true, Text = "Whitelist", Searchable = true,
    })
    pickupSettings:AddDropdown("AutoPickupBlacklist", {
        Values = S.pickupItemNames,
        Default = { "Chips","Carrot","Bloxiade","Beans","MRE","Bloxy Cola","Nuclear Fuel","Refined Fuel","Fuel","Power Armor Arm","Power Armor Core","Radio Tower Part","AC","Battery","Battery Pack","Bucket","Dumbell","Exhaust Pipe","Reactor Component","Refined Metal","Satellite Dish","Scrap","Screws","Spatula","Tray","TV","Watch","Zombie Heart","Airstrike","Attack Order","Call of the Dead","Summon Brute","Summon Zombies","Taunt","The Future","The Past","The Present" },
        Multi = true, Text = "Blacklist", Searchable = true,
    })

    local categoryFilters = Tabs.AutoPickup:AddRightGroupbox("Category Filters", "filter")
    categoryFilters:AddToggle("UseCategoryFilter", { Text = "Use Category Filters", Default = false })
    categoryFilters:AddDivider()
    categoryFilters:AddToggle("PickupAmmo", { Text = "Ammo", Default = false })
    categoryFilters:AddToggle("PickupResource", { Text = "Resources", Default = false })
    categoryFilters:AddToggle("PickupFuel", { Text = "Fuel", Default = false })
    categoryFilters:AddToggle("PickupMedical", { Text = "Medical", Default = false })
    categoryFilters:AddToggle("PickupCarpart", {
        Text = "Car Parts",
        Default = false,
        Tooltip = "Basic Turret, Heavy Turret, Minigun Turret, Plow, Self-Repair Device, Steel Plating, Vehicle Storage.",
    })
    categoryFilters:AddToggle("PickupMisc", {
        Text = "Misc Items",
        Default = false,
        Tooltip = "Emerald, Gas Mask, Power Armor Arm/Core, Radio Tower Part, Blueprint, Military Keycard, Repair Hammer, Suppressor.",
    })
    categoryFilters:AddToggle("PickupConsumables", {
        Text = "Consumables",
        Default = false,
        Tooltip = "Grenade, Molotov.",
    })

    local bringPickupGroup = Tabs.AutoPickup:AddRightGroupbox("Bring Pickup Item", "download")
    bringPickupGroup:AddToggle("BringPickupItem", {
        Text = "Bring Pickup Item",
        Default = false,
        Tooltip = "Teleport to items and pick them up. Auto-disables when backpack is full.",
        Callback = function(st)
            if st then S.startBringPickup() else S.stopBringPickup() end
        end,
    })
    bringPickupGroup:AddToggle("BringAllPickup", {
        Text = "All Pickup Items",
        Default = false,
        Tooltip = "Pick up all dropped items without filtering.",
    })
    bringPickupGroup:AddDropdown("BringPickupSortOrder", {
        Values = {"Nearest First", "Farthest First", "Alphabetical", "Reverse Alphabetical"},
        Default = 1,
        Text = "Sort Order",
        Tooltip = "Sets which items are picked up first.",
    })
    bringPickupGroup:AddLabel("Item Filter (when 'All Pickup Items' is off)", { DoesWrap = true })
    bringPickupGroup:AddDropdown("BringPickupWhitelist", {
        Values = S.pickupItemNames,
        Default = 1,
        Multi = true,
        Text = "Item Filter",
        Tooltip = "Only items in this list are teleported to when 'All Pickup Items' is off.",
        Searchable = true,
    })
end

-- ============================================
-- UI: MISC TAB
-- ============================================
do
    local utilityGroup = Tabs.Misc:AddLeftGroupbox("Utilities", "shield-check")
    utilityGroup:AddToggle("ObjectIdentifier", {
        Text = "Object Identifier", Default = false,
        Callback = function(st)
            if st then
                S.objectIDActive = true
                S.objectIDLogs = {}
                S.createObjectIDGUI()
                S.setupObjectIDMouse()
                S.setupObjectIDKeyboard()
            else
                S.stopObjectIdentifier()
            end
        end,
    })
    utilityGroup:AddToggle("AntiAFK", {
        Text = "Anti-AFK", Default = true,
        Callback = function(st) if st then S.startAntiAFK() else S.stopAntiAFK() end end,
    })
    utilityGroup:AddToggle("Fullbright", {
        Text = "Fullbright", Default = false,
        Callback = function(st) if st then S.enableFullbright() else S.disableFullbright() end end,
    })
    utilityGroup:AddToggle("RemoveFog", {
        Text = "Remove Fog", Default = false,
        Callback = function(st) if st then S.enableRemoveFog() else S.disableRemoveFog() end end,
    })

    local unloadGroup = Tabs.Misc:AddLeftGroupbox("Script Control", "power")
    unloadGroup:AddButton("Unload Script", function()
        Library.Unloaded = true
        task.wait(0.1)
        Library:Unload()
    end)

    local buildingRevealGroup = Tabs.Misc:AddLeftGroupbox("Building Reveal", "building")
    for _, def in ipairs(S.buildingDefs) do
        buildingRevealGroup:AddButton("Reveal " .. def.name, function()
            S.revealBuilding(def.name, 10)
        end, { Tooltip = "Highlights the " .. def.name .. " and points an arrow toward it for 10 seconds." })
    end
    buildingRevealGroup:AddLabel("Reveals ESP + direction for 10s.", { DoesWrap = true })

    local serverGroup = Tabs.Misc:AddRightGroupbox("Server Tools", "server")
    serverGroup:AddButton("Server Hop", function() S.serverHop() end)
    serverGroup:AddButton("Rejoin Server", function() S.rejoinServer() end)
    serverGroup:AddDivider()
    serverGroup:AddLabel("Current Job ID:")
    serverGroup:AddLabel("JobId", { Text = game.JobId ~= "" and game.JobId:sub(1, 30) .. "..." or "Unknown", DoesWrap = true })

    local remoteSpyGroup = Tabs.Misc:AddRightGroupbox("Remote Spy", "bug")
    remoteSpyGroup:AddToggle("RemoteSpyEnabled", {
        Text = "Enable Remote Spy", Default = false,
        Callback = function(st) if st then S.startRemoteSpy() else S.stopRemoteSpy() end end,
    })
    remoteSpyGroup:AddLabel("Check Developer Console (F9)")

    local fpsUnlockerGroup = Tabs.Misc:AddRightGroupbox("FPS Unlocker", "zap")
    fpsUnlockerGroup:AddSlider("FPSCap", {
        Text = "FPS Cap", Default = 144, Min = 30, Max = 360, Rounding = 0, Suffix = " fps",
        Callback = function(v)
            if Toggles.FPSUnlock and Toggles.FPSUnlock.Value then pcall(function() if setfpscap then setfpscap(v) end end) end
        end,
    })
    fpsUnlockerGroup:AddToggle("FPSUnlock", {
        Text = "Unlock FPS", Default = false,
        Callback = function(st)
            pcall(function()
                if setfpscap then
                    if st then setfpscap(Options.FPSCap and Options.FPSCap.Value or 144)
                    else setfpscap(60) end
                end
            end)
        end,
    })
end

-- ============================================
-- UNLOAD CLEANUP
-- ============================================
Library:OnUnload(function()
    for char, _ in pairs(S.mobESPInstances) do S.removeMobESP(char) end
    for _, sys in pairs(S.espSystems) do for item, _ in pairs(sys.instances) do sys.remove(item) end end
    for p, _ in pairs(S.playerESPInstances) do S.removePlayerESP(p) end
    for s, _ in pairs(S.structureESPInstances) do S.removeStructureESP(s) end
    for c, _ in pairs(S.chestESPInstances) do S.removeChestESP(c) end
    for _, conn in ipairs(S.connections) do
        if typeof(conn) == "RBXScriptConnection" then pcall(function() conn:Disconnect() end) end
    end
    S.connections = {}
    S.stopAutoPickup(); S.stopBringPickup(); S.stopRepairAura(); S.stopAutoSprint(); S.stopKillAura()
    S.stopAimbot(); S.stopSilentAim(); S.stopBhop(); S.stopFunnyDance(); S.stopRemoteSpy()
    S.stopAutoShoot(); S.stopAutoReload(); S.stopObjectIdentifier(); S.stopChestESP(); S.stopRadar()
    pcall(function() if setfpscap then setfpscap(60) end end)
    if S.fovCircle then pcall(function() S.fovCircle:Remove() end); S.fovCircle = nil end
    if Toggles.RemoveFog and Toggles.RemoveFog.Value then S.disableRemoveFog() end
    if Toggles.Fullbright and Toggles.Fullbright.Value then S.disableFullbright() end
    S.stopAntiAFK()
        for name, _ in pairs(S.buildingRevealActive or {}) do
        local data = S.buildingRevealActive[name]
        if data then
            if data.highlight then pcall(function() data.highlight:Destroy() end) end
            if data.billboard then pcall(function() data.billboard:Destroy() end) end
            if data.conn then pcall(function() data.conn:Disconnect() end) end
            if data.indicator then
                pcall(function() data.indicator.line:Remove() end)
                pcall(function() data.indicator.label:Remove() end)
            end
        end
        S.buildingRevealActive[name] = nil
                    if data.anchor and data.anchor.Parent then
                pcall(function() data.anchor:Destroy() end)
            end
    end
    Library:Notify({ Title = "test", Description = "Unloaded.", Time = 3 })
end)

-- ============================================
-- KEYBINDS TAB
-- ============================================
do
    local MenuGroup = Tabs.Keybinds:AddLeftGroupbox("Keybinds", "key")
    local Toggle = MenuGroup:AddToggle("MyToggle", { Text = "Example Toggle", Default = false })
    Toggle:AddKeyPicker("KeyPicker", {
        Default = "K", Mode = "Toggle", Text = "Example keybind", NoUI = false,
    })

    local radarGroup = Tabs.Keybinds:AddLeftGroupbox("Minimap Radar", "map")
    radarGroup:AddToggle("Radar", {
        Text = "Enable Radar", Default = false,
        Callback = function(st) if st then S.startRadar() else S.stopRadar() end end,
    }):AddKeyPicker("RadarKeybind", {
        Default = "M", Mode = "Toggle", Text = "Toggle Radar",
    })

    radarGroup:AddToggle("RadarRotate",    { Text = "Rotate with Camera", Default = true })
    radarGroup:AddToggle("RadarShowRings", { Text = "Show Distance Rings", Default = true })
    radarGroup:AddDivider()
    radarGroup:AddSlider("RadarSize",    { Text = "Size",     Default = 150, Min = 60, Max = 260, Rounding = 0 })
    radarGroup:AddSlider("RadarRange",   { Text = "Range",    Default = 300, Min = 100, Max = 1000, Rounding = 0, Suffix = " studs" })
    radarGroup:AddSlider("RadarOffsetX", { Text = "Position X", Default = 180, Min = 0, Max = 2000, Rounding = 0 })
    radarGroup:AddSlider("RadarOffsetY", { Text = "Position Y", Default = 180, Min = 0, Max = 2000, Rounding = 0 })
    radarGroup:AddSlider("RadarTransparency", { Text = "Background Alpha", Default = 0.7, Min = 0.0, Max = 0.95, Rounding = 2 })

    radarGroup:AddDivider()
    radarGroup:AddLabel("Item Categories", { DoesWrap = true })
    radarGroup:AddToggle("RadarGun",        { Text = "Gun",        Default = true })
    radarGroup:AddToggle("RadarMelee",      { Text = "Melee",      Default = false })
    radarGroup:AddToggle("RadarMedical",    { Text = "Medical",    Default = true })
    radarGroup:AddToggle("RadarArmor",      { Text = "Armor",      Default = false })
    radarGroup:AddToggle("RadarFood",       { Text = "Food",       Default = false })
    radarGroup:AddToggle("RadarResource",   { Text = "Resources",  Default = false })
    radarGroup:AddToggle("RadarCarpart",    { Text = "Car Parts",  Default = false })
    radarGroup:AddToggle("RadarFuel",       { Text = "Fuel",       Default = false })
    radarGroup:AddToggle("RadarAmmunition", { Text = "Ammunition", Default = true })
    radarGroup:AddToggle("RadarAbility",    { Text = "Abilities",  Default = false })

    radarGroup:AddDivider()
    radarGroup:AddLabel("World Objects", { DoesWrap = true })
    radarGroup:AddToggle("RadarChests",     { Text = "Chests",     Default = true })
    radarGroup:AddToggle("RadarStructures", { Text = "Structures", Default = false })
end

-- ============================================
-- UI SETTINGS TAB
-- ============================================
do
    local MenuGroup = Tabs["UI Settings"]:AddLeftGroupbox("Menu", "wrench")
    MenuGroup:AddToggle("KeybindMenuOpen", {
        Default = Library.KeybindFrame.Visible, Text = "Open Keybind Menu",
        Callback = function(v) Library.KeybindFrame.Visible = v end,
    })
    MenuGroup:AddToggle("ShowCustomCursor", {
        Text = "Custom Cursor", Default = true,
        Callback = function(v) Library.ShowCustomCursor = v end,
    })
    MenuGroup:AddDropdown("NotificationSide", {
        Values = { "Left", "Right" }, Default = "Right", Text = "Notification Side",
        Callback = function(v) Library:SetNotifySide(v) end,
    })
    MenuGroup:AddDropdown("DPIDropdown", {
        Values = { "50%","75%","100%","125%","150%","175%","200%" }, Default = "100%", Text = "DPI Scale",
        Callback = function(v)
            v = v:gsub("%%", "")
            Library:SetDPIScale(tonumber(v))
        end,
    })
    MenuGroup:AddSlider("UICornerSlider", {
        Text = "Corner Radius", Default = Library.CornerRadius, Min = 0, Max = 20, Rounding = 0,
        Callback = function(v) Window:SetCornerRadius(v) end,
    })
    MenuGroup:AddDivider()
    MenuGroup:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", { Default = "RightShift", NoUI = true, Text = "Menu keybind" })
end

Library.ToggleKeybind = Options.MenuKeybind

-- ============================================
-- THEME / SAVE MANAGERS
-- ============================================
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
ThemeManager:SetFolder("SPYMM")
SaveManager:SetFolder("SPYMM/survive-the-apocalypse")
SaveManager:BuildConfigSection(Tabs["UI Settings"])
ThemeManager:ApplyToTab(Tabs["UI Settings"])
SaveManager:LoadAutoloadConfig()

-- Start Anti-AFK by default
S.startAntiAFK()

-- ============================================
-- POPUP TEXT LOGGER (always active, no UI)
-- ============================================
do
    local RS = game:GetService("ReplicatedStorage")
    local PG = game:GetService("Players").LocalPlayer.PlayerGui

    local function log(source, text)
        text = tostring(text)
        if text == "" then return end
        print(("[%s] %s"):format(source, text))
    end

    local function hookRemote(remote, label)
        if not remote then return end
        if remote:IsA("RemoteEvent") then
            remote.OnClientEvent:Connect(function(...)
                for i = 1, select("#", ...) do
                    local v = select(i, ...)
                    if type(v) == "string" and v ~= "" then
                        log(label, v)
                    end
                end
            end)
        elseif remote:IsA("RemoteFunction") then
            local prev = remote.OnClientInvoke
            remote.OnClientInvoke = function(...)
                for i = 1, select("#", ...) do
                    local v = select(i, ...)
                    if type(v) == "string" and v ~= "" then
                        log(label .. "Fn", v)
                    end
                end
                if prev then return prev(...) end
            end
        end
    end

    task.spawn(function()
        local repl = RS:WaitForChild("Remotes", 30)
        local rep  = repl and repl:WaitForChild("Replication", 30)
        if not rep then return end
        hookRemote(rep:WaitForChild("Popup", 30),    "Popup")
        hookRemote(rep:WaitForChild("BigPopup", 30), "BigPopup")
    end)

    local function readText(gui)
        local out = {}
        for _, d in ipairs(gui:GetDescendants()) do
            if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" and d.Visible then
                table.insert(out, d.Text)
            end
        end
        if #out == 0 and (gui:IsA("TextLabel") or gui:IsA("TextButton")) and gui.Text ~= "" then
            out[1] = gui.Text
        end
        return table.concat(out, " | ")
    end

    local function watchUI(container, label)
        if not container then return end
        local function handle(child)
            if not child:IsA("GuiObject") then return end
            local last
            local function read()
                local t = readText(child)
                if t == "" or t == last then return end
                last = t
                log(label, t)
            end
            task.spawn(function()
                task.wait(0.05) read()
                task.wait(0.2)  read()
            end)
            for _, d in ipairs(child:GetDescendants()) do
                if d:IsA("TextLabel") or d:IsA("TextButton") then
                    d:GetPropertyChangedSignal("Text"):Connect(function()
                        task.wait(0.05); read()
                    end)
                end
            end
        end
        for _, c in ipairs(container:GetChildren()) do handle(c) end
        container.ChildAdded:Connect(handle)
    end

    task.spawn(function()
        local g = PG:WaitForChild("Popups", 30)
        watchUI(g and g:WaitForChild("Popups", 30), "PopupUI")
    end)
    task.spawn(function()
        local m = PG:WaitForChild("Main", 30)
        watchUI(m and m:WaitForChild("BigPopup", 30), "BigPopupUI")
    end)

    print("[PopupTextLog] active")
end

-- ============================================
-- INIT
-- ============================================
Library:Notify({ Title = "test", Description = "Loaded! Right Shift = toggle menu.", Time = 5 })
print("SPYMM v8.4 loaded | " .. #S.itemNames .. " items tracked | Right Shift = menu")