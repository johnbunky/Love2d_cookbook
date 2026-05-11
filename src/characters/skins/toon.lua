-- src/characters/skins/toon.lua
--
-- Cartoon skin: flat color, thick black outline, no shading.
-- Far side is same hue but darker — no gradients, no highlights.
-- Works best with saturated profile.color values.
--
-- Profile keys (all optional):
--   profile.color              {r,g,b}   fill color
--   profile.toon.outline       {r,g,b,a} outline color (def black)
--   profile.toon.outline_w     number    outline thickness px (def 4)
--   profile.far_darken         0-1       far side dim (def 0.55)

local Toon = {}
local Draw = require "src.systems.draw2d"

local function proj(b, cam) return cam:toScreen(b.x, b.y, b.z) end

local function limb(a, b, r1, r2, fill, outline, ow, cam)
    local ax,ay = proj(a, cam);  local bx,by = proj(b, cam)
    if not (Draw.safe(ax,ay) and Draw.safe(bx,by)) then return end
    Draw.ocapsule(ax,ay,r1, bx,by,r2, fill, outline, ow)
end

function Toon.draw(bones, rig, profile, camera, _c)
    local col = profile.color
    local pt  = profile.toon   or {}
    local pw  = profile.widths or {}
    local fd  = profile.far_darken or 0.55

    local hw = rig.hip_w      or 18
    local sw = rig.shoulder_w or 22

    -- toon uses uniform (non-tapered) segments for a cleaner cartoon look
    local leg = math.max(pw.leg_top or hw*0.58, 7)
    local arm = math.max(pw.arm_top or sw*0.42, 6)
    local tor = math.max(pw.torso_bot or hw*0.90, 11)

    local ow      = pt.outline_w or 4
    local outline = pt.outline   or {0.08, 0.06, 0.06, 1}

    local fill     = {col[1],    col[2],    col[3],    1}
    local far_fill = {col[1]*fd, col[2]*fd, col[3]*fd, 1}

    -- far layer
    limb(bones.far_shoulder, bones.far_elbow, arm, arm, far_fill, outline, ow, camera)
    limb(bones.far_elbow,    bones.far_hand,  arm, arm*0.72, far_fill, outline, ow, camera)
    limb(bones.far_hip,      bones.far_knee,  leg, leg, far_fill, outline, ow, camera)
    limb(bones.far_knee,     bones.far_foot,  leg, leg*0.78, far_fill, outline, ow, camera)

    -- torso
    limb(bones.hip, bones.chest, tor, tor*0.88, fill, outline, ow, camera)

    -- near layer
    limb(bones.near_hip,      bones.near_knee,  leg,     leg,      fill, outline, ow, camera)
    limb(bones.near_knee,     bones.near_foot,  leg,     leg*0.78, fill, outline, ow, camera)
    limb(bones.near_shoulder, bones.near_elbow, arm,     arm,      fill, outline, ow, camera)
    limb(bones.near_elbow,    bones.near_hand,  arm,     arm*0.72, fill, outline, ow, camera)

    -- head: flat filled circle, thick outline
    local hr      = rig.head_r or 17
    local hdx,hdy = proj(bones.head, camera)
    if Draw.safe(hdx, hdy) then
        love.graphics.setColor(outline)
        love.graphics.circle("fill", hdx, hdy, hr + ow, 14)
        love.graphics.setColor(fill)
        love.graphics.circle("fill", hdx, hdy, hr, 14)
    end
end

return Toon
