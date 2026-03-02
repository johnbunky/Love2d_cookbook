-- src/states/examples/billboards.lua
-- Demonstrates: billboards in a 3D world — sprites that always face the camera
-- Doom-style depth-sorted sprites, axis-aligned and spherical billboards

local Utils = require("src.utils")
local Vec3  = require("src.systems.vec3")
local Mat4  = require("src.systems.mat4")
local Timer = require("src.systems.timer")
local Example = {}

local W, H
local timer
local time = 0

-- -------------------------
-- Camera (same as basics_3d)
-- -------------------------
local cam = {
    pos   = Vec3.new(0, 1.6, 8),
    yaw   = 0,
    pitch = -0.05,
    fov   = math.pi / 3,
    near  = 0.1,
    far   = 80,
}

-- -------------------------
-- Get view-projection matrix
-- -------------------------
local function getVP()
    local aspect = W / H
    local proj   = Mat4.perspective(cam.fov, aspect, cam.near, cam.far)
    local dir    = Vec3.new(
        math.cos(cam.pitch)*math.sin(cam.yaw),
        math.sin(cam.pitch),
       -math.cos(cam.pitch)*math.cos(cam.yaw))
    local at     = Vec3.add(cam.pos, dir)
    local view   = Mat4.lookAt(
        cam.pos.x, cam.pos.y, cam.pos.z,
        at.x, at.y, at.z)
    return Mat4.mul(proj, view)
end

-- -------------------------
-- Project a world point to screen
-- Returns sx, sy, depth  or nil
-- -------------------------
local function project(vp, x, y, z)
    return Mat4.project(vp, x, y, z, W, H)
end

-- -------------------------
-- Billboard types
-- -------------------------
local TYPES = {
    { name="tree",   color={0.25,0.65,0.20}, shape="tree",   scale=1.8, shadow=true  },
    { name="lamp",   color={0.75,0.75,0.55}, shape="lamp",   scale=1.2, shadow=true  },
    { name="barrel", color={0.45,0.32,0.18}, shape="barrel", scale=0.7, shadow=true  },
    { name="ghost",  color={0.70,0.85,1.00}, shape="ghost",  scale=1.0, shadow=false },
    { name="fire",   color={1.00,0.55,0.10}, shape="fire",   scale=0.6, shadow=false },
}

