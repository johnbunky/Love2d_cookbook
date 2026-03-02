-- src/states/examples/basics_3d.lua
-- Demonstrates: Vec3, Mat4, perspective projection, wireframe cube, terrain

local Utils = require("src.utils")
local Vec3  = require("src.systems.vec3")
local Mat4  = require("src.systems.mat4")
local Timer = require("src.systems.timer")
local Example = {}

local W, H
local timer
local time = 0

-- -------------------------
-- Camera
-- -------------------------
local cam = {
    pos   = Vec3.new(0, 2, 6),
    yaw   = 0,
    pitch = -0.25,
    fov   = math.pi / 3,
    near  = 0.1,
    far   = 100,
}

-- -------------------------
-- Scenes
-- -------------------------
local scenes = { "Cube", "Cubes", "Terrain", "Solar System" }
local selectedScene = 1

-- -------------------------
-- Cube geometry
-- -------------------------
local CUBE_VERTS = {
    Vec3.new(-1,-1,-1), Vec3.new( 1,-1,-1),
    Vec3.new( 1, 1,-1), Vec3.new(-1, 1,-1),
    Vec3.new(-1,-1, 1), Vec3.new( 1,-1, 1),
    Vec3.new( 1, 1, 1), Vec3.new(-1, 1, 1),
}
local CUBE_EDGES = {
    {1,2},{2,3},{3,4},{4,1},  -- back face
    {5,6},{6,7},{7,8},{8,5},  -- front face
    {1,5},{2,6},{3,7},{4,8},  -- connecting
}
local CUBE_FACES = {
    { verts={1,2,3,4}, normal=Vec3.new( 0, 0,-1), color={0.9,0.3,0.3} },
    { verts={5,6,7,8}, normal=Vec3.new( 0, 0, 1), color={0.3,0.9,0.3} },
    { verts={1,4,8,5}, normal=Vec3.new(-1, 0, 0), color={0.3,0.3,0.9} },
    { verts={2,3,7,6}, normal=Vec3.new( 1, 0, 0), color={0.9,0.9,0.3} },
    { verts={4,3,7,8}, normal=Vec3.new( 0, 1, 0), color={0.9,0.5,0.2} },
    { verts={1,2,6,5}, normal=Vec3.new( 0,-1, 0), color={0.6,0.3,0.9} },
}

-- -------------------------
-- Project helpers
-- -------------------------
local function getViewProj()
    local aspect = W / H
    local proj   = Mat4.perspective(cam.fov, aspect, cam.near, cam.far)
    local dir    = Vec3.new(
        math.cos(cam.pitch)*math.sin(cam.yaw),
        math.sin(cam.pitch),
       -math.cos(cam.pitch)*math.cos(cam.yaw))  -- negative Z = look into scene at yaw=0
    local at     = Vec3.add(cam.pos, dir)
    local view   = Mat4.lookAt(
        cam.pos.x, cam.pos.y, cam.pos.z,
        at.x, at.y, at.z)
    return Mat4.mul(proj, view)
end

local function project(vp, model, v)
    local mv = Mat4.mul(vp, model)
    local sx, sy, depth = Mat4.project(mv, v.x, v.y, v.z, W, H)
    if not sx then return nil end
    return sx, sy, depth
end

