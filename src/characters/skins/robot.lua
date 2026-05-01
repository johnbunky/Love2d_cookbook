-- src/characters/skins/robot.lua
-- Hold R: full on-screen debug console.

local Robot = {}

local OL = 2.0

local function safe(x, y)
    return x == x and y == y
        and math.abs(x) < 5000
        and math.abs(y) < 5000
end

local function proj(b, cam)
    return cam:toScreen(b.x, b.y, b.z)
end

local function rect_seg(x1,y1,w1, x2,y2,w2)
    if not (safe(x1,y1) and safe(x2,y2)) then return end
    if w1 > 200 or w2 > 200 then return end
    local dx = x2-x1;  local dy = y2-y1
    local len = math.sqrt(dx*dx + dy*dy)
    if len < 1 then return end
    local nx = -dy/len;  local ny = dx/len
    love.graphics.polygon("fill",
        x1+nx*w1, y1+ny*w1,
        x2+nx*w2, y2+ny*w2,
        x2-nx*w2, y2-ny*w2,
        x1-nx*w1, y1-ny*w1
    )
end

local function orect(x1,y1,w1, x2,y2,w2, fill, outline)
    love.graphics.setColor(outline)
    rect_seg(x1,y1, w1+OL, x2,y2, w2+OL)
    love.graphics.setColor(fill)
    rect_seg(x1,y1, w1,    x2,y2, w2)
end

