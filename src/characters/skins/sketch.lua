-- src/characters/skins/sketch.lua
--
-- Sketch/ink skin: outlines only, no fill.
-- Line weight varies by limb — thicker on the body, thinner on extremities.
-- Far side lines are thinner and lighter, near side full weight.
-- Combine with "face" skin for a complete illustrated look.
--
-- Profile keys (all optional):
--   profile.color              {r,g,b}   ink color (def near-black)
--   profile.sketch.near_w      number    near side line width px (def 2.5)
--   profile.sketch.far_w       number    far side line width px  (def 1.2)
--   profile.sketch.far_alpha   number    far side opacity (def 0.38)

local Sketch = {}
local Draw   = require "src.systems.draw2d"

local function proj(b, cam) return cam:toScreen(b.x, b.y, b.z) end

-- Draw the outline of a capsule without filling it.
-- Draws two parallel lines + semicircle caps.
local function stroke_capsule(x1,y1,r1, x2,y2,r2, lw)
    if not (Draw.safe(x1,y1) and Draw.safe(x2,y2)) then return end
    local dx = x2-x1;  local dy = y2-y1
    local len = math.sqrt(dx*dx+dy*dy)
    if len < 1 then
        love.graphics.circle("line", x1, y1, math.max(r1,r2), 10)
        return
    end
    local nx = -dy/len;  local ny = dx/len
    love.graphics.setLineWidth(lw)
    -- two side lines
    love.graphics.line(x1+nx*r1, y1+ny*r1, x2+nx*r2, y2+ny*r2)
    love.graphics.line(x1-nx*r1, y1-ny*r1, x2-nx*r2, y2-ny*r2)
    -- end caps (arcs approximated as partial circles)
    local a_start = math.atan2(ny, nx)
    love.graphics.arc("line", "open", x1, y1, r1,  a_start + math.pi*0.5,  a_start + math.pi*1.5, 8)
    love.graphics.arc("line", "open", x2, y2, r2,  a_start - math.pi*0.5,  a_start + math.pi*0.5, 8)
end

local function sketch_limb(a, b, r1, r2, lw, cam)
    local ax,ay = proj(a, cam);  local bx,by = proj(b, cam)
    stroke_capsule(ax,ay,r1, bx,by,r2, lw)
end

function Sketch.draw(bones, rig, profile, camera, _c)
    local col = profile.color or {0.12, 0.10, 0.10}
    local ps  = profile.sketch or {}
    local pw  = profile.widths or {}

    local hw = rig.hip_w      or 18
    local sw = rig.shoulder_w or 22

    local leg_top = pw.leg_top or hw * 0.55
    local leg_bot = pw.leg_bot or hw * 0.38
    local foot    = pw.foot    or hw * 0.28
    local arm_top = pw.arm_top or sw * 0.40
    local arm_bot = pw.arm_bot or sw * 0.30
    local hand    = pw.hand    or sw * 0.22
    local tor_bot = pw.torso_bot or hw * 0.88
    local tor_top = pw.torso_top or sw * 0.82

    local near_w   = ps.near_w    or 2.5
    local far_w    = ps.far_w     or 1.2
    local far_a    = ps.far_alpha or 0.38

    -- far layer (thin, faded)
    love.graphics.setColor(col[1], col[2], col[3], far_a)
    sketch_limb(bones.far_shoulder, bones.far_elbow, arm_top, arm_bot, far_w, camera)
    sketch_limb(bones.far_elbow,    bones.far_hand,  arm_bot, hand,    far_w, camera)
    sketch_limb(bones.far_hip,      bones.far_knee,  leg_top, leg_bot, far_w, camera)
    sketch_limb(bones.far_knee,     bones.far_foot,  leg_bot, foot,    far_w, camera)

    -- torso outline
    love.graphics.setColor(col[1], col[2], col[3], 1)
    sketch_limb(bones.hip, bones.chest, tor_bot, tor_top, near_w * 1.2, camera)

    -- near layer (full weight)
    sketch_limb(bones.near_hip,      bones.near_knee,  leg_top, leg_bot, near_w, camera)
    sketch_limb(bones.near_knee,     bones.near_foot,  leg_bot, foot,    near_w * 0.85, camera)
    sketch_limb(bones.near_shoulder, bones.near_elbow, arm_top, arm_bot, near_w, camera)
    sketch_limb(bones.near_elbow,    bones.near_hand,  arm_bot, hand,    near_w * 0.85, camera)

    -- head: circle outline, slightly heavier
    local hr      = rig.head_r or 17
    local hdx,hdy = proj(bones.head, camera)
    if Draw.safe(hdx, hdy) then
        love.graphics.setColor(col[1], col[2], col[3], 1)
        love.graphics.setLineWidth(near_w * 1.1)
        love.graphics.circle("line", hdx, hdy, hr, 14)
        love.graphics.setLineWidth(1)
    end
end

return Sketch
