-- src/characters/skins/soft.lua
-- Outlined capsule skin. All primitives from src/systems/draw2d.lua.

local Soft = {}
local Draw = require "src.systems.draw2d"

local function proj(b, cam) return cam:toScreen(b.x, b.y, b.z) end

local function limb(a, b, r1, r2, fill, outline, cam)
    local ax, ay = proj(a, cam)
    local bx, by = proj(b, cam)
    Draw.ocapsule(ax,ay,r1, bx,by,r2, fill, outline)
end

function Soft.draw(bones, rig, profile, camera, _c)
    local col = profile.color
    local pw  = profile.widths    or {}
    local ps  = profile.secondary or {}
    local fd  = profile.far_darken or 0.50

    local hw = rig.hip_w      or 18
    local sw = rig.shoulder_w or 22

    local leg_top = pw.leg_top   or hw * 0.55
    local leg_bot = pw.leg_bot   or hw * 0.38
    local foot    = pw.foot      or hw * 0.28
    local arm_top = pw.arm_top   or sw * 0.40
    local arm_bot = pw.arm_bot   or sw * 0.30
    local hand    = pw.hand      or sw * 0.22
    local tor_bot = pw.torso_bot or hw * 0.88
    local tor_top = pw.torso_top or sw * 0.82

    local fill        = { col[1],      col[2],      col[3],      1    }
    local outline     = profile.outline_color
                     or { col[1]*0.30, col[2]*0.30, col[3]*0.30, 1    }
    local far_fill    = { col[1]*fd,   col[2]*fd,   col[3]*fd,   0.85 }
    local far_outline = { col[1]*0.18, col[2]*0.18, col[3]*0.18, 0.85 }

    -- far layer
    limb(bones.far_shoulder, bones.far_elbow, arm_top, arm_bot, far_fill, far_outline, camera)
    limb(bones.far_elbow,    bones.far_hand,  arm_bot, hand,    far_fill, far_outline, camera)
    limb(bones.far_hip,      bones.far_knee,  leg_top, leg_bot, far_fill, far_outline, camera)
    limb(bones.far_knee,     bones.far_foot,  leg_bot, foot,    far_fill, far_outline, camera)

    -- torso: single wide capsule hip → chest
    limb(bones.hip, bones.chest, tor_bot, tor_top, fill, outline, camera)

    -- near layer
    limb(bones.near_hip,      bones.near_knee,  leg_top, leg_bot, fill, outline, camera)
    limb(bones.near_knee,     bones.near_foot,  leg_bot, foot,    fill, outline, camera)
    limb(bones.near_shoulder, bones.near_elbow, arm_top, arm_bot, fill, outline, camera)
    limb(bones.near_elbow,    bones.near_hand,  arm_bot, hand,    fill, outline, camera)

    -- secondary: breast
    if bones.breast_l and bones.breast_r then
        local br = (ps.breast and ps.breast.r) or (sw * 0.32)
        local bn = bones.left_near and bones.breast_l or bones.breast_r
        local bf = bones.left_near and bones.breast_r or bones.breast_l
        local bfx, bfy = proj(bf, camera)
        Draw.ocirc(bfx, bfy, br*0.82, far_fill, far_outline)
        local bnx, bny = proj(bn, camera)
        Draw.ocirc(bnx, bny, br, fill, outline)
    end

    -- secondary: ponytail / tail
    if bones.ponytail and #bones.ponytail >= 2 then
        local pts    = bones.ponytail
        local n      = #pts
        local root_r = (ps.ponytail and ps.ponytail.r) or 4
        for i = 1, n-1 do
            local t1 = (i-1)/(n-1);  local t2 = i/(n-1)
            limb(pts[i], pts[i+1],
                root_r*(1-t1*0.70), root_r*(1-t2*0.70),
                fill, outline, camera)
        end
    end

    -- secondary: belly
    if bones.belly then
        local br    = (ps.belly and ps.belly.r) or (hw*0.60)
        local bx,by = proj(bones.belly, camera)
        Draw.ocirc(bx, by, br, fill, outline)
    end

    -- head
    local hdx, hdy = proj(bones.head, camera)
    Draw.ball(hdx, hdy, rig.head_r or 17, fill, outline)
end

return Soft