-- -------------------------
-- Draw a cube with model matrix
-- -------------------------
local function drawCube(vp, model, wireframe, alpha)
    alpha = alpha or 1

    if not wireframe then
        -- Collect faces with depth
        local light = Vec3.normalize(Vec3.new(0.6, 1.0, 0.8))
        local facesDrawn = {}

        for _, face in ipairs(CUBE_FACES) do
            -- Transform normal
            local fn  = face.normal
            -- Simple dot lighting (world space normal approximation)
            local dot = math.max(0.15, Vec3.dot(fn, light))

            -- Get projected center for depth sorting
            local cx, cy, cz = 0, 0, 0
            local pts = {}
            local visible = true
            for _, vi in ipairs(face.verts) do
                local v = CUBE_VERTS[vi]
                local sx, sy, depth = project(vp, model, v)
                if not sx then visible = false; break end
                table.insert(pts, {sx, sy})
                cz = cz + depth
            end
            if visible then
                table.insert(facesDrawn, {
                    pts   = pts,
                    color = face.color,
                    dot   = dot,
                    depth = cz / #face.verts,
                })
            end
        end

        -- Sort back to front
        table.sort(facesDrawn, function(a,b) return a.depth > b.depth end)

        for _, fd in ipairs(facesDrawn) do
            local verts = {}
            for _, pt in ipairs(fd.pts) do
                table.insert(verts, pt[1])
                table.insert(verts, pt[2])
            end
            love.graphics.setColor(
                fd.color[1]*fd.dot,
                fd.color[2]*fd.dot,
                fd.color[3]*fd.dot,
                alpha)
            love.graphics.polygon("fill", verts)
            -- Edge outline
            love.graphics.setColor(0,0,0, alpha*0.3)
            love.graphics.polygon("line", verts)
        end
    else
        -- Wireframe
        for _, edge in ipairs(CUBE_EDGES) do
            local a = CUBE_VERTS[edge[1]]
            local b = CUBE_VERTS[edge[2]]
            local ax, ay = project(vp, model, a)
            local bx, by = project(vp, model, b)
            if ax and bx then
                love.graphics.setColor(0.4, 0.8, 1.0, alpha)
                love.graphics.line(ax, ay, bx, by)
            end
        end
    end
end

-- -------------------------
-- Terrain heightmap
-- -------------------------
local terrain = {}
local TSIZE   = 16
local function buildTerrain()
    terrain = {}
    for z = 0, TSIZE do
        terrain[z] = {}
        for x = 0, TSIZE do
            local h =
                math.sin(x * 0.5) * 0.6 +
                math.cos(z * 0.4) * 0.5 +
                math.sin(x * 0.9 + z * 0.7) * 0.3
            terrain[z][x] = h
        end
    end
end

local function drawTerrain(vp)
    local model = Mat4.identity()
    for z = 0, TSIZE-1 do
        for x = 0, TSIZE-1 do
            local cx = x - TSIZE/2
            local cz = z - TSIZE/2
            local h00 = terrain[z][x]
            local h10 = terrain[z][x+1]
            local h01 = terrain[z+1][x]
            local h11 = terrain[z+1][x+1]

            local v00 = Vec3.new(cx,     h00, cz)
            local v10 = Vec3.new(cx+1,   h10, cz)
            local v01 = Vec3.new(cx,     h01, cz+1)
            local v11 = Vec3.new(cx+1,   h11, cz+1)

            local ax, ay, ad = project(vp, model, v00)
            local bx, by, bd = project(vp, model, v10)
            local cx2,cy2,cd = project(vp, model, v11)
            local dx, dy, dd = project(vp, model, v01)

            if ax and bx and cx2 and dx then
                local avgH = (h00+h10+h01+h11)*0.25
                local t    = (avgH + 1) * 0.5
                local depth= (ad+bd+cd+dd)*0.25
                -- Color from height
                local r = Utils.lerp(0.2, 0.8, t)
                local g = Utils.lerp(0.5, 0.9, t)
                local b = Utils.lerp(0.2, 0.3, t)

                love.graphics.setColor(r, g, b)
                love.graphics.polygon("fill", ax,ay, bx,by, cx2,cy2, dx,dy)
                love.graphics.setColor(0,0,0,0.2)
                love.graphics.polygon("line", ax,ay, bx,by, cx2,cy2, dx,dy)
            end
        end
    end
end