-- Torso plate: push/rotate/rectangle — no hand-rolled polygon, no triangle risk.
-- w = half-width of the plate in pixels (uniform, robots don't need taper).
local function torso_plate(x1,y1, x2,y2, w, fill, outline)
    if not (safe(x1,y1) and safe(x2,y2)) then return end
    local dx = x2-x1;  local dy = y2-y1
    local len = math.sqrt(dx*dx + dy*dy)
    if len < 1 then return end
    local angle = math.atan2(dy, dx)
    love.graphics.push()
    love.graphics.translate(x1, y1)
    love.graphics.rotate(angle)
    love.graphics.setColor(outline)
    love.graphics.rectangle("fill", -OL, -(w+OL), len + OL*2, (w+OL)*2)
    love.graphics.setColor(fill)
    love.graphics.rectangle("fill",  0,  -w,       len,        w*2)
    love.graphics.pop()
end

local function bolt(x, y, r, metal_col)
    if not safe(x, y) then return end
    love.graphics.setColor(0.10, 0.10, 0.12, 1)
    love.graphics.circle("fill", x, y, r+1.5, 8)
    love.graphics.setColor(metal_col)
    love.graphics.circle("fill", x, y, r, 8)
    love.graphics.setColor(0, 0, 0, 0)
end

local function limb(a, b, w1, w2, fill, outline, bolt_r, bolt_col, cam)
    if not a or not b then return end
    local ax,ay = proj(a, cam)
    local bx,by = proj(b, cam)
    if not (safe(ax,ay) and safe(bx,by)) then return end
    orect(ax,ay,w1, bx,by,w2, fill, outline)
    bolt(bx, by, bolt_r, bolt_col)
end

-- ── on-screen debug console ───────────────────────────────────────────────────
local function draw_debug(bones, rig, widths, camera)
    local W  = love.graphics.getWidth()
    local lh = 13
    local px = W - 340
    local py = 55

    -- collect all bone entries and sort by name
    local entries = {}
    for k, v in pairs(bones) do
        if type(v) == "table" and v.x ~= nil then
            local sx, sy = camera:toScreen(v.x, v.y, v.z)
            local bad = not safe(sx, sy)
            table.insert(entries, { name=k, b=v, sx=sx, sy=sy, bad=bad })
        end
    end
    table.sort(entries, function(a,b) return a.name < b.name end)

    local rows = #entries + 8   -- bones + header + widths + scalars
    love.graphics.setColor(0, 0, 0, 0.78)
    love.graphics.rectangle("fill", px-6, py-4, 334, rows * lh + 8)

    -- header
    love.graphics.setColor(1, 0.85, 0.2, 1)
    love.graphics.print("ROBOT BONE DEBUG  (hold R)", px, py)
    py = py + lh + 2

    love.graphics.setColor(0.55, 0.55, 0.55, 1)
    love.graphics.print(
        string.format("%-20s %6s %6s %6s  %7s %7s", "bone","wx","wy","wz","sx","sy"),
        px, py, 0, 0.85)
    py = py + lh

    for _, e in ipairs(entries) do
        -- dot on character
        if safe(e.sx, e.sy) then
            love.graphics.setColor(0.2, 1, 0.5, 0.9)
            love.graphics.circle("fill", e.sx, e.sy, 3)
            love.graphics.setColor(0, 0, 0, 0.7)
            love.graphics.print(e.name, e.sx+5, e.sy-5, 0, 0.65)
        end
        -- console row
        if e.bad then
            love.graphics.setColor(1, 0.25, 0.25, 1)
        else
            love.graphics.setColor(0.82, 0.95, 0.82, 1)
        end
        love.graphics.print(
            string.format("%-20s %6.0f %6.0f %6.0f  %7.1f %7.1f%s",
                e.name, e.b.x, e.b.y, e.b.z, e.sx, e.sy,
                e.bad and " BAD" or ""),
            px, py, 0, 0.85)
        py = py + lh
    end

    -- scalar/bool bones
    love.graphics.setColor(0.6, 0.6, 0.6, 1)
    love.graphics.print(
        string.format("facing=%s  left_near=%s",
            tostring(bones.facing), tostring(bones.left_near)),
        px, py, 0, 0.85)
    py = py + lh

    -- rig values
    love.graphics.setColor(0.7, 0.8, 1, 1)
    love.graphics.print(
        string.format("rig  hip_w=%.0f  shoulder_w=%.0f  spine=%.0f  head_r=%.0f",
            rig.hip_w or 0, rig.shoulder_w or 0, rig.spine or 0, rig.head_r or 0),
        px, py, 0, 0.85)
    py = py + lh

    -- computed widths
    love.graphics.setColor(1, 0.7, 0.4, 1)
    love.graphics.print(
        string.format("widths  leg=%.0f/%.0f/%.0f  arm=%.0f/%.0f/%.0f  tor=%.0f/%.0f",
            widths.leg_top, widths.leg_bot, widths.foot,
            widths.arm_top, widths.arm_bot, widths.hand,
            widths.tor_bot, widths.tor_top),
        px, py, 0, 0.85)
end

-- ── public ────────────────────────────────────────────────────────────────────
function Robot.draw(bones, rig, profile, camera, _c)
    local col = profile.color
    local pw  = profile.widths or {}
    local pr  = profile.robot  or {}
    local fd  = profile.far_darken or 0.45

    local hw = rig.hip_w      or 18
    local sw = rig.shoulder_w or 22

    local w = {
        leg_top = math.max(pw.leg_top or hw * 0.52, 6),
        leg_bot = math.max(pw.leg_bot or hw * 0.46, 5),
        foot    = math.max(pw.foot    or hw * 0.38, 4),
        arm_top = math.max(pw.arm_top or sw * 0.38, 5),
        arm_bot = math.max(pw.arm_bot or sw * 0.34, 4),
        hand    = math.max(pw.hand    or sw * 0.28, 3),
        tor_bot = math.max(pw.torso_bot or hw * 0.88, 10),
        tor_top = math.max(pw.torso_top or sw * 0.82, 10),
    }

    local fill    = { col[1],        col[2],        col[3],        1    }
    local fill2   = { col[1]*0.78,   col[2]*0.78,   col[3]*0.78,   1    }
    local outline = profile.outline_color or { 0.12, 0.12, 0.14, 1 }

    local far_fill    = { col[1]*fd,      col[2]*fd,      col[3]*fd,      0.85 }
    local far_fill2   = { col[1]*fd*0.78, col[2]*fd*0.78, col[3]*fd*0.78, 0.85 }
    local far_outline = { 0.06, 0.06, 0.08, 0.85 }

    local bolt_r   = pr.joint_size  or 3.5
    local bolt_col = pr.joint_color or { 0.75, 0.78, 0.82, 1 }

    -- far layer
    limb(bones.far_shoulder, bones.far_elbow, w.arm_top, w.arm_bot, far_fill,  far_outline, bolt_r, bolt_col, camera)
    limb(bones.far_elbow,    bones.far_hand,  w.arm_bot, w.hand,    far_fill2, far_outline, bolt_r, bolt_col, camera)
    limb(bones.far_hip,      bones.far_knee,  w.leg_top, w.leg_bot, far_fill,  far_outline, bolt_r, bolt_col, camera)
    limb(bones.far_knee,     bones.far_foot,  w.leg_bot, w.foot,    far_fill2, far_outline, bolt_r, bolt_col, camera)

    -- torso: two plates drawn with push/rotate/rectangle
    local hx,hy = proj(bones.hip,   camera)
    local cx,cy = proj(bones.chest, camera)
    if safe(hx,hy) and safe(cx,cy) then
        local mx = (hx+cx)*0.5;  local my = (hy+cy)*0.5
        local tw = (w.tor_bot + w.tor_top) * 0.5   -- uniform half-width
        torso_plate(hx,hy, mx,my, w.tor_bot, fill2, outline)   -- pelvis plate
        bolt(hx, hy, bolt_r*1.2, bolt_col)
        torso_plate(mx,my, cx,cy, w.tor_top, fill,  outline)   -- chest plate
        bolt(cx, cy, bolt_r*1.2, bolt_col)
        bolt(mx, my, bolt_r,     bolt_col)                     -- mid joint
    end

    -- near layer
    limb(bones.near_hip,      bones.near_knee,  w.leg_top, w.leg_bot, fill,  outline, bolt_r, bolt_col, camera)
    limb(bones.near_knee,     bones.near_foot,  w.leg_bot, w.foot,    fill2, outline, bolt_r, bolt_col, camera)
    limb(bones.near_shoulder, bones.near_elbow, w.arm_top, w.arm_bot, fill,  outline, bolt_r, bolt_col, camera)
    limb(bones.near_elbow,    bones.near_hand,  w.arm_bot, w.hand,    fill2, outline, bolt_r, bolt_col, camera)

    -- head
    local hr       = rig.head_r or 17
    local hdx, hdy = proj(bones.head, camera)
    if safe(hdx, hdy) then
        love.graphics.setColor(outline)
        local vo = {}
        for i = 0,5 do
            local a = math.pi/6 + i*math.pi/3
            vo[i*2+1] = hdx + math.cos(a)*(hr+OL)
            vo[i*2+2] = hdy + math.sin(a)*(hr+OL)
        end
        love.graphics.polygon("fill", vo)

        love.graphics.setColor(fill)
        local vf = {}
        for i = 0,5 do
            local a = math.pi/6 + i*math.pi/3
            vf[i*2+1] = hdx + math.cos(a)*hr
            vf[i*2+2] = hdy + math.sin(a)*hr
        end
        love.graphics.polygon("fill", vf)

        love.graphics.setColor(0.2, 0.8, 1.0, 0.85)
        love.graphics.rectangle("fill", hdx-hr*0.45, hdy-hr*0.10, hr*0.90, hr*0.22)
        bolt(hdx, hdy+hr*0.75, bolt_r, bolt_col)
    end

    -- debug overlay: hold R
    if love.keyboard.isDown("r") then
        draw_debug(bones, rig, w, camera)
    end
end

return Robot
