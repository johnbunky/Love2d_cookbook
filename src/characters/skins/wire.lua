--- src/characters/skins/wire.lua
--
-- Skeleton debug / wireframe skin.
-- Draws every bone as a line, every joint as a filled circle.
-- This is the "nothing breaks" reference skin — it exactly replaces
-- the old line/oval drawing that was inlined in humanoid_draw.lua.
--
-- Interface:  Wire.draw(bones, rig, profile, camera)

local Wire = {}

-- ── default palette (override per-profile with profile.colors.wire_*) ────────
local DEF = {
    body   = { 0.80, 0.75, 0.70, 1 },   -- skeleton lines
    far    = { 0.55, 0.52, 0.50, 1 },   -- far-side limbs (darker/greyer)
    joint  = { 1.00, 1.00, 1.00, 1 },   -- joint dots
    head   = { 0.95, 0.85, 0.70, 1 },   -- head circle fill
    joint_r = 3,                          -- joint dot radius (px)
    head_r  = 10,                         -- head radius (px)
    line_w  = 2,                          -- bone line width
}

-- ── helpers ───────────────────────────────────────────────────────────────────

local function proj(b, cam)
    return cam:toScreen(b.x, b.y, b.z)
end

local function bone(a, b, cam)
    local ax, ay = proj(a, cam)
    local bx, by = proj(b, cam)
    love.graphics.line(ax, ay, bx, by)
end

local function dot(b, r, cam)
    local x, y = proj(b, cam)
    love.graphics.circle("fill", x, y, r)
end

-- ── public ────────────────────────────────────────────────────────────────────

function Wire.draw(bones, rig, profile, camera)
    local c  = (profile.colors or {})
    local fw = c.wire_far   or DEF.far
    local bw = c.wire_body  or DEF.body
    local jw = c.wire_joint or DEF.joint
    local hw = c.wire_head  or DEF.head
    local jr = c.wire_joint_r or DEF.joint_r
    local hr = c.wire_head_r  or DEF.head_r
    local lw = c.wire_line_w  or DEF.line_w

    love.graphics.setLineWidth(lw)

    -- ── far arm ──────────────────────────────────────────────────────────────
    love.graphics.setColor(fw)
    bone(bones.far_shoulder, bones.far_elbow, camera)
    bone(bones.far_elbow,    bones.far_hand,  camera)

    -- ── far leg ──────────────────────────────────────────────────────────────
    bone(bones.far_hip,  bones.far_knee, camera)
    bone(bones.far_knee, bones.far_foot, camera)

    -- ── torso ─────────────────────────────────────────────────────────────────
    love.graphics.setColor(bw)
    bone(bones.hip,   bones.chest, camera)
    bone(bones.chest, bones.head,  camera)

    -- ── near arm ─────────────────────────────────────────────────────────────
    bone(bones.near_shoulder, bones.near_elbow, camera)
    bone(bones.near_elbow,    bones.near_hand,  camera)

    -- ── near leg ─────────────────────────────────────────────────────────────
    bone(bones.near_hip,  bones.near_knee, camera)
    bone(bones.near_knee, bones.near_foot, camera)

    -- ── joints ───────────────────────────────────────────────────────────────
    love.graphics.setColor(jw)
    local joint_bones = {
        "far_shoulder","far_elbow","far_hand",
        "far_hip","far_knee","far_foot",
        "hip","chest",
        "near_shoulder","near_elbow","near_hand",
        "near_hip","near_knee","near_foot",
    }
    for _, name in ipairs(joint_bones) do
        if bones[name] then dot(bones[name], jr, camera) end
    end

    -- ── head ─────────────────────────────────────────────────────────────────
    love.graphics.setColor(hw)
    dot(bones.head, hr, camera)

    love.graphics.setLineWidth(1)
end

return Wire
