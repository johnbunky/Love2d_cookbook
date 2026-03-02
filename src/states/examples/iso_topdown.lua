-- src/states/examples/iso_topdown.lua
-- Orthographic top-down world: tile grid, depth-sorted sprites, walking character
-- No Mat4 needed — world→screen is just scale + offset

local Utils  = require("src.utils")
local Timer  = require("src.systems.timer")
local Example = {}

local W, H
local timer
local time = 0

-- -------------------------
-- World → Screen projection
-- Two modes: top-down and isometric
-- -------------------------
local TILE      = 48       -- pixels per tile (zoom changes this)
local TILE_MIN  = 24
local TILE_MAX  = 96
local MODE      = "iso"    -- "top" or "iso"
local DEBUG     = true     -- show depth numbers on every tile

-- Camera: world position at screen center, clamped to map
local camX, camY = 9, 7

-- Top-down: y-axis is depth (screen Y)
local function toScreenTop(wx, wy)
    local sx = (wx - camX) * TILE + W/2
    local sy = (wy - camY) * TILE + H/2
    return sx, sy
end

-- Isometric: 2:1 diamond projection
-- wx,wy are world X,Z  |  wh is world height (Y)
local function toScreenIso(wx, wy, wh)
    wh = wh or 0
    local sx = (wx - wy) * TILE*0.5        + W/2  - (camX - camY) * TILE*0.5
    local sy = (wx + wy) * TILE*0.25       + H/2  - (camX + camY) * TILE*0.25 - wh*TILE*0.5
    return sx, sy
end

local function toScreen(wx, wy, wh)
    if MODE == "iso" then
        return toScreenIso(wx, wy, wh)
    else
        return toScreenTop(wx, wy)
    end
end

-- -------------------------
-- Map
-- -------------------------
local MAP_W, MAP_H = 10, 8

-- Tile types
local TILES = {
    [0] = { color={0.08,0.10,0.08}, passable=false },  -- void
    [1] = { color={0.22,0.28,0.18}, passable=true  },  -- grass
    [2] = { color={0.32,0.28,0.20}, passable=true  },  -- dirt path
    [3] = { color={0.18,0.22,0.30}, passable=true  },  -- stone floor
    [4] = { color={0.30,0.24,0.18}, passable=false },  -- wall
    [5] = { color={0.15,0.35,0.20}, passable=true  },  -- dark grass
    [6] = { color={0.30,0.35,0.42}, passable=true  },  -- raised platform (top)
}

-- Platform definitions: tiles that have raised height
-- { x, y, height }  (tile coords, 1-based)
local PLATFORM_HEIGHT = 1.0   -- world units tall
local PLATFORMS = {
    {tx=4, ty=3}, {tx=5, ty=3},
    {tx=4, ty=4}, {tx=5, ty=4},
}
-- Build quick lookup
local platformSet = {}
for _, p in ipairs(PLATFORMS) do
    platformSet[p.tx .. "," .. p.ty] = true
end

local function isPlatform(tx, ty)
    return platformSet[tx .. "," .. ty] == true
end

local function getPlatformTopAt(wx, wy)
    -- Returns platform surface height if tile under wx,wy is a platform, else 0
    local tx = math.floor(wx + 0.5)
    local ty = math.floor(wy + 0.5)
    if isPlatform(tx, ty) then return PLATFORM_HEIGHT end
    return 0
end

-- Small debug map: 10x8, platform at tiles (5,4) and (6,4)
local MAP_DATA = {
    {4,4,4,4,4,4,4,4,4,4},
    {4,1,1,1,1,1,1,1,1,4},
    {4,1,1,1,1,1,1,1,1,4},
    {4,1,1,6,6,1,1,1,1,4},
    {4,1,1,6,6,1,1,1,1,4},
    {4,1,1,1,1,1,1,1,1,4},
    {4,1,1,1,1,1,1,1,1,4},
    {4,4,4,4,4,4,4,4,4,4},
}

