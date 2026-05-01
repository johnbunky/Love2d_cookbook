-- src/characters/skins/wire.lua
-- Line skeleton. Default skin (profile.skin = nil falls back here).
-- Uses safe() from draw2d for projection guards.

local Wire = {}

local function safe(x, y)
    return x == x and y == y and math.abs(x) < 5000 and math.abs(y) < 5000
end

local function proj(b, cam) return cam:toScreen(b.x, b.y, b.z) end

local function seg(a, b, cam)
    local ax, ay = proj(a, cam)
    local bx, by = proj(b, cam)
    if not (safe(ax,ay) and safe(bx,by)) then return end
    love.graphics.line(ax, ay, bx, by)
    love.graphics.circle("fill", bx, by, 4)
end

local function bar(a, b, cam, w)
    local ax, ay = proj(a, cam)
    local bx, by = proj(b, cam)
    if not (safe(ax,ay) and safe(bx,by)) then return end
    love.graphics.setLineWidth(w or 4)
    love.graphics.line(ax, ay, bx, by)
    love.graphics.circle("fill", ax, ay, 5)
    love.graphics.circle("fill", bx, by, 5)
end

function Wire.draw(bones, rig, profile, camera, _c)
    local col = profile.color

    love.graphics.setLineWidth(3)

    -- far layer (dimmed)
    love.graphics.setColor(col[1]*0.5, col[2]*0.5, col[3]*0.5, 0.42)
    seg(bones.far_shoulder, bones.far_elbow, camera)
    seg(bones.far_elbow,    bones.far_hand,  camera)
    seg(bones.far_hip,      bones.far_knee,  camera)
    seg(bones.far_knee,     bones.far_foot,  camera)

    -- spine
    love.graphics.setColor(col[1], col[2], col[3])
    seg(bones.hip, bones.chest, camera)

    -- hip bar
    bar(bones.hip_left, bones.hip_right, camera, 4)

    -- shoulder bar
    love.graphics.setColor(col[1], col[2], col[3])
    bar(bones.shoulder_left, bones.shoulder_right, camera, 4)

    -- head
    love.graphics.setLineWidth(2)
    local hdx, hdy = proj(bones.head, camera)
    if safe(hdx, hdy) then
        love.graphics.setColor(col[1], col[2], col[3])
        love.graphics.circle("line", hdx, hdy, rig.head_r)
    end

    -- near layer (full brightness)
    love.graphics.setLineWidth(3)
    love.graphics.setColor(col[1], col[2], col[3])
    seg(bones.near_hip,      bones.near_knee,  camera)
    seg(bones.near_knee,     bones.near_foot,  camera)
    seg(bones.near_shoulder, bones.near_elbow, camera)
    seg(bones.near_elbow,    bones.near_hand,  camera)

    love.graphics.setLineWidth(1)
end

return Wire