-- -------------------------
-- Draw a billboard sprite at screen position
-- screenR = radius in pixels
-- -------------------------
local function drawBillboardSprite(shape, sx, sy, screenR, r, g, b, alpha, t)
    alpha = alpha or 1
    if shape == "tree" then
        -- Trunk
        love.graphics.setColor(0.35*r, 0.22*g, 0.10*b, alpha)
        love.graphics.rectangle("fill",
            sx - screenR*0.12, sy,
            screenR*0.24, screenR*0.5)
        -- Three triangle tiers
        for i = 1, 3 do
            local tier = 1 - (i-1)*0.28
            local tw   = screenR * tier
            local ty   = sy - screenR*(0.3 + (i-1)*0.4)
            love.graphics.setColor(r*0.5*tier, g*tier, b*0.3*tier, alpha)
            love.graphics.polygon("fill",
                sx,       ty - screenR*0.45,
                sx + tw,  ty + screenR*0.1,
                sx - tw,  ty + screenR*0.1)
        end

    elseif shape == "lamp" then
        -- Pole
        love.graphics.setColor(r*0.6, g*0.6, b*0.5, alpha)
        love.graphics.setLineWidth(math.max(1, screenR*0.08))
        love.graphics.line(sx, sy, sx, sy - screenR*1.6)
        love.graphics.setLineWidth(1)
        -- Arm
        love.graphics.line(sx, sy - screenR*1.5, sx + screenR*0.5, sy - screenR*1.5)
        -- Bulb glow
        love.graphics.setColor(1.0, 0.95, 0.6, alpha*0.4)
        love.graphics.circle("fill", sx + screenR*0.5, sy - screenR*1.5, screenR*0.35)
        love.graphics.setColor(1.0, 1.0, 0.8, alpha)
        love.graphics.circle("fill", sx + screenR*0.5, sy - screenR*1.5, screenR*0.15)

    elseif shape == "barrel" then
        -- Body
        love.graphics.setColor(r, g, b, alpha)
        love.graphics.ellipse("fill", sx, sy - screenR*0.5, screenR*0.45, screenR*0.6)
        -- Bands
        love.graphics.setColor(r*0.5, g*0.4, b*0.3, alpha)
        for i = 0, 2 do
            local bY = sy - screenR*0.15 - i*screenR*0.28
            love.graphics.setLineWidth(math.max(1, screenR*0.07))
            love.graphics.line(sx - screenR*0.42, bY, sx + screenR*0.42, bY)
        end
        love.graphics.setLineWidth(1)

    elseif shape == "ghost" then
        -- Animated bob
        local bob = math.sin(t * 2 + sx * 0.01) * screenR * 0.12
        local gy  = sy + bob
        -- Body
        love.graphics.setColor(r, g, b, alpha * (0.7 + math.sin(t*3)*0.15))
        love.graphics.ellipse("fill", sx, gy - screenR*0.5, screenR*0.5, screenR*0.65)
        -- Wavy bottom
        local segs = 5
        local pts  = {}
        for i = 0, segs do
            local fx = sx - screenR*0.5 + i*(screenR/segs)
            local fy = gy + (i%2==0 and screenR*0.15 or 0)
            table.insert(pts, fx); table.insert(pts, fy)
        end
        table.insert(pts, sx + screenR*0.5); table.insert(pts, gy - screenR*0.5)
        table.insert(pts, sx - screenR*0.5); table.insert(pts, gy - screenR*0.5)
        love.graphics.polygon("fill", pts)
        -- Eyes
        love.graphics.setColor(0.1, 0.1, 0.2, alpha)
        love.graphics.circle("fill", sx - screenR*0.15, gy - screenR*0.55, screenR*0.1)
        love.graphics.circle("fill", sx + screenR*0.15, gy - screenR*0.55, screenR*0.1)

    elseif shape == "fire" then
        -- Animated flicker
        local flicker = math.sin(t * 12 + sx) * 0.2 + 0.9
        local fw      = screenR * 0.55 * flicker
        -- Outer flame
        love.graphics.setColor(r, g*0.3, 0, alpha * 0.7)
        love.graphics.polygon("fill",
            sx,      sy - screenR*1.4*flicker,
            sx + fw, sy,
            sx - fw, sy)
        -- Inner flame
        love.graphics.setColor(1.0, 0.85, 0.1, alpha * 0.9)
        love.graphics.polygon("fill",
            sx,           sy - screenR*0.9*flicker,
            sx + fw*0.5,  sy,
            sx - fw*0.5,  sy)
        -- Core
        love.graphics.setColor(1, 1, 0.8, alpha)
        love.graphics.circle("fill", sx, sy - screenR*0.1, screenR*0.2)
    end
end

-- -------------------------
-- World objects
-- -------------------------
local objects = {}

local function buildWorld()
    objects = {}
    math.randomseed(55)

    -- Ring of trees
    for i = 1, 12 do
        local angle = (i-1) / 12 * math.pi * 2
        local dist  = math.random(5, 9)
        table.insert(objects, {
            type  = "tree",
            x     = math.cos(angle) * dist,
            y     = 0,
            z     = math.sin(angle) * dist,
            scale = math.random(80,130)/100,
        })
    end
    -- Lamps along a path
    for i = -3, 3 do
        table.insert(objects, {
            type="lamp", x=i*2.5, y=0, z=-2, scale=1.0 })
        table.insert(objects, {
            type="lamp", x=i*2.5, y=0, z= 2, scale=1.0 })
    end
    -- Barrels scattered
    for _ = 1, 8 do
        table.insert(objects, {
            type  = "barrel",
            x     = math.random(-6,6),
            y     = 0,
            z     = math.random(-6,6),
            scale = math.random(80,110)/100,
        })
    end
    -- Ghosts roaming
    for i = 1, 4 do
        local angle = (i-1)/4 * math.pi * 2
        table.insert(objects, {
            type   = "ghost",
            x      = math.cos(angle)*3,
            y      = 0.5,
            z      = math.sin(angle)*3,
            scale  = 1.0,
            orbit  = angle,
            speed  = 0.4 + math.random()*0.3,
        })
    end
    -- Fires at corners
    for _, pos in ipairs({{-4,0,-4},{4,0,-4},{-4,0,4},{4,0,4}}) do
        table.insert(objects, {
            type="fire", x=pos[1], y=0, z=pos[3], scale=1.0 })
    end
end