local function getTile(x, y)
    if y < 1 or y > MAP_H or x < 1 or x > MAP_W then return 0 end
    return MAP_DATA[y][x] or 0
end

local function isPassable(x, y)
    -- Check a small radius around player to prevent wall face visual overlap
    local margin = 0.45
    for _, offset in ipairs({{0,0},{margin,0},{-margin,0},{0,margin},{0,-margin}}) do
        local t = getTile(math.floor(x+offset[1]+0.5), math.floor(y+offset[2]+0.5))
        if not (TILES[t] and TILES[t].passable) then return false end
    end
    return true
end

-- -------------------------
-- World objects (depth-sorted sprites)
-- -------------------------
local objects = {}

local function addObj(x, y, type, data)
    table.insert(objects, { x=x, y=y, type=type, data=data or {} })
end

local function buildObjects()
    objects = {}
    -- Just a couple of objects to test depth sorting
    addObj(3, 2, "crate",  {})
    addObj(7, 5, "barrel", {})
    addObj(6, 2, "tree",   { size=0.8 })
end

-- -------------------------
-- Player
-- -------------------------
local player = {
    x=2, y=4,       -- world position (tile units, float)
    dx=0, dy=0,     -- movement direction
    facing=0,       -- angle for drawing
    moving=false,
    animT=0,
    speed=5,
    h=0,            -- current height (0 = ground)
    vy=0,           -- vertical velocity
    onGround=true,  -- true when standing on ground or platform
    jumpPower=5.5,
    gravity=14,
}

-- -------------------------
-- Draw helpers
-- -------------------------

-- Draw a tile face in top-down mode
local function drawTileTop(tx, ty, color)
    local sx, sy = toScreenTop(tx-0.5, ty-0.5)
    love.graphics.setColor(color)
    love.graphics.rectangle("fill", sx, sy, TILE, TILE)
    love.graphics.setColor(0,0,0,0.1)
    love.graphics.rectangle("line", sx, sy, TILE, TILE)
end

-- Draw an isometric tile (diamond)
local function drawTileIso(tx, ty, color, wallColor)
    -- Four corners of the tile diamond
    local cx, cy   = toScreenIso(tx,   ty,   0)
    local lx, ly   = toScreenIso(tx-1, ty,   0)
    local rx, ry   = toScreenIso(tx,   ty-1, 0)
    local bx, by   = toScreenIso(tx-1, ty-1, 0)

    -- Top face
    love.graphics.setColor(color)
    love.graphics.polygon("fill", lx,ly, cx,cy, rx,ry, bx,by)
    love.graphics.setColor(0,0,0,0.12)
    love.graphics.polygon("line", lx,ly, cx,cy, rx,ry, bx,by)

    -- Wall face for walls (add height)
    if wallColor then
        local H2 = 0.7  -- wall height in world units
        local tlx,tly = toScreenIso(tx-1, ty,   H2)
        local tcx,tcy = toScreenIso(tx,   ty,   H2)
        local trx,try = toScreenIso(tx,   ty-1, H2)
        local tbx,tby = toScreenIso(tx-1, ty-1, H2)

        -- Left wall face
        love.graphics.setColor(wallColor[1]*0.7, wallColor[2]*0.7, wallColor[3]*0.7)
        love.graphics.polygon("fill", lx,ly, tlx,tly, tcx,tcy, cx,cy)
        -- Right wall face
        love.graphics.setColor(wallColor[1]*0.55, wallColor[2]*0.55, wallColor[3]*0.55)
        love.graphics.polygon("fill", cx,cy, tcx,tcy, trx,try, rx,ry)
    end
end