-- -------------------------
-- Solar system
-- -------------------------
local solar = {
    { name="Sun",     r=0.8,  dist=0,   speed=0,    color={1.0,0.85,0.1}, moons={} },
    { name="Mercury", r=0.15, dist=2.0, speed=2.4,  color={0.7,0.6,0.5},  moons={} },
    { name="Venus",   r=0.28, dist=3.2, speed=1.8,  color={0.9,0.75,0.4}, moons={} },
    { name="Earth",   r=0.30, dist=4.5, speed=1.2,  color={0.3,0.6,0.9},
        moons={ {r=0.08, dist=0.7, speed=5.0, color={0.8,0.8,0.75}} } },
    { name="Mars",    r=0.22, dist=6.0, speed=0.8,  color={0.85,0.4,0.2},
        moons={ {r=0.05, dist=0.5, speed=8.0, color={0.7,0.65,0.6}} } },
}

local function drawSphere(vp, cx, cy, cz, radius, cr, cg, cb)
    local model = Mat4.translate(cx, cy, cz)
    -- Draw as icosahedron approximation using circles
    local sx, sy, depth = Mat4.project(
        Mat4.mul(Mat4.perspective(cam.fov, W/H, cam.near, cam.far),
        Mat4.lookAt(cam.pos.x,cam.pos.y,cam.pos.z,
            cam.pos.x+math.cos(cam.pitch)*math.sin(cam.yaw),
            cam.pos.y+math.sin(cam.pitch),
            cam.pos.z-math.cos(cam.pitch)*math.cos(cam.yaw))),
        cx, cy, cz, W, H)
    if not sx then return end

    -- Approximate screen radius via perspective division
    local dist = Vec3.dist(cam.pos, Vec3.new(cx,cy,cz))
    local screenR = (radius / dist) * (H / (2 * math.tan(cam.fov*0.5)))
    if screenR < 1 then return end

    -- Shade
    local light = Vec3.normalize(Vec3.new(1, 1, 0.5))
    local toL   = Vec3.normalize(Vec3.sub(Vec3.new(cx,cy,cz), cam.pos))
    local dot   = math.max(0.2, -Vec3.dot(toL, light) + 0.6)

    love.graphics.setColor(cr*dot, cg*dot, cb*dot)
    love.graphics.circle("fill", sx, sy, screenR)
    love.graphics.setColor(0,0,0,0.3)
    love.graphics.circle("line", sx, sy, screenR)
end

local function drawSolarSystem(vp)
    for _, planet in ipairs(solar) do
        local px = planet.dist * math.cos(time * planet.speed)
        local pz = planet.dist * math.sin(time * planet.speed)
        -- Orbit ring
        if planet.dist > 0 then
            love.graphics.setColor(0.25, 0.3, 0.45, 0.4)
            -- Project orbit as ellipse approximation
        end
        drawSphere(vp, px, 0, pz, planet.r,
            planet.color[1], planet.color[2], planet.color[3])
        -- Moons
        for _, moon in ipairs(planet.moons or {}) do
            local mx = px + moon.dist * math.cos(time * moon.speed)
            local mz = pz + moon.dist * math.sin(time * moon.speed)
            drawSphere(vp, mx, 0, mz, moon.r,
                moon.color[1], moon.color[2], moon.color[3])
        end
    end
end

-- -------------------------
-- State
-- -------------------------
local cubeRot = { x=0, y=0, z=0 }
local autoRotate = true

function Example.enter()
    W = love.graphics.getWidth()
    H = love.graphics.getHeight()
    timer = Timer.new()
    time  = 0
    buildTerrain()
    cam.pos   = Vec3.new(0, 2, 6)
    cam.yaw   = 0
    cam.pitch = -0.2
    cubeRot   = { x=0.3, y=0.5, z=0.1 }
end

function Example.exit()
    Timer.clear(timer)
end