-- -------------------------
-- Draw flat floor grid
-- -------------------------
local function drawFloor(vp)
    local SIZE = 10
    -- Floor quads
    for z = -SIZE, SIZE-1 do
        for x = -SIZE, SIZE-1 do
            local ax, ay = project(vp, x,   0, z)
            local bx, by = project(vp, x+1, 0, z)
            local cx, cy = project(vp, x+1, 0, z+1)
            local dx, dy = project(vp, x,   0, z+1)
            if ax and bx and cx and dx then
                local checker = ((x+z) % 2 == 0)
                love.graphics.setColor(
                    checker and 0.18 or 0.14,
                    checker and 0.20 or 0.16,
                    checker and 0.16 or 0.12)
                love.graphics.polygon("fill", ax,ay, bx,by, cx,cy, dx,dy)
            end
        end
    end
    -- Grid lines
    love.graphics.setColor(0.10, 0.12, 0.10, 0.5)
    for i = -SIZE, SIZE do
        local ax, ay = project(vp, i,    0, -SIZE)
        local bx, by = project(vp, i,    0,  SIZE)
        local cx, cy = project(vp, -SIZE,0,  i)
        local dx, dy = project(vp,  SIZE,0,  i)
        if ax and bx then love.graphics.line(ax,ay,bx,by) end
        if cx and dx then love.graphics.line(cx,cy,dx,dy) end
    end
end

-- -------------------------
-- Draw sky gradient
-- -------------------------
local function drawSky()
    love.graphics.setColor(0.10, 0.14, 0.28)
    love.graphics.rectangle("fill", 0, 0, W, H*0.6)
    -- Horizon
    for i = 1, 8 do
        local t = i/8
        love.graphics.setColor(0.15+t*0.05, 0.16+t*0.06, 0.12+t*0.05)
        love.graphics.rectangle("fill", 0, H*0.6 - i*4, W, 5)
    end
    -- Stars
    love.graphics.setColor(1, 1, 1, 0.5)
    math.randomseed(7)
    for _ = 1, 80 do
        love.graphics.circle("fill",
            math.random(0,W), math.random(0, H*0.5), math.random()*1.2+0.3)
    end
    -- Moon
    love.graphics.setColor(0.92, 0.90, 0.80)
    love.graphics.circle("fill", W*0.8, H*0.15, 22)
    love.graphics.setColor(0.10, 0.14, 0.28)
    love.graphics.circle("fill", W*0.8+10, H*0.15-4, 18)
end

-- -------------------------
-- Enter / Exit / Update
-- -------------------------
function Example.enter()
    W = love.graphics.getWidth()
    H = love.graphics.getHeight()
    timer = Timer.new()
    time  = 0
    cam.pos   = Vec3.new(0, 1.6, 8)
    cam.yaw   = 0
    cam.pitch = -0.05
    buildWorld()
end

function Example.exit()
    Timer.clear(timer)
end

local showMode = "solid"  -- "solid" | "wire"

function Example.update(dt)
    Timer.update(timer, dt)
    time = time + dt

    -- Animate ghosts orbiting
    for _, obj in ipairs(objects) do
        if obj.type == "ghost" and obj.orbit then
            obj.orbit = obj.orbit + dt * obj.speed
            obj.x = math.cos(obj.orbit) * 3
            obj.z = math.sin(obj.orbit) * 3
        end
    end

    -- Camera move
    local speed = 5 * dt
    local fwd   = Vec3.new(
        math.cos(cam.pitch)*math.sin(cam.yaw),
        math.sin(cam.pitch),
       -math.cos(cam.pitch)*math.cos(cam.yaw))
    local right = Vec3.normalize(Vec3.cross(fwd, Vec3.up()))
    if love.keyboard.isDown("w","up")    then cam.pos = Vec3.addScale(cam.pos, fwd,   speed) end
    if love.keyboard.isDown("s","down")  then cam.pos = Vec3.addScale(cam.pos, fwd,  -speed) end
    if love.keyboard.isDown("a","left")  then cam.pos = Vec3.addScale(cam.pos, right,-speed) end
    if love.keyboard.isDown("d","right") then cam.pos = Vec3.addScale(cam.pos, right, speed) end

    -- Mouse look
    if love.mouse.isDown(1) then
        local mx, my = love.mouse.getPosition()
        if Example._lmx then
            cam.yaw   = cam.yaw   - (mx - Example._lmx)*0.005
            cam.pitch = Utils.clamp(
                cam.pitch - (my - Example._lmy)*0.005, -0.8, 0.8)
        end
        Example._lmx, Example._lmy = mx, my
    else
        Example._lmx = nil
    end
