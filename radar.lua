--[[ RADAR TEST — standalone, no dependencies
     Draws mobs / players / dropped items near you.
     Use this to verify Solara's Drawing API works.
]]

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local Workspace         = game:GetService("Workspace")
local LocalPlayer       = Players.LocalPlayer

-- ============================================
-- CONFIG
-- ============================================
local RADAR_SIZE     = 150      -- pixel radius
local RADAR_RANGE    = 300      -- studs
local RADAR_POS      = Vector2.new(180, 180)  -- screen position (top-left)
local ROTATE_WITH_CAMERA = true

-- Mob names — paste from your main script's S.mobNames
local MOB_NAMES = {
    "Runner","Crawler","Elemental","Phaser","Hazmat","Electrified","Riot","Zombie",
    "Brute","Spitter","Rebel","Bandit","Gunner","Sniper","Heavy Rebel","Butcher",
    "Bloater","Screamer","Armored Zombie","Emforcer Riot","Acidic Bloater",
    "Blitzer Runner","Blighted Spitter","Tank Muscle","Nuclear Hazmat",
    "Aberrant Screamer","Shadow Muscle","Electrified Muscle","Specter Phaser",
    "Frost Elemental","Muscle","Infested Zombie","Infested Runner",
    "Infested Crawler","Infested Riot","Infested Screamer","Infested Muscle",
    "Exterminator","Night Hunter","Experiment","Infested Brute","Cyborg",
}
local MOB_SET = {}
for _, n in ipairs(MOB_NAMES) do MOB_SET[n] = true end

-- ============================================
-- DRAWING POOL
-- ============================================
local bg        = Drawing.new("Circle")
local border    = Drawing.new("Circle")
local ring1     = Drawing.new("Circle")
local ring2     = Drawing.new("Circle")
local ring3     = Drawing.new("Circle")
local centerDot = Drawing.new("Circle")
local cone      = Drawing.new("Triangle")

bg.Filled = true; bg.NumSides = 64
bg.Color = Color3.fromRGB(12,12,18); bg.Thickness = 0
bg.Transparency = 0.7

border.Filled = false; border.NumSides = 64
border.Color = Color3.fromRGB(90,90,110); border.Thickness = 1.5

for _, ring in ipairs({ring1, ring2, ring3}) do
    ring.Filled = false; ring.NumSides = 48
    ring.Color = Color3.fromRGB(70,70,90); ring.Thickness = 1
    ring.Transparency = 0.55
end

centerDot.Filled = true; centerDot.NumSides = 16
centerDot.Color = Color3.fromRGB(120,220,255); centerDot.Radius = 3

cone.Filled = true
cone.Color = Color3.fromRGB(120,220,255); cone.Transparency = 0.35

-- Dot pool
local MAX_DOTS = 300
local dots = {}
for i = 1, MAX_DOTS do
    local d = Drawing.new("Circle")
    d.Filled = true; d.NumSides = 8
    d.Radius = 3; d.Transparency = 1; d.Visible = false
    dots[i] = d
end

print("[RadarTest] Drawing pool allocated:", MAX_DOTS, "dots")

-- ============================================
-- HELPERS
-- ============================================
local function getMainPart(model)
    return model:FindFirstChild("HumanoidRootPart")
        or model:FindFirstChild("Torso")
        or model:FindFirstChild("UpperTorso")
        or model.PrimaryPart
        or model:FindFirstChildWhichIsA("BasePart")
end

local function collectTargets(myPos)
    local out = {}
    local r2 = RADAR_RANGE * RADAR_RANGE

    -- Mobs
    local charsFolder = Workspace:FindFirstChild("Characters")
    if charsFolder then
        local playerChars = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character then playerChars[p.Character] = true end
        end
        for _, mob in ipairs(charsFolder:GetChildren()) do
            if mob:IsA("Model") and not playerChars[mob] and MOB_SET[mob.Name] then
                local part = getMainPart(mob)
                if part then
                    local dx = part.Position.X - myPos.X
                    local dz = part.Position.Z - myPos.Z
                    if dx*dx + dz*dz <= r2 then
                        table.insert(out, { pos = part.Position, color = Color3.fromRGB(255,60,60), size = 3.5 })
                    end
                end
            end
        end
    end

    -- Players
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local dx = hrp.Position.X - myPos.X
                local dz = hrp.Position.Z - myPos.Z
                if dx*dx + dz*dz <= r2 then
                    table.insert(out, { pos = hrp.Position, color = Color3.fromRGB(80,160,255), size = 4 })
                end
            end
        end
    end

    -- Dropped items
    local itemsFolder = Workspace:FindFirstChild("DroppedItems")
    if itemsFolder then
        for _, item in ipairs(itemsFolder:GetChildren()) do
            local part = getMainPart(item)
            if part then
                local dx = part.Position.X - myPos.X
                local dz = part.Position.Z - myPos.Z
                if dx*dx + dz*dz <= r2 then
                    table.insert(out, { pos = part.Position, color = Color3.fromRGB(0,220,255), size = 2.5 })
                end
            end
        end
    end

    return out