function Example.update(dt)
    Timer.update(timer, dt)
    time = time + dt

    -- Camera look with mouse drag
    if love.mouse.isDown(1) then
        local mx, my = love.mouse.getPosition()
        if Example._lmx then
            cam.yaw   = cam.yaw   - (mx - Example._lmx) * 0.005
            cam.pitch = Utils.clamp(cam.pitch - (my - Example._lmy)*0.005, -1.4, 1.4)
        end
        Example._lmx, Example._lmy = mx, my
    else
        Example._lmx = nil
    end

    -- Camera move
    local speed = 4 * dt
    local fwd   = Vec3.new(
        math.cos(cam.pitch)*math.sin(cam.yaw),
        math.sin(cam.pitch),
       -math.cos(cam.pitch)*math.cos(cam.yaw))
    local right = Vec3.normalize(Vec3.cross(fwd, Vec3.up()))

    if love.keyboard.isDown("w","up")    then cam.pos = Vec3.addScale(cam.pos, fwd,   speed) end
    if love.keyboard.isDown("s","down")  then cam.pos = Vec3.addScale(cam.pos, fwd,  -speed) end
    if love.keyboard.isDown("a","left")  then cam.pos = Vec3.addScale(cam.pos, right,-speed) end
    if love.keyboard.isDown("d","right") then cam.pos = Vec3.addScale(cam.pos, right, speed) end
    if love.keyboard.isDown("q")         then cam.pos.y = cam.pos.y + speed end
    if love.keyboard.isDown("e")         then cam.pos.y = cam.pos.y - speed end

    -- Auto rotate cube
    if autoRotate and selectedScene <= 2 then
        cubeRot.y = cubeRot.y + dt * 0.8
        cubeRot.x = cubeRot.x + dt * 0.3
    end
end