-- Draw a raised platform block at tile tx,ty
local function drawPlatformBlock(tx, ty)
    local ph = PLATFORM_HEIGHT
    local topColor   = {0.38, 0.42, 0.52}
    local leftColor  = {0.22, 0.26, 0.34}
    local rightColor = {0.18, 0.22, 0.28}

    -- 8 corners: bottom face + top face
    local bll_x, bll_y = toScreenIso(tx-1, ty,   0)
    local bcc_x, bcc_y = toScreenIso(tx,   ty,   0)
    local brr_x, brr_y = toScreenIso(tx,   ty-1, 0)
    local bbb_x, bbb_y = toScreenIso(tx-1, ty-1, 0)
    local tll_x, tll_y = toScreenIso(tx-1, ty,   ph)
    local tcc_x, tcc_y = toScreenIso(tx,   ty,   ph)
    local trr_x, trr_y = toScreenIso(tx,   ty-1, ph)
    local tbb_x, tbb_y = toScreenIso(tx-1, ty-1, ph)

    -- Left face
    love.graphics.setColor(leftColor)
    love.graphics.polygon("fill",
        bll_x,bll_y, tll_x,tll_y, tcc_x,tcc_y, bcc_x,bcc_y)
    love.graphics.setColor(0,0,0,0.15)
    love.graphics.polygon("line",
        bll_x,bll_y, tll_x,tll_y, tcc_x,tcc_y, bcc_x,bcc_y)

    -- Right face
    love.graphics.setColor(rightColor)
    love.graphics.polygon("fill",
        bcc_x,bcc_y, tcc_x,tcc_y, trr_x,trr_y, brr_x,brr_y)
    love.graphics.setColor(0,0,0,0.15)
    love.graphics.polygon("line",
        bcc_x,bcc_y, tcc_x,tcc_y, trr_x,trr_y, brr_x,brr_y)

    -- Top face
    love.graphics.setColor(topColor)
    love.graphics.polygon("fill",
        tll_x,tll_y, tcc_x,tcc_y, trr_x,trr_y, tbb_x,tbb_y)
    love.graphics.setColor(0,0,0,0.10)
    love.graphics.polygon("line",
        tll_x,tll_y, tcc_x,tcc_y, trr_x,trr_y, tbb_x,tbb_y)

    -- Edge highlight on top
    love.graphics.setColor(0.55, 0.60, 0.72, 0.5)
    love.graphics.line(tll_x,tll_y, tcc_x,tcc_y)
    love.graphics.line(tcc_x,tcc_y, trr_x,trr_y)
end

-- Draw a sprite object at world position
local function drawObject(obj, screenX, screenY)
    local t    = obj.type
    local d    = obj.data
    local sz   = TILE * (d.size or 1.0)
    local sx, sy = screenX, screenY

    if t == "tree" then
        -- Shadow
        love.graphics.setColor(0,0,0, 0.18)
        love.graphics.ellipse("fill", sx, sy + sz*0.1, sz*0.35, sz*0.12)
        -- Trunk
        love.graphics.setColor(0.35, 0.22, 0.10)
        love.graphics.rectangle("fill", sx-sz*0.07, sy-sz*0.5, sz*0.14, sz*0.5)
        -- Canopy tiers
        for i=1,3 do
            local tier = 1-(i-1)*0.25
            love.graphics.setColor(0.15*tier, 0.50*tier, 0.12*tier)
            love.graphics.polygon("fill",
                sx,          sy - sz*(0.5 + (3-i)*0.25),
                sx + sz*0.35*tier, sy - sz*(0.2 + (3-i)*0.1),
                sx - sz*0.35*tier, sy - sz*(0.2 + (3-i)*0.1))
        end

    elseif t == "crate" then
        love.graphics.setColor(0,0,0, 0.15)
        love.graphics.ellipse("fill", sx, sy+sz*0.15, sz*0.28, sz*0.10)
        -- Box faces
        local h = sz*0.45
        local hw = sz*0.28
        love.graphics.setColor(0.55, 0.40, 0.22)  -- top
        love.graphics.polygon("fill",
            sx-hw, sy-h*0.2, sx, sy-h*0.5, sx+hw, sy-h*0.2, sx, sy+h*0.1)
        love.graphics.setColor(0.42, 0.30, 0.16)  -- left face
        love.graphics.polygon("fill",
            sx-hw, sy-h*0.2, sx, sy+h*0.1, sx, sy+h*0.5, sx-hw, sy+h*0.2)
        love.graphics.setColor(0.35, 0.25, 0.13)  -- right face
        love.graphics.polygon("fill",
            sx+hw, sy-h*0.2, sx, sy+h*0.1, sx, sy+h*0.5, sx+hw, sy+h*0.2)
        -- Wood grain lines
        love.graphics.setColor(0,0,0, 0.15)
        love.graphics.line(sx-hw,sy-h*0.2, sx+hw, sy-h*0.2)

    elseif t == "barrel" then
        love.graphics.setColor(0,0,0,0.15)
        love.graphics.ellipse("fill", sx, sy+sz*0.1, sz*0.22, sz*0.08)
        local bh = sz*0.55
        love.graphics.setColor(0.38, 0.26, 0.14)
        love.graphics.ellipse("fill", sx, sy-bh*0.1, sz*0.22, sz*0.30)
        love.graphics.setColor(0.5, 0.35, 0.18)
        love.graphics.ellipse("fill", sx, sy-bh*0.5, sz*0.20, sz*0.10)
        love.graphics.setColor(0.55, 0.45, 0.25)
        for i=0,2 do
            love.graphics.ellipse("line",
                sx, sy-bh*(0.1+i*0.18), sz*0.22, sz*0.07)
        end

    elseif t == "torch" then
        -- Pole
        love.graphics.setColor(0.50, 0.38, 0.20)
        love.graphics.setLineWidth(2)
        love.graphics.line(sx, sy, sx, sy - sz*0.8)
        love.graphics.setLineWidth(1)
        -- Flame flicker
        local flicker = math.sin(time*12 + sx*0.1)*0.12 + 0.9
        love.graphics.setColor(1.0, 0.50, 0.05, 0.8)
        love.graphics.polygon("fill",
            sx, sy - sz*0.8 - sz*0.35*flicker,
            sx+sz*0.15, sy - sz*0.8,
            sx-sz*0.15, sy - sz*0.8)
        love.graphics.setColor(1.0, 0.90, 0.30, 0.9)
        love.graphics.polygon("fill",
            sx, sy - sz*0.8 - sz*0.22*flicker,
            sx+sz*0.08, sy - sz*0.8,
            sx-sz*0.08, sy - sz*0.8)

    elseif t == "pond" then
        local r = (d.r or 1) * TILE * 0.5
        -- Water shimmer
        local shimmer = math.sin(time*2)*0.05 + 0.1
        love.graphics.setColor(0.15+shimmer, 0.35+shimmer, 0.60+shimmer, 0.85)
        love.graphics.ellipse("fill", sx, sy, r, r*0.45)
        love.graphics.setColor(0.5, 0.75, 1.0, 0.4)
        love.graphics.ellipse("line", sx, sy, r*0.6, r*0.25)

    elseif t == "rock" then
        local rs = sz * (d.size or 1) * 0.3
        love.graphics.setColor(0,0,0,0.12)
        love.graphics.ellipse("fill", sx+rs*0.1, sy+rs*0.2, rs*0.9, rs*0.3)
        love.graphics.setColor(0.45, 0.43, 0.40)
        love.graphics.polygon("fill",
            sx-rs,   sy,
            sx-rs*0.3, sy-rs*0.9,
            sx+rs*0.5, sy-rs*0.7,
            sx+rs,   sy-rs*0.1)
        love.graphics.setColor(0.55, 0.53, 0.50)
        love.graphics.polygon("fill",
            sx-rs*0.3, sy-rs*0.9,
            sx+rs*0.5, sy-rs*0.7,
            sx+rs*0.3, sy-rs*0.4,
            sx-rs*0.1, sy-rs*0.5)
    end
end