end

-- ============================================
-- MAIN LOOP
-- ============================================
local stats = { mobs=0, players=0, items=0, drawn=0 }

local conn = RunService.RenderStepped:Connect(function()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local camera = Workspace.CurrentCamera
    if not hrp or not camera then
        bg.Visible = false; border.Visible = false
        ring1.Visible = false; ring2.Visible = false; ring3.Visible = false
        centerDot.Visible = false; cone.Visible = false
        for _, d in ipairs(dots) do d.Visible = false end
        return
    end

    local center      = RADAR_POS
    local radarRadius = RADAR_SIZE
    local scale       = radarRadius / RADAR_RANGE

    -- Camera horizontal direction
    local look = camera.CFrame.LookVector
    local camLx, camLz = look.X, look.Z
    local hMag = math.sqrt(camLx*camLx + camLz*camLz)
    if hMag > 0.001 then camLx, camLz = camLx/hMag, camLz/hMag else camLx, camLz = 0, -1 end

    local bFwdX, bFwdZ, bRightX, bRightZ
    if ROTATE_WITH_CAMERA then
        bFwdX, bFwdZ = camLx, camLz
        bRightX, bRightZ = -camLz, camLx
    else
        bFwdX, bFwdZ = 0, -1
        bRightX, bRightZ = 1, 0
    end

    -- Background
    bg.Position = center; bg.Radius = radarRadius; bg.Visible = true
    border.Position = center; border.Radius = radarRadius; border.Visible = true

    -- Rings at 25/50/75%
    ring1.Position = center; ring1.Radius = radarRadius * 0.25; ring1.Visible = true
    ring2.Position = center; ring2.Radius = radarRadius * 0.50; ring2.Visible = true
    ring3.Position = center; ring3.Radius = radarRadius * 0.75; ring3.Visible = true

    -- Center dot
    centerDot.Position = center; centerDot.Visible = true

    -- Facing cone
    local fwdSX = camLx * bRightX + camLz * bRightZ
    local fwdSY = -(camLx * bFwdX + camLz * bFwdZ)
    local fLen = math.sqrt(fwdSX*fwdSX + fwdSY*fwdSY)
    if fLen > 0.001 then fwdSX, fwdSY = fwdSX/fLen, fwdSY/fLen end

    local coneLen = radarRadius * 0.35
    local spread  = math.rad(28)
    local cs, sn  = math.cos(spread), math.sin(spread)
    local ax = fwdSX * cs - fwdSY * sn
    local ay = fwdSX * sn + fwdSY * cs
    local bx = fwdSX * cs + fwdSY * sn
    local by = -fwdSX * sn + fwdSY * cs

    cone.PointA  = center
    cone.PointB  = center + Vector2.new(ax, ay) * coneLen
    cone.PointC  = center + Vector2.new(bx, by) * coneLen
    cone.Visible = true

    -- Targets
    local targets = collectTargets(hrp.Position)
    local myX, myZ = hrp.Position.X, hrp.Position.Z
    local r2 = radarRadius * radarRadius
    local poolIdx = 1

    stats.mobs = 0; stats.players = 0; stats.items = 0

    for _, t in ipairs(targets) do
        if poolIdx > MAX_DOTS then break end
        local dx = t.pos.X - myX
        local dz = t.pos.Z - myZ
        local sx = dx * bRightX + dz * bRightZ
        local sy = -(dx * bFwdX + dz * bFwdZ)
        local px = center.X + sx * scale
        local py = center.Y + sy * scale
        local ddx, ddy = px - center.X, py - center.Y
        if ddx*ddx + ddy*ddy <= r2 then
            local d = dots[poolIdx]
            d.Position = Vector2.new(px, py)
            d.Color = t.color
            d.Radius = t.size or 3
            d.Visible = true
            poolIdx = poolIdx + 1
        end
    end
    for i = poolIdx, MAX_DOTS do
        if dots[i].Visible then dots[i].Visible = false end
    end
    stats.drawn = poolIdx - 1
end)

-- ============================================
-- CLEANUP COMMAND
-- ============================================
-- Run "getgenv().stopRadarTest()" in the executor to kill it.
getgenv().stopRadarTest = function()
    if conn then conn:Disconnect() end
    for _, d in ipairs(dots) do d:Remove() end
    bg:Remove(); border:Remove()
    ring1:Remove(); ring2:Remove(); ring3:Remove()
    centerDot:Remove(); cone:Remove()
    print("[RadarTest] stopped and cleaned up")
end

-- ============================================
-- STATUS PRINTER
-- ============================================
task.spawn(function()
    while conn do
        task.wait(3)
        print(string.format("[RadarTest] drawn=%d  (%d mobs, %d players, %d items in range)",
            stats.drawn, stats.mobs, stats.players, stats.items))
    end
end)

print("[RadarTest] Started. Top-left radar @ 180,180 radius 150.")
print("[RadarTest] Run getgenv().stopRadarTest() to stop.")