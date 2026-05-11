-- src/characters/skins/ghost.lua
--
-- Ghost/spirit skin: semi-transparent, soft inner glow, no hard outline.
-- Use with blend = "add" in the skin stack for a glowing energy effect,
-- or blend = "alpha" for a translucent ghost.
--
-- Best combined with a dark background.
--
-- Profile keys (all optional):
--   profile.color              {r,g,b}   glow color
--   profile.ghost.alpha        number    overall opacity (def 0.55)
--   profile.ghost.core_alpha   number    bright core opacity (def 0.30)
--   profile.ghost.glow_scale   number    glow radius multiplier (def 1.5)

local Ghost = {}
local Draw  = require "src.systems.draw2d"

local function proj(b, cam) return cam:toScreen(b.x, b.y, b.z) end

-- Soft glow capsule: draw two passes — wide faint outer, narrow brighter inner.
local function glow_limb(ax,ay,r1, bx,by,r2, col, alpha, core_alpha, glow_scale)
    if not (Draw.safe(ax,ay) and Draw.safe(bx,by)) then return end
    -- outer glow (wide, faint)
    love.graphics.setColor(col[1], col[2], col[3], alpha * 0.5)
    Draw.capsule(ax,ay, r1*glow_scale, bx,by, r2*glow_scale)
    -- inner core (narrow, brighter)
    love.graphics.setColor(col[1], col[2], col[3], alpha + core_alpha)
    Draw.capsule(ax,ay, r1*0.55, bx,by, r2*0.55)
end

local function limb(a, b, r1, r2, col, alpha, core_alpha, glow_scale, cam)
    local ax,ay = proj(a, cam);  local bx,by = proj(b, cam)
    glow_limb(ax,ay,r1, bx,by,r2, col, alpha, core_alpha, glow_scale)
end

function Ghost.draw(bones, rig, profile, camera, _c)
    local col = profile.color or {0.55, 0.80, 1.0}
    local pg  = profile.ghost  or {}
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

    local alpha      = pg.alpha      or 0.55
    local core_alpha = pg.core_alpha or 0.30
    local glow_scale = pg.glow_scale or 1.5

    -- far layer (dimmer)
    local fa = alpha * 0.45
    limb(bones.far_shoulder, bones.far_elbow, arm_top, arm_bot, col, fa, core_alpha*0.5, glow_scale, camera)
    limb(bones.far_elbow,    bones.far_hand,  arm_bot, hand,    col, fa, core_alpha*0.5, glow_scale, camera)
    limb(bones.far_hip,      bones.far_knee,  leg_top, leg_bot, col, fa, core_alpha*0.5, glow_scale, camera)
    limb(bones.far_knee,     bones.far_foot,  leg_bot, foot,    col, fa, core_alpha*0.5, glow_scale, camera)

    -- torso
    limb(bones.hip, bones.chest, tor_bot, tor_top, col, alpha, core_alpha, glow_scale, camera)

    -- near layer
    limb(bones.near_hip,      bones.near_knee,  leg_top, leg_bot, col, alpha, core_alpha, glow_scale, camera)
    limb(bones.near_knee,     bones.near_foot,  leg_bot, foot,    col, alpha, core_alpha, glow_scale, camera)
    limb(bones.near_shoulder, bones.near_elbow, arm_top, arm_bot, col, alpha, core_alpha, glow_scale, camera)
    limb(bones.near_elbow,    bones.near_hand,  arm_bot, hand,    col, alpha, core_alpha, glow_scale, camera)

    -- head: glow ball
    local hr      = rig.head_r or 17
    local hdx,hdy = proj(bones.head, camera)
    if Draw.safe(hdx, hdy) then
        love.graphics.setColor(col[1], col[2], col[3], alpha * 0.45)
        love.graphics.circle("fill", hdx, hdy, hr * glow_scale, 14)
        love.graphics.setColor(col[1], col[2], col[3], alpha + core_alpha)
        love.graphics.circle("fill", hdx, hdy, hr * 0.60, 14)
    end

    love.graphics.setColor(1,1,1,1)
end

return Ghost