-- Draw the player sprite
local function drawPlayer(sx, sy)
    local anim  = player.animT
    local bob   = player.moving and math.sin(anim*10)*2 or 0
    local legL  = player.moving and  math.sin(anim*10)*4 or 0
    local legR  = player.moving and -math.sin(anim*10)*4 or 0
    local sz    = TILE * 0.6

    -- Shadow
    love.graphics.setColor(0,0,0,0.2)
    love.graphics.ellipse("fill", sx, sy+sz*0.5, sz*0.3, sz*0.1)

    -- Legs
    love.graphics.setColor(0.25, 0.22, 0.55)
    love.graphics.rectangle("fill", sx-sz*0.15+legL*0.3, sy+sz*0.1+bob, sz*0.12, sz*0.35)
    love.graphics.rectangle("fill", sx+sz*0.03+legR*0.3, sy+sz*0.1+bob, sz*0.12, sz*0.35)

    -- Body
    love.graphics.setColor(0.30, 0.55, 0.85)
    love.graphics.rectangle("fill", sx-sz*0.22, sy-sz*0.25+bob, sz*0.44, sz*0.38, 3,3)

    -- Arms
    love.graphics.setColor(0.30, 0.55, 0.85)
    love.graphics.rectangle("fill", sx-sz*0.38+legR*0.2, sy-sz*0.18+bob, sz*0.14, sz*0.28, 2,2)
    love.graphics.rectangle("fill", sx+sz*0.24+legL*0.2, sy-sz*0.18+bob, sz*0.14, sz*0.28, 2,2)

    -- Head
    love.graphics.setColor(0.85, 0.70, 0.55)
    love.graphics.circle("fill", sx, sy-sz*0.35+bob, sz*0.22)

    -- Eyes (face direction)
    local eyeOff = sz*0.09
    love.graphics.setColor(0.1, 0.1, 0.2)
    love.graphics.circle("fill", sx-eyeOff, sy-sz*0.38+bob, sz*0.06)
    love.graphics.circle("fill", sx+eyeOff, sy-sz*0.38+bob, sz*0.06)
end

-- -------------------------
-- Enter / Exit / Update
-- -------------------------
function Example.enter()
    W = love.graphics.getWidth()
    H = love.graphics.getHeight()
    timer = Timer.new()
    time  = 0
    camX  = 5
    camY  = 4
    player.h  = 0
    player.vy = 0
    player.onGround = true
    buildObjects()
end

function Example.exit()
    Timer.clear(timer)
end

function Example.update(dt)
    Timer.update(timer, dt)
    time = time + dt

    -- Input
    local dx, dy = 0, 0
    if love.keyboard.isDown("w","up")    then dy = dy - 1 end
    if love.keyboard.isDown("s","down")  then dy = dy + 1 end
    if love.keyboard.isDown("a","left")  then dx = dx - 1 end
    if love.keyboard.isDown("d","right") then dx = dx + 1 end

    player.moving = (dx ~= 0 or dy ~= 0)

    if player.moving then
        local len  = math.sqrt(dx*dx+dy*dy)
        local nx   = player.x + (dx/len) * player.speed * dt
        local ny   = player.y + (dy/len) * player.speed * dt

        -- Horizontal collision: blocked by wall OR by platform side (if not high enough)
        local function canMoveTo(wx, wy)
            if not isPassable(wx, wy) then return false end
            -- If target is a platform tile and player is not on top of it, block
            if isPlatform(math.floor(wx+0.5), math.floor(wy+0.5)) then
                return player.h >= PLATFORM_HEIGHT - 0.05
            end
            return true
        end

        if canMoveTo(nx, player.y) then player.x = nx end
        if canMoveTo(player.x, ny) then player.y = ny end
        player.animT = player.animT + dt
        if dx ~= 0 or dy ~= 0 then
            player.facing = math.atan2(dy, dx)
        end
    end

    -- Vertical physics (gravity + jump)
    local floorH = getPlatformTopAt(player.x, player.y)  -- 0 or PLATFORM_HEIGHT
    player.vy    = player.vy - player.gravity * dt
    player.h     = player.h + player.vy * dt

    if player.h <= floorH then
        -- Landed
        player.h        = floorH
        player.vy       = 0
        player.onGround = true
    else
        player.onGround = false
    end

    -- If player walks off platform edge, start falling
    if player.onGround and player.h > 0 and floorH == 0 then
        player.onGround = false
        -- small nudge so gravity takes over
    end

    -- Smooth camera follow, clamped to map edges so player never leaves screen
    local halfW = (W/2) / TILE
    local halfH = (H/2) / TILE
    local targetCX = Utils.clamp(player.x, 1 + halfW, MAP_W - halfW)
    local targetCY = Utils.clamp(player.y, 1 + halfH, MAP_H - halfH)
    camX = Utils.lerp(camX, targetCX, 8*dt)
    camY = Utils.lerp(camY, targetCY, 8*dt)