end

-- -------------------------
-- Draw
-- -------------------------
function Example.draw()
    drawSky()

    local vp = getVP()
    drawFloor(vp)

    -- Collect visible billboards with depth for sorting
    local visible = {}
    for _, obj in ipairs(objects) do
        local def = nil
        for _, t in ipairs(TYPES) do
            if t.name == obj.type then def = t; break end
        end
        if def then
            local sx, sy, depth = project(vp, obj.x, obj.y, obj.z)
            if sx and depth > 0 and depth < cam.far then
                -- Compute screen size from world scale + perspective
                local dist = Vec3.dist(cam.pos, Vec3.new(obj.x, obj.y, obj.z))
                local screenR = math.max(4,
                    (def.scale * (obj.scale or 1)) / dist *
                    (H / (2 * math.tan(cam.fov * 0.5))))
                table.insert(visible, {
                    obj=obj, def=def,
                    sx=sx, sy=sy,
                    depth=depth, dist=dist,
                    screenR=screenR,
                })
            end
        end
    end

    -- Sort back to front (painter's algorithm)
    table.sort(visible, function(a, b) return a.depth > b.depth end)

    -- Draw each billboard
    for _, v in ipairs(visible) do
        local obj, def = v.obj, v.def
        local sx, sy, sr = v.sx, v.sy, v.screenR

        -- Ground shadow (axis-aligned ellipse on floor)
        if def.shadow then
            local gx, gy = project(vp, obj.x, 0, obj.z)
            if gx then
                local alpha = math.max(0, 1 - v.dist * 0.08) * 0.5
                love.graphics.setColor(0, 0, 0, alpha)
                love.graphics.ellipse("fill", gx, gy, sr*0.6, sr*0.15)
            end
        end

        -- Sprite
        local alpha = math.max(0.2, 1 - v.dist * 0.05)
        drawBillboardSprite(def.shape, sx, sy,
            sr, def.color[1], def.color[2], def.color[3], alpha, time)

        -- Debug: show billboard axis in wire mode
        if showMode == "wire" then
            love.graphics.setColor(0.4, 0.8, 1.0, 0.5)
            love.graphics.rectangle("line",
                sx - sr*0.5, sy - sr*1.5, sr, sr*1.5)
            love.graphics.setColor(1, 0.5, 0.2, 0.8)
            love.graphics.circle("line", sx, sy, 3)
        end
    end

    -- HUD panel
    love.graphics.setColor(0.06, 0.08, 0.14, 0.92)
    love.graphics.rectangle("fill", W-200, 30, 190, 110, 6,6)
    love.graphics.setColor(0.35, 0.50, 0.80)
    love.graphics.rectangle("line", W-200, 30, 190, 110, 6,6)
    love.graphics.setColor(0.5, 0.7, 1.0)
    love.graphics.printf("BILLBOARDS", W-200, 38, 190, "center")
    love.graphics.setColor(0.7, 0.75, 0.85)
    love.graphics.print(string.format(
        "Objects: %d\nVisible: %d\nMode:    %s\nCam Z:   %.1f",
        #objects, #visible, showMode, cam.pos.z),
        W-188, 58)

    -- Sprite legend
    local lx = 12
    love.graphics.setColor(0.06, 0.08, 0.14, 0.85)
    love.graphics.rectangle("fill", lx-4, H-120, 110, 112, 6,6)
    love.graphics.setColor(0.35, 0.50, 0.80)
    love.graphics.rectangle("line", lx-4, H-120, 110, 112, 6,6)
    love.graphics.setColor(0.5, 0.7, 1.0)
    love.graphics.print("Sprites:", lx, H-116)
    for i, def in ipairs(TYPES) do
        love.graphics.setColor(def.color[1], def.color[2], def.color[3])
        love.graphics.circle("fill", lx+6, H-96+(i-1)*18, 5)
        love.graphics.setColor(0.75, 0.80, 0.90)
        love.graphics.print(def.name, lx+16, H-102+(i-1)*18)
    end

    Utils.drawHUD("BILLBOARDS",
        "WASD move    drag look    TAB wire mode    R reset    ESC back")
end

function Example.keypressed(key)
    if key == "tab" then
        showMode = showMode == "solid" and "wire" or "solid"
    elseif key == "r" then
        Example.enter()
    end
    Utils.handlePause(key, Example)
end

return Example
