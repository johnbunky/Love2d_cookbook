-- src/characters/skins/face.lua
--
-- Expressive face skin. Draw on top of any body skin:
--   skins = { "soft", "face" }
--
-- All face features are placed in WORLD SPACE then projected —
-- same approach as shoulder bar endpoints in humanoid_draw.
-- Works correctly in sidescroll, 3/4, and isometric.

local Face = {}
local Draw = require "src.systems.draw2d"

-- ── expression table ──────────────────────────────────────────────────────────
local EXPR = {
    idle  = { eye_scale=1.00, pupil_dy= 0.0, brow_raise=0.0, brow_angle= 0.00, mouth_curve= 0.4, mouth_open=0 },
    walk  = { eye_scale=0.95, pupil_dy=-0.1, brow_raise=0.0, brow_angle= 0.00, mouth_curve= 0.1, mouth_open=0 },
    jump  = { eye_scale=1.30, pupil_dy=-0.3, brow_raise=1.8, brow_angle=-0.25, mouth_curve= 0.0, mouth_open=3 },
    fall  = { eye_scale=1.35, pupil_dy=-0.4, brow_raise=2.0, brow_angle=-0.30, mouth_curve=-0.2, mouth_open=4 },
    land  = { eye_scale=0.40, pupil_dy= 0.2, brow_raise=0.0, brow_angle= 0.35, mouth_curve=-0.1, mouth_open=0 },
    sit   = { eye_scale=0.75, pupil_dy= 0.1, brow_raise=0.0, brow_angle= 0.00, mouth_curve= 0.6, mouth_open=0 },
}
local EXPR_DEFAULT = EXPR.idle

local function lerp(a, b, t) return a + (b-a) * t end
local function smoothstep(t) return t*t*(3-2*t) end

local function get_state(c)
    if not c or not c.sm then return "idle" end
    for name in pairs(EXPR) do
        if c.sm:is(name) then return name end
    end
    return "idle"
end

-- ── mouth polyline (screen space, called after projection) ────────────────────
local function draw_mouth(cx, cy, w, curve, open, col, hr)
    love.graphics.setColor(col)
    love.graphics.setLineWidth(1.5)
    local segs = 8
    local top  = {}
    for i = 0, segs do
        local t = i/segs
        top[#top+1] = cx + (t-0.5)*2*w
        top[#top+1] = cy + math.sin(t*math.pi) * curve - open*0.5
    end
    love.graphics.line(top)
    if open > 0.5 then
        local bot = {}
        for i = 0, segs do
            local t = i/segs
            bot[#bot+1] = cx + (t-0.5)*2*w*0.85
            bot[#bot+1] = cy + math.sin(t*math.pi) * (curve*0.3) + open*0.5
        end
        love.graphics.line(bot)
    end
    love.graphics.setLineWidth(1)
end

-- ── update: blink + expression transition ────────────────────────────────────
function Face.update(bones, rig, profile, dt, c)
    if not c then return end
    if not c.skin_state       then c.skin_state      = {} end
    if not c.skin_state.face  then
        c.skin_state.face = {
            blink_timer = 2 + math.random()*3,
            blinking    = false,
            blink_t     = 0,
            expr_t      = 1,
            last_state  = "idle",
        }
    end
    local f   = c.skin_state.face
    local cur = get_state(c)
    if cur ~= f.last_state then
        f.last_state = cur
        f.expr_t     = 0
    end
    f.expr_t      = math.min(1, f.expr_t + dt*8)
    f.blink_timer = f.blink_timer - dt
    if f.blink_timer <= 0 and not f.blinking then
        f.blinking = true;  f.blink_t = 0
    end
    if f.blinking then
        f.blink_t = f.blink_t + dt*10
        if f.blink_t >= 1 then
            f.blinking    = false
            f.blink_t     = 0
            f.blink_timer = 2 + math.random()*3
        end
    end
end

-- ── draw ─────────────────────────────────────────────────────────────────────
function Face.draw(bones, rig, profile, camera, c)
    if not c then return end

    local pf  = profile.face or {}
    local hr  = rig.head_r   or 17
    local col = pf.skin_col  or profile.color or {0.9,0.7,0.6}

    -- ── movement direction (world space) ─────────────────────────────────────
    -- same logic as humanoid_draw: lastDx/lastDy hold the last movement direction
    local dx = c.lastDx or c.facing or 1
    local dy = c.lastDy or 0
    -- perpendicular to movement — same as shoulder bar uses
    local vx, vy = c.vel and c.vel.x or 0, c.vel and c.vel.y or 0
    local vlen = math.sqrt(vx*vx + vy*vy)
    if vlen > 4 then dx = vx/vlen; dy = vy/vlen end
    local px = -dy;  local py = dx   -- perpendicular (world)

    -- ── face plane offsets (world units) ─────────────────────────────────────
    -- fwd: how far in front of head center the face sits
    -- spread: eye separation along the perpendicular (like shoulder_w)
    -- rise: eye height above head center (z offset)
    local fwd    = pf.fwd    or hr * 0.55   -- push face forward
    local spread = pf.spread or hr * 0.32   -- half eye separation
    local rise   = pf.rise   or hr * 0.15   -- eyes above head center

    local hb = bones.head   -- head world position

    -- near/far eye world positions
    -- near eye = same side as near shoulder (left_near drives this)
    local near_sign = bones.left_near and  1 or -1
    local far_sign  = bones.left_near and -1 or  1

    local near_eye_w = {
        x = hb.x + px*spread*near_sign + dx*fwd,
        y = hb.y + py*spread*near_sign + dy*fwd,
        z = hb.z + rise,
    }
    local far_eye_w = {
        x = hb.x + px*spread*far_sign + dx*fwd,
        y = hb.y + py*spread*far_sign + dy*fwd,
        z = hb.z + rise,
    }
    -- mouth world position: forward on face, slightly below center
    local mouth_w = {
        x = hb.x + dx * fwd,
        y = hb.y + dy * fwd,
        z = hb.z - hr * 0.28,
    }
    -- brow positions: just above each eye
    local brow_rise = hr * 0.28
    local near_brow_w = { x=near_eye_w.x, y=near_eye_w.y, z=near_eye_w.z + brow_rise }
    local far_brow_w  = { x=far_eye_w.x,  y=far_eye_w.y,  z=far_eye_w.z  + brow_rise }

    -- ── project all points to screen ─────────────────────────────────────────
    local nex, ney = camera:toScreen(near_eye_w.x, near_eye_w.y, near_eye_w.z)
    local fex, fey = camera:toScreen(far_eye_w.x,  far_eye_w.y,  far_eye_w.z)
    local mox, moy = camera:toScreen(mouth_w.x,    mouth_w.y,    mouth_w.z)
    local nbx, nby = camera:toScreen(near_brow_w.x,near_brow_w.y,near_brow_w.z)
    local fbx, fby = camera:toScreen(far_brow_w.x, far_brow_w.y, far_brow_w.z)

    if not Draw.safe(nex,ney) then return end

    -- ── expression ───────────────────────────────────────────────────────────
    local f    = c.skin_state and c.skin_state.face
    local expr = EXPR[f and f.last_state or "idle"] or EXPR_DEFAULT
    local et   = f and f.expr_t or 1

    local eye_sc  = lerp(1.0,                    expr.eye_scale,   et)
    local pup_sc  = lerp(EXPR_DEFAULT.pupil_dy,  expr.pupil_dy,    et)  -- reuse var
    local pup_dy  = lerp(0,                      expr.pupil_dy,    et)
    local b_raise = lerp(0,                      expr.brow_raise,  et)
    local b_ang   = lerp(0,                      expr.brow_angle,  et)
    local m_curve = lerp(EXPR_DEFAULT.mouth_curve,expr.mouth_curve,et)
    local m_open  = lerp(0,                      expr.mouth_open,  et)

    -- blink squash
    local blink_sq = 1.0
    if f and f.blinking then
        local bt = smoothstep(math.min(1, f.blink_t*2))
        local bo = smoothstep(math.max(0, f.blink_t*2-1))
        blink_sq = math.max(0.05, 1 - bt + bo)
    end

    -- ── colors ───────────────────────────────────────────────────────────────
    local eye_col   = pf.eye_col   or {1,1,1}
    local pupil_col = pf.pupil_col or {0.10,0.10,0.15}
    local mouth_col = pf.mouth_col or {col[1]*0.55, col[2]*0.45, col[3]*0.45, 1}
    local brow_col  = pf.brow_col  or {col[1]*0.35, col[2]*0.25, col[3]*0.20, 1}
    local outline   = profile.outline_color or {col[1]*0.3, col[2]*0.3, col[3]*0.3, 1}

    local eye_r   = pf.eye_r   or hr * 0.22
    local pupil_r = pf.pupil_r or eye_r * 0.55

    -- screen-space facing vector (for pupil offset direction)
    local hx, hy = camera:toScreen(hb.x, hb.y, hb.z)
    local fx2,fy2 = camera:toScreen(hb.x+dx*10, hb.y+dy*10, hb.z)
    local sdx = fx2-hx;  local sdy = fy2-hy
    local sl  = math.sqrt(sdx*sdx+sdy*sdy)
    if sl > 0.001 then sdx=sdx/sl; sdy=sdy/sl end

    -- ── draw far eye (dimmed) ─────────────────────────────────────────────────
    local far_er = eye_r * eye_sc * 0.82
    love.graphics.setColor(eye_col[1]*0.75, eye_col[2]*0.75, eye_col[3]*0.75, 0.85)
    love.graphics.ellipse("fill", fex, fey, far_er+1.5, far_er*blink_sq+1.5)
    love.graphics.setColor(eye_col[1]*0.75, eye_col[2]*0.75, eye_col[3]*0.75, 0.85)
    love.graphics.ellipse("fill", fex, fey, far_er, far_er*blink_sq)
    -- far pupil
    love.graphics.setColor(pupil_col[1]*0.6, pupil_col[2]*0.6, pupil_col[3]*0.6, 0.85)
    love.graphics.ellipse("fill",
        fex + sdx*pupil_r*0.35, fey + sdy*pupil_r*0.35 + eye_r*pup_dy,
        pupil_r*0.82, pupil_r*0.82*blink_sq)
    -- far brow
    love.graphics.setColor(brow_col)
    love.graphics.setLineWidth(1.5)
    local fbw = far_er * 0.9
    love.graphics.line(fbx-fbw, fby-b_raise*0.7, fbx+fbw, fby-b_raise*0.7)

    -- ── draw near eye (full) ──────────────────────────────────────────────────
    local near_er = eye_r * eye_sc
    -- outline
    love.graphics.setColor(outline)
    love.graphics.ellipse("fill", nex, ney, near_er+1.5, near_er*blink_sq+1.5)
    -- white
    love.graphics.setColor(eye_col)
    love.graphics.ellipse("fill", nex, ney, near_er, near_er*blink_sq)
    -- pupil
    local px2 = nex + sdx * pupil_r * 0.38
    local py2 = ney + sdy * pupil_r * 0.38 + eye_r * eye_sc * pup_dy
    love.graphics.setColor(pupil_col)
    love.graphics.ellipse("fill", px2, py2, pupil_r, pupil_r*blink_sq)
    -- specular
    love.graphics.setColor(1,1,1,0.75)
    love.graphics.circle("fill", px2-near_er*0.22, py2-near_er*0.22, pupil_r*0.28)
    -- near brow
    love.graphics.setColor(brow_col)
    love.graphics.setLineWidth(2.0)
    local nbw = near_er * 0.9
    -- brow_angle tilts inner end up/down
    local brow_dy = b_ang * nbw
    love.graphics.line(nbx-nbw, nby - b_raise - brow_dy,
                       nbx+nbw, nby - b_raise + brow_dy)

    -- ── mouth ─────────────────────────────────────────────────────────────────
    local mouth_w2 = pf.mouth_w or hr * 0.30
    draw_mouth(mox, moy, mouth_w2, m_curve * hr * 0.18, m_open, mouth_col, hr)

    love.graphics.setLineWidth(1)
end

return Face