end

-- -------------------------
-- Draw
-- -------------------------
function Example.draw()
    -- Background
    love.graphics.setColor(0.06, 0.07, 0.10)
    love.graphics.rectangle("fill", 0, 0, W, H)

    if MODE == "top" then
        -- Top-down: draw tiles row by row
        for ty = 1, MAP_H do
            for tx = 1, MAP_W do
                local tile = getTile(tx, ty)
                local def  = TILES[tile]
                if def then
                    drawTileTop(tx, ty, def.color)
                end
            end
        end

        -- Sort objects + player by Y for depth
        local drawList = {}
        for _, obj in ipairs(objects) do
            local sx, sy = toScreen(obj.x, obj.y)
            table.insert(drawList, { sx=sx, sy=sy, depth=obj.y, obj=obj })
        end
        -- Player
        local psx, psy = toScreen(player.x, player.y, player.h)
        table.insert(drawList, { sx=psx, sy=psy, depth=player.y, isPlayer=true })

        table.sort(drawList, function(a,b) return a.depth < b.depth end)
        for _, item in ipairs(drawList) do
            if item.isPlayer then
                drawPlayer(item.sx, item.sy)
            else
                drawObject(item.obj, item.sx, item.sy)
            end
        end

    else
        -- Isometric: collect ALL draw calls into one flat list, sort by depth
        local drawList = {}

        -- Tiles: depth = tx+ty (integer)
        for ty = 1, MAP_H do
            for tx = 1, MAP_W do
                local tile = getTile(tx, ty)
                local def  = TILES[tile]
                if def then
                    table.insert(drawList, {
                        depth = tx + ty,
                        kind  = "tile",
                        tx=tx, ty=ty, tile=tile, def=def,
                    })
                end
            end
        end

        -- Objects: +0.5 so they draw after tiles at same depth
        for _, obj in ipairs(objects) do
            local sx, sy = toScreen(obj.x, obj.y)
            table.insert(drawList, {
                depth = obj.x + obj.y + 0.5,
                kind  = "obj",
                sx=sx, sy=sy, obj=obj,
            })
        end

        -- Player depth: floor(x)+floor(y)+0.99 puts player just before
        -- the NEXT row of tiles (depth 19) while still after their own tile (18).
        -- Tiles at depth 19+ are visually ahead — they correctly occlude the player
        -- only when the player has moved into their zone.
        local psx, psy = toScreen(player.x, player.y, player.h)
        local ptx = math.floor(player.x + 0.5)   -- round = same as getTile
        local pty = math.floor(player.y + 0.5)
        local snapDepth = ptx + pty + 0.5         -- after own tile, before next row
        table.insert(drawList, {
            depth = snapDepth,
            kind  = "player",
            sx=psx, sy=psy,
        })

        -- Sort back to front; tiles before sprites at equal depth
        table.sort(drawList, function(a, b)
            if math.abs(a.depth - b.depth) > 0.01 then
                return a.depth < b.depth
            end
            return (a.kind == "tile") and (b.kind ~= "tile")
        end)

        -- Single draw pass
        for _, item in ipairs(drawList) do
            if item.kind == "tile" then
                local isWall      = (item.tile == 4)
                local isPlatformT = (item.tile == 6)
                if isPlatformT then
                    drawPlatformBlock(item.tx, item.ty)
                else
                    drawTileIso(item.tx, item.ty, item.def.color,
                        isWall and {item.def.color[1], item.def.color[2], item.def.color[3]} or nil)
                end
            elseif item.kind == "obj" then
                drawObject(item.obj, item.sx, item.sy)
            elseif item.kind == "player" then
                drawPlayer(item.sx, item.sy)
            end
        end
    end

    -- DEBUG overlay: show depth value on every tile and the player
    if DEBUG and MODE == "iso" then
        for ty = 1, MAP_H do
            for tx = 1, MAP_W do
                local tile = getTile(tx, ty)
                if tile ~= 0 then
                    local sx, sy = toScreenIso(tx-0.5, ty-0.5, 0)
                    local depth  = tx + ty
                    -- Color by tile type
                    if tile == 6 then
                        love.graphics.setColor(1, 0.8, 0, 0.9)
                    else
                        love.graphics.setColor(0.5, 0.8, 1.0, 0.7)
                    end
                    love.graphics.printf(tostring(depth), sx-20, sy-8, 40, "center")
                end
            end
        end
        -- Player depth
        local psx, psy = toScreen(player.x, player.y, player.h)
        local ptxd = math.floor(player.x + 0.5)
        local ptyd = math.floor(player.y + 0.5)
        local pd   = ptxd + ptyd + 0.5   -- ACTUAL sort depth
        love.graphics.setColor(0, 1, 0, 1)
        love.graphics.circle("line", psx, psy, 16)
        love.graphics.setColor(0, 1, 0, 1)
        love.graphics.printf(string.format("%.1f", pd), psx-25, psy-22, 50, "center")
        -- Arrow showing player screen pos
        love.graphics.line(psx, psy-16, psx, psy-24)
    end

    -- HUD
    love.graphics.setColor(0.06, 0.08, 0.14, 0.92)
    love.graphics.rectangle("fill", W-190, 30, 180, 115, 6,6)
    love.graphics.setColor(0.35, 0.50, 0.80)
    love.graphics.rectangle("line", W-190, 30, 180, 115, 6,6)
    love.graphics.setColor(0.5, 0.7, 1.0)
    love.graphics.printf("ISO / TOP-DOWN", W-190, 38, 180, "center")
    love.graphics.setColor(0.75, 0.80, 0.90)
    local ptx = math.floor(player.x+0.5)
    local pty = math.floor(player.y+0.5)
    local pd  = ptx + pty + 0.5   -- matches actual drawList sort depth
    love.graphics.print(string.format(
        "Mode:  %s\nPos:   %.2f, %.2f\nH:     %.2f %s\nTile:  %d,%d (d=%d)\nP.dep: %.2f",
        MODE == "iso" and "Iso" or "Top",
        player.x, player.y,
        player.h, player.onGround and "(gnd)" or "(air)",
        ptx, pty, ptx+pty,
        pd),
        W-178, 56)

    Utils.drawHUD("ISO / TOP-DOWN",
        "WASD move    SPACE jump    TAB iso/top    G debug    +/- zoom    ESC back")
end

function Example.keypressed(key)
    if key == "tab" then
        MODE = MODE == "iso" and "top" or "iso"
    elseif key == "f1" or key == "g" then
        DEBUG = not DEBUG
    elseif key == "space" then
        if player.onGround then
            player.vy = player.jumpPower
            player.onGround = false
        end
    elseif key == "=" or key == "+" then
        TILE = math.min(TILE_MAX, TILE + 8)
    elseif key == "-" then
        TILE = math.max(TILE_MIN, TILE - 8)
    end
    Utils.handlePause(key, Example)
end

function Example.wheelmoved(x, y)
    TILE = math.max(TILE_MIN, math.min(TILE_MAX, TILE + y * 6))
end

return Example
