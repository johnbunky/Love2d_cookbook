-- src/characters/skins/soft.lua
--
-- Outlined capsule skin.
-- Every shape is drawn twice: dark outline pass (r + OL), then fill pass (r).
-- Torso = one wide tapered capsule hip→chest, not a polygon.
-- Secondary items (breast, ponytail, tail, belly) are optional — drawn only
-- when the matching bone keys exist in the bones table.
--
-- Profile keys (all optional):
--   profile.color              {r,g,b}     base color
--   profile.outline_color      {r,g,b,a}   override outline (default: darkened color)
--   profile.far_darken         0-1         far side dim factor (default 0.50)
--   profile.widths.*           numbers     per-limb radius overrides (see DEF_W)
--   profile.secondary.breast   {r=number}  breast circle radius
--   profile.secondary.ponytail {r=number}  ponytail root radius

local Soft = {}

-- outline thickness in pixels
local OL = 2.5

-- ── primitives ────────────────────────────────────────────────────────────────

local function proj(b, cam)
    return cam:toScreen(b.x, b.y, b.z)
end

local function capsule(x1,y1,r1, x2,y2,r2)
    local dx = x2-x1;  local dy = y2-y1
    local len = math.sqrt(dx*dx + dy*dy)
    if len < 0.5 then
        love.graphics.circle("fill", x1, y1, math.max(r1, r2), 10)
        return
    end
    local nx = -dy/len;  local ny = dx/len
    love.graphics.polygon("fill",
        x1+nx*r1, y1+ny*r1,
        x2+nx*r2, y2+ny*r2,
        x2-nx*r2, y2-ny*r2,
        x1-nx*r1, y1-ny*r1
    )
    love.graphics.circle("fill", x1, y1, r1, 10)
    love.graphics.circle("fill", x2, y2, r2, 10)
end

-- outlined capsule: dark pass first, fill pass on top
local function ocap(x1,y1,r1, x2,y2,r2, fill, outline)
    love.graphics.setColor(outline)
    capsule(x1,y1, r1+OL, x2,y2, r2+OL)
    love.graphics.setColor(fill)
    capsule(x1,y1, r1,    x2,y2, r2)
end

-- outlined circle
local function ocirc(x, y, r, fill, outline)
    love.graphics.setColor(outline)
    love.graphics.circle("fill", x, y, r + OL, 12)
    love.graphics.setColor(fill)
    love.graphics.circle("fill", x, y, r,      12)
end

-- world-space bone pair → screen → ocap
local function limb(a, b, r1, r2, fill, outline, cam)
    local ax, ay = proj(a, cam)
    local bx, by = proj(b, cam)
    ocap(ax,ay,r1, bx,by,r2, fill, outline)
end

-- ── public ────────────────────────────────────────────────────────────────────

function Soft.draw(bones, rig, profile, camera)
    local col = profile.color
    local pw  = profile.widths    or {}
    local ps  = profile.secondary or {}
    local fd  = profile.far_darken or 0.50

    local hw = rig.hip_w      or 18
    local sw = rig.shoulder_w or 22

    -- ── resolve widths (proportional to rig by default) ──────────────────────
    local leg_top = pw.leg_top or hw * 0.55
    local leg_bot = pw.leg_bot or hw * 0.38
    local foot    = pw.foot    or hw * 0.28
    local arm_top = pw.arm_top or sw * 0.40
    local arm_bot = pw.arm_bot or sw * 0.30
    local hand    = pw.hand    or sw * 0.22
    local tor_bot = pw.torso_bot or hw * 0.88   -- torso radius at hip
    local tor_top = pw.torso_top or sw * 0.82   -- torso radius at chest

    -- ── colors ───────────────────────────────────────────────────────────────
    local fill = { col[1], col[2], col[3], 1 }

    local outline = profile.outline_color or {
        col[1]*0.30, col[2]*0.30, col[3]*0.30, 1
    }

    local far_fill = { col[1]*fd, col[2]*fd, col[3]*fd, 0.85 }

    local far_outline = {
        col[1]*0.18, col[2]*0.18, col[3]*0.18, 0.85
    }

    -- ── far layer ─────────────────────────────────────────────────────────────
    limb(bones.far_shoulder, bones.far_elbow, arm_top, arm_bot, far_fill, far_outline, camera)
    limb(bones.far_elbow,    bones.far_hand,  arm_bot, hand,    far_fill, far_outline, camera)
    limb(bones.far_hip,      bones.far_knee,  leg_top, leg_bot, far_fill, far_outline, camera)
    limb(bones.far_knee,     bones.far_foot,  leg_bot, foot,    far_fill, far_outline, camera)

    -- ── torso: single wide capsule hip → chest ────────────────────────────────
    -- The capsule's rounded ends naturally bulge at hip and shoulder,
    -- giving the body silhouette without any polygon or shading tricks.
    limb(bones.hip, bones.chest, tor_bot, tor_top, fill, outline, camera)

    -- ── near layer ────────────────────────────────────────────────────────────
    limb(bones.near_hip,      bones.near_knee,  leg_top, leg_bot, fill, outline, camera)
    limb(bones.near_knee,     bones.near_foot,  leg_bot, foot,    fill, outline, camera)
    limb(bones.near_shoulder, bones.near_elbow, arm_top, arm_bot, fill, outline, camera)
    limb(bones.near_elbow,    bones.near_hand,  arm_bot, hand,    fill, outline, camera)

    -- ── secondary: breast ─────────────────────────────────────────────────────
    -- bones.breast_l / bones.breast_r are spring-driven world positions.
    -- Skin just draws them — it doesn't know or care how they were computed.
    if bones.breast_l and bones.breast_r then
        local br   = (ps.breast and ps.breast.r) or (sw * 0.32)
        local l_near = bones.left_near
        local bn   = l_near and bones.breast_l or bones.breast_r
        local bf   = l_near and bones.breast_r or bones.breast_l
        -- far breast (dimmed, behind torso near-side)
        local bfx, bfy = proj(bf, camera)
        ocirc(bfx, bfy, br * 0.82, far_fill, far_outline)
        -- near breast
        local bnx, bny = proj(bn, camera)
        ocirc(bnx, bny, br, fill, outline)
    end

    -- ── secondary: ponytail / tail ────────────────────────────────────────────
    -- bones.ponytail = array of {x,y,z} from root to tip (FK or verlet chain).
    -- Works for hair, animal tail, scarf, rope — anything that's a chain.
    if bones.ponytail and #bones.ponytail >= 2 then
        local pts  = bones.ponytail
        local n    = #pts
        local root_r = (ps.ponytail and ps.ponytail.r) or 4
        for i = 1, n-1 do
            local t1 = (i-1) / (n-1)          -- 0 = root, 1 = tip
            local t2 =  i    / (n-1)
            local r1 = root_r * (1 - t1 * 0.70)
            local r2 = root_r * (1 - t2 * 0.70)
            limb(pts[i], pts[i+1], r1, r2, fill, outline, camera)
        end
    end

    -- ── secondary: belly ─────────────────────────────────────────────────────
    -- bones.belly = single {x,y,z} spring-driven point below the chest.
    -- Used for pregnancy, fat, backpack bulge, etc.
    if bones.belly then
        local br = (ps.belly and ps.belly.r) or (hw * 0.60)
        local bx, by = proj(bones.belly, camera)
        ocirc(bx, by, br, fill, outline)
    end

    -- ── head (always on top) ──────────────────────────────────────────────────
    local hr      = rig.head_r or 17
    local hdx,hdy = proj(bones.head, camera)
    ocirc(hdx, hdy, hr, fill, outline)
end

return Soft