function Example.draw()
    -- Background
    love.graphics.setColor(0.05, 0.06, 0.12)
    love.graphics.rectangle("fill", 0, 0, W, H)

    -- Stars for space scenes
    if selectedScene == 4 then
        love.graphics.setColor(1,1,1,0.6)
        math.randomseed(123)
        for _ = 1, 200 do
            love.graphics.circle("fill",
                math.random(0,W), math.random(0,H), math.random()*1.5)
        end
    end

    local vp = getViewProj()

    -- Draw grid floor
    if selectedScene <= 2 then
        local model = Mat4.identity()
        love.graphics.setColor(0.15, 0.18, 0.25, 0.6)
        for i = -5, 5 do
            local ax, ay = project(vp, model, Vec3.new(i, -1, -5))
            local bx, by = project(vp, model, Vec3.new(i, -1,  5))
            if ax and bx then love.graphics.line(ax,ay,bx,by) end
            ax, ay = project(vp, model, Vec3.new(-5, -1, i))
            bx, by = project(vp, model, Vec3.new( 5, -1, i))
            if ax and bx then love.graphics.line(ax,ay,bx,by) end
        end
    end

    if selectedScene == 1 then
        -- Single solid cube
        local model = Mat4.mul(
            Mat4.mul(Mat4.rotateY(cubeRot.y), Mat4.rotateX(cubeRot.x)),
            Mat4.rotateZ(cubeRot.z))
        drawCube(vp, model, false)

    elseif selectedScene == 2 then
        -- Multiple cubes
        local positions = {
            {x= 0, y=0, z=0, s=1.0},
            {x= 3, y=0, z=0, s=0.6},
            {x=-3, y=0, z=0, s=0.6},
            {x= 0, y=0, z=3, s=0.7},
            {x= 0, y=0, z=-3,s=0.7},
            {x= 2, y=1.5,z=2, s=0.4},
        }
        for _, p in ipairs(positions) do
            local model = Mat4.mul(
                Mat4.translate(p.x, p.y, p.z),
                Mat4.mul(Mat4.scale(p.s,p.s,p.s),
                    Mat4.mul(Mat4.rotateY(cubeRot.y*(1+p.s)),
                             Mat4.rotateX(cubeRot.x))))
            drawCube(vp, model, false)
        end

    elseif selectedScene == 3 then
        drawTerrain(vp)

    elseif selectedScene == 4 then
        drawSolarSystem(vp)
    end

    -- Axes (bottom left)
    local axModel = Mat4.mul(
        Mat4.translate(W*0.08, H*0.85, 0),
        Mat4.mul(Mat4.rotateY(cam.yaw), Mat4.rotateX(cam.pitch)))
    -- Just labels
    love.graphics.setColor(0.9, 0.3, 0.3); love.graphics.print("X", W*0.08+30, H*0.85-5)
    love.graphics.setColor(0.3, 0.9, 0.3); love.graphics.print("Y", W*0.08-5,  H*0.85-30)
    love.graphics.setColor(0.3, 0.3, 0.9); love.graphics.print("Z", W*0.08-20, H*0.85+10)

    -- Info panel
    love.graphics.setColor(0.06, 0.08, 0.14, 0.90)
    love.graphics.rectangle("fill", W-200, 30, 190, 120, 6,6)
    love.graphics.setColor(0.5, 0.7, 1.0)
    love.graphics.printf("3D BASICS", W-200, 38, 190, "center")
    love.graphics.setColor(0.7, 0.75, 0.85)
    love.graphics.print(string.format(
        "Scene: %s\nCam:   %.1f %.1f %.1f\nYaw:   %.2f\nPitch: %.2f",
        scenes[selectedScene],
        cam.pos.x, cam.pos.y, cam.pos.z,
        cam.yaw, cam.pitch),
        W-188, 58)

    -- Scene buttons
    local bw = 42
    for i, name in ipairs(scenes) do
        local bx = W - 200 + (i-1)*(bw+3) + 4
        local by = H - 60
        local sel = (i == selectedScene)
        love.graphics.setColor(sel and 0.20 or 0.10,
                               sel and 0.35 or 0.14,
                               sel and 0.60 or 0.22)
        love.graphics.rectangle("fill", bx, by, bw, 26, 4,4)
        love.graphics.setColor(sel and 0.5 or 0.3,
                               sel and 0.75 or 0.45,
                               sel and 1.0 or 0.6)
        love.graphics.rectangle("line", bx, by, bw, 26, 4,4)
        love.graphics.setColor(sel and 1 or 0.6, sel and 1 or 0.6, sel and 1 or 0.7)
        love.graphics.printf(i..":"..name:sub(1,4), bx, by+6, bw, "center")
    end

    Utils.drawHUD("3D BASICS",
        "WASD move    QE up/down    drag look    1-4 scene    R auto-rotate    ESC back")
end

function Example.keypressed(key)
    local n = tonumber(key)
    if n and n >= 1 and n <= #scenes then
        selectedScene = n
        if n == 1 or n == 2 then
            cam.pos   = Vec3.new(0, 2, 6)
            cam.pitch = -0.2
        elseif n == 3 then
            cam.pos   = Vec3.new(0, 8, 12)
            cam.pitch = -0.45
        elseif n == 4 then
            cam.pos   = Vec3.new(0, 4, 18)
            cam.pitch = -0.15
        end
        cam.yaw = 0
        return
    end
    if key == "r" then autoRotate = not autoRotate end
    Utils.handlePause(key, Example)
end

function Example.mousepressed(x, y, button)
    if button == 1 then
        -- Scene buttons
        local bw = 42
        for i = 1, #scenes do
            local bx = W - 200 + (i-1)*(bw+3) + 4
            local by = H - 60
            if x>=bx and x<=bx+bw and y>=by and y<=by+26 then
                selectedScene = i
                if i == 1 or i == 2 then
                    cam.pos   = Vec3.new(0, 2, 6)
                    cam.pitch = -0.2
                elseif i == 3 then
                    cam.pos   = Vec3.new(0, 8, 12)
                    cam.pitch = -0.45
                elseif i == 4 then
                    cam.pos   = Vec3.new(0, 4, 18)
                    cam.pitch = -0.15
                end
                cam.yaw = 0
                return
            end
        end
    end
end

return Example
