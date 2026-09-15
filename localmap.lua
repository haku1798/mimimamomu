local Remote = game:GetService("ReplicatedStorage").Remotes.Misc.UpdateMap

-- 1. Disconnect the real server connections so it doesn't overwrite our fake map
for _, conn in ipairs(getconnections(Remote.OnClientEvent)) do
    conn:Disconnect()
end

local tiles = {}
local icons = {}

-- 2. Generate a huge grid of tiles (e.g., -50 to 50)
for x = -50, 50 do
    for y = -50, 50 do
        local tileType = "Road" -- Default tile type
        
        -- Add some variety so it's not just a flat color
        if x == 0 and y == 0 then
            tileType = "Center"
        elseif math.abs(x) < 5 and math.abs(y) < 5 then
            tileType = "Center"
        elseif (x + y) % 10 == 0 then
            tileType = "Power Plant"
        end
        
        table.insert(tiles, {
            TileType = tileType,
            X = x,
            Y = y,
            Biomes = {}
        })
    end
end

-- 3. Add some icons for POIs you want to see
local poiIcons = {
    {X = 0, Y = 0, AssetId = "rbxassetid://99240475732118", IconType = "Power Plant"},
    {X = 45, Y = 45, AssetId = "rbxassetid://125331474611505", Crate = true},
    {X = -45, Y = -45, AssetId = "rbxassetid://125331474611505", Crate = true},
}

for _, icon in ipairs(poiIcons) do
    table.insert(icons, icon)
end

-- 4. Fire the signal to draw the map
firesignal(Remote.OnClientEvent, tiles, icons)
print("Full map injected!")