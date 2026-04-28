-- draw/humanoid_draw.lua
-- Humanoid with hip bar, shoulder bar, and limbs attached to their edges.

local IK = require "src.systems.ik"
local M  = {}

local function seg(cam, x1,y1,z1, x2,y2,z2)
    local sx1,sy1 = cam:toScreen(x1,y1,z1)
    local sx2,sy2 = cam:toScreen(x2,y2,z2)
    love.graphics.line(sx1,sy1, sx2,sy2)
    love.graphics.circle("fill", sx2,sy2, 4)
end

local function dot(cam, x,y,z, r)
    local sx,sy = cam:toScreen(x,y,z)
    love.graphics.circle("fill", sx,sy, r or 4)
end

function M.render(c, hints, camera)
    hints = hints or {}
    local p   = c.profile
    local rig = c.rig
    local pos = c.pos
    local col = p.color
    local f   = c.facing

    local swing   = hints.swingAngle or 0
    local bob     = hints.bob        or 0
    local lean    = hints.lean       or 0
    local squash  = hints.squash     or 1
    local sway    = hints.sway       or 0
    local wave    = hints.wave       or 0   -- forward/back hip oscillation
    local spExtra = hints.spineExtra or 0
    local airTuck = hints.airTuck    or 0
    local legExt  = hints.legExtend  or 0

    -- proportions: profile.body overrides rig defaults
    local b    = p.body or {}
    local rig2 = {
        spine      = b.spine      or rig.spine      or 60,
        head_r     = b.head_r     or rig.head_r     or 17,
        ul         = b.ul         or rig.ul         or 52,
        ll         = b.ll         or rig.ll         or 46,
        ua         = b.ua         or rig.ua         or 36,
        la         = b.la         or rig.la         or 30,
        hip_w      = b.hip_w      or rig.hip_w      or 18,
        shoulder_w = b.shoulder_w or rig.shoulder_w or 22,
        knee_dir   = rig.knee_dir or 1,
    }
    rig = rig2   -- shadow rig with merged values

    local spineLen = (rig.spine + spExtra) * squash
    local hw = rig.hip_w
    local sw = rig.shoulder_w

    -- movement direction — computed first, needed for hip wave and lean
    local vx, vy = c.vel.x, c.vel.y
    local vlen   = math.sqrt(vx*vx + vy*vy)
    local dx, dy
    if vlen > 4 then
        dx, dy = vx/vlen, vy/vlen
        c.lastDx, c.lastDy = dx, dy   -- remember last movement direction
    else
        dx, dy = c.lastDx or f, c.lastDy or 0   -- hold orientation after stopping
    end
    local px, py = -dy, dx   -- hip bar perpendicular

    -- hip centre: sway shifts perpendicular, wave shifts along movement direction
    local hx = pos.x + sway + dx * wave
    local hy = pos.y         + dy * wave
    local hz = pos.z + bob

    -- shoulder centre: lean in movement direction + posture arch
    -- arch > 0 = chest forward (shoulders pulled back), like feminine upright posture
    -- arch < 0 = hunch (shoulders forward), like elderly or tired posture
    local arch       = p.posture_arch or 0
    local lean_dist  = math.sin(lean) * spineLen
    -- arch offsets shoulder perpendicular to lean direction (back = -dx, -dy)
    local arch_dist  = math.sin(arch) * spineLen * 0.4
    local sx = hx + dx * lean_dist - dx * arch_dist
    local sy = hy + dy * lean_dist - dy * arch_dist
    local sz = hz + math.cos(lean) * spineLen + math.sin(math.abs(arch)) * spineLen * 0.06

    -- shoulder bar perpendicular: rotated by shoulderRotate for counter-rotation
    local sr    = hints.shoulderRotate or 0
    local cos_r = math.cos(sr)
    local sin_r = math.sin(sr)
    local spx   = px * cos_r - py * sin_r
    local spy   = px * sin_r + py * cos_r

    -- hip bar: optionally rotated (woman's hip sway)
    local hr_ang  = hints.hipRotate or 0
    local hcos    = math.cos(hr_ang); local hsin = math.sin(hr_ang)
    local hpx     = px*hcos - py*hsin
    local hpy     = px*hsin + py*hcos
    local hl_x = hx - hpx*hw;  local hl_y = hy - hpy*hw
    local hr_x = hx + hpx*hw;  local hr_y = hy + hpy*hw
    -- shoulder bar endpoints (use rotated perpendicular spx,spy)
    local sl_x = sx - spx*sw;  local sl_y = sy - spy*sw
    local sr_x = sx + spx*sw;  local sr_y = sy + spy*sw

    -- camera depth: lower value = closer to camera = draws on top
    local function camDepth(wx, wy)
        if camera.view == "isometric"    then return wx + wy
        elseif camera.view == "threequarter" then return wy
        else return -wx * f  end  -- sidescroll: facing side is front
    end

    -- left/right side of hip bar — stable, smooth, never flickers
    -- near side = HIGHER camDepth in 3/4 and iso (camera looks from low Y)
    local left_near = camDepth(hl_x, hl_y) >= camDepth(hr_x, hr_y)

    -- near-side hip/shoulder endpoints
    local hn_x = left_near and hl_x or hr_x;  local hn_y = left_near and hl_y or hr_y
    local hf_x = left_near and hr_x or hl_x;  local hf_y = left_near and hr_y or hl_y
    local sn_x = left_near and sl_x or sr_x;  local sn_y = left_near and sl_y or sr_y
    local sf_x = left_near and sr_x or sl_x;  local sf_y = left_near and sr_y or sl_y

    -- assign feet by proximity to near/far hip attachment
    local f1 = c.stepper.feet[1]
    local f2 = c.stepper.feet[2]
    local d1n = (f1.x-hn_x)^2 + (f1.y-hn_y)^2
    local d1f = (f1.x-hf_x)^2 + (f1.y-hf_y)^2
    local fn, ff   -- near foot, far foot
    if d1n <= d1f then fn=f1; ff=f2 else fn=f2; ff=f1 end

    -- IK foot targets: adjust z for tuck (pull up) and extend (push down)
    local tuck_lift = airTuck * (rig.ul + rig.ll) * 0.55
    local ext_drop  = legExt  * (rig.ul + rig.ll) * 0.12

    local fn_fz = fn.z + tuck_lift - ext_drop
    local ff_fz = ff.z + tuck_lift - ext_drop

    local nkx,nky,nkz = IK.solveLeg(hn_x,hn_y,hz, fn.x,fn.y,fn_fz, rig.ul,rig.ll, dx,dy)
    local fkx,fky,fkz = IK.solveLeg(hf_x,hf_y,hz, ff.x,ff.y,ff_fz, rig.ul,rig.ll, dx,dy)

    -- arms: FK chain from shoulder endpoint.
    -- Simple forward-kinematics avoids IK pole-vector issues entirely.
    -- Elbow z = shoulder_z - ua, hand z = elbow_z - la (arms hang straight down at rest).
    -- Swing offset (as) moves elbow and hand forward/back along movement direction.
    local as  = swing * f
    local nex = sn_x + dx*(as* 35);  local ney = sn_y + dy*(as* 35);  local nez = sz - rig.ua
    local nhx = nex  + dx*(as* 18);  local nhy = ney  + dy*(as* 18);  local nhz = nez - rig.la
    local fex = sf_x + dx*(as*-35);  local fey = sf_y + dy*(as*-35);  local fez = sz - rig.ua
    local fhx = fex  + dx*(as*-18);  local fhy = fey  + dy*(as*-18);  local fhz = fez - rig.la

    love.graphics.setLineWidth(3)

    -- === far layer (dimmed) ===
    love.graphics.setColor(col[1]*0.5, col[2]*0.5, col[3]*0.5, 0.42)
    seg(camera, sf_x,sf_y,sz,  fex,fey,fez)
    seg(camera, fex,fey,fez,   fhx,fhy,fhz)
    seg(camera, hf_x,hf_y,hz,  fkx,fky,fkz)
    seg(camera, fkx,fky,fkz,   ff.x,ff.y,ff_fz)

    -- === spine + bars ===
    love.graphics.setColor(col[1], col[2], col[3])
    local chx,chy = camera:toScreen(hx,hy,hz)
    local csx,csy = camera:toScreen(sx,sy,sz)
    love.graphics.setLineWidth(3)
    love.graphics.line(chx,chy, csx,csy)

    -- hip bar
    local hbsx1,hbsy1 = camera:toScreen(hl_x,hl_y,hz)
    local hbsx2,hbsy2 = camera:toScreen(hr_x,hr_y,hz)
    love.graphics.setLineWidth(4)
    love.graphics.line(hbsx1,hbsy1, hbsx2,hbsy2)
    love.graphics.circle("fill", hbsx1,hbsy1, 5)
    love.graphics.circle("fill", hbsx2,hbsy2, 5)

    -- shoulder bar
    local sbsx1,sbsy1 = camera:toScreen(sl_x,sl_y,sz)
    local sbsx2,sbsy2 = camera:toScreen(sr_x,sr_y,sz)
    love.graphics.setLineWidth(4)
    love.graphics.line(sbsx1,sbsy1, sbsx2,sbsy2)
    love.graphics.circle("fill", sbsx1,sbsy1, 5)
    love.graphics.circle("fill", sbsx2,sbsy2, 5)
    love.graphics.setLineWidth(3)

    -- head
    love.graphics.setLineWidth(2)
    local hdx,hdy = camera:toScreen(sx,sy, sz + rig.head_r)
    love.graphics.circle("line", hdx,hdy, rig.head_r)
    love.graphics.setLineWidth(3)

    -- breast: two circles at shoulder bar, slightly forward, upper torso
    if p.breast and c.springs and c.springs.breast_l then
        local size  = rig.head_r * 0.55
        local fwd   = 6   -- pixels forward in facing direction

        -- positions: shoulder bar endpoints, pushed forward
        local lx = sl_x + dx * fwd * f;  local ly = sl_y + dy * fwd * f
        local rx = sr_x + dx * fwd * f;  local ry = sr_y + dy * fwd * f
        local lz = sz - 4 + c.springs.breast_l.value
        local rz = sz - 4 + c.springs.breast_r.value

        -- near/far
        local l_near = camDepth(lx, ly) >= camDepth(rx, ry)
        local nx2,ny2,nz2 = l_near and lx or rx, l_near and ly or ry, l_near and lz or rz
        local fx2,fy2,fz2 = l_near and rx or lx, l_near and ry or ly, l_near and rz or lz

        love.graphics.setColor(col[1]*0.5, col[2]*0.5, col[3]*0.5, 0.42)
        local bfx,bfy = camera:toScreen(fx2, fy2, fz2)
        love.graphics.circle("fill", bfx, bfy, size * 0.85)

        love.graphics.setColor(col[1], col[2], col[3])
        local bnx,bny = camera:toScreen(nx2, ny2, nz2)
        love.graphics.circle("fill", bnx, bny, size)
    end

    -- === near layer (full brightness) ===
    love.graphics.setColor(col[1], col[2], col[3])
    seg(camera, hn_x,hn_y,hz,  nkx,nky,nkz)
    seg(camera, nkx,nky,nkz,   fn.x,fn.y,fn_fz)
    seg(camera, sn_x,sn_y,sz,  nex,ney,nez)
    seg(camera, nex,ney,nez,   nhx,nhy,nhz)

    -- === DEBUG: hold G ===
    if love.keyboard.isDown("g") then
        local function dbdot(wx,wy,wz, r, cr,cg,cb)
            local sx,sy = camera:toScreen(wx,wy,wz)
            love.graphics.setColor(cr,cg,cb,1)
            love.graphics.circle("fill", sx,sy, r)
            love.graphics.setColor(1,1,1,0.6)
            love.graphics.print(string.format("%.0f,%.0f,%.0f",wx,wy,wz), sx+4,sy-5, 0,0.65)
        end

        -- LEGS
        dbdot(hn_x,hn_y,hz,   6, 1,1,0)       -- near hip attach  (yellow)
        dbdot(hf_x,hf_y,hz,   6, 0.7,0.7,0)   -- far  hip attach  (dark yellow)
        dbdot(fn.x,fn.y,fn.z, 6, 0,1,1)        -- near foot        (cyan)
        dbdot(ff.x,ff.y,ff.z, 6, 0.3,0.3,1)   -- far  foot        (blue)
        dbdot(nkx,nky,nkz,    5, 0,1,0)        -- near knee        (green)
        dbdot(fkx,fky,fkz,    5, 1,0,0)        -- far  knee        (red)

        -- ARMS (FK)
        dbdot(sn_x,sn_y,sz,   6, 1,0.5,0)      -- near shoulder attach  (orange)
        dbdot(sf_x,sf_y,sz,   6, 0.6,0.3,0)    -- far  shoulder attach  (dark orange)
        dbdot(nex,ney,nez,     5, 1,0,1)        -- near elbow            (magenta)
        dbdot(fex,fey,fez,     5, 0.6,0,0.6)   -- far  elbow            (dark magenta)
        dbdot(nhx,nhy,nhz,     5, 0.5,1,0.5)   -- near hand             (light green)
        dbdot(fhx,fhy,fhz,     5, 0.2,0.6,0.2) -- far  hand             (dark green)

        -- velocity arrow
        love.graphics.setColor(1,0.5,0,0.9)
        love.graphics.setLineWidth(2)
        local ax,ay   = camera:toScreen(hx,hy,hz)
        local bx2,by2 = camera:toScreen(hx+c.vel.x*0.3, hy+c.vel.y*0.3, hz)
        love.graphics.line(ax,ay, bx2,by2)

        love.graphics.setColor(1,1,1,0.85)
        love.graphics.print(string.format(
            "facing:%+d  vx:%+.0f vy:%+.0f\n"..
            "dx:%.2f dy:%.2f  near:%s\n"..
            "--- LEGS ---\n"..
            "hn(%.0f,%.0f,%.0f)  hf(%.0f,%.0f,%.0f)\n"..
            "fn(%.0f,%.0f,%.0f)  ff(%.0f,%.0f,%.0f)\n"..
            "nk(%.0f,%.0f,%.0f)  fk(%.0f,%.0f,%.0f)\n"..
            "--- ARMS (FK) ---\n"..
            "sn(%.0f,%.0f,%.0f)  sf(%.0f,%.0f,%.0f)\n"..
            "ne(%.0f,%.0f,%.0f)  fe(%.0f,%.0f,%.0f)\n"..
            "nh(%.0f,%.0f,%.0f)  fh(%.0f,%.0f,%.0f)",
            f, c.vel.x, c.vel.y, dx, dy, tostring(left_near),
            hn_x,hn_y,hz,  hf_x,hf_y,hz,
            fn.x,fn.y,fn.z, ff.x,ff.y,ff.z,
            nkx,nky,nkz,    fkx,fky,fkz,
            sn_x,sn_y,sz,  sf_x,sf_y,sz,
            nex,ney,nez,    fex,fey,fez,
            nhx,nhy,nhz,    fhx,fhy,fhz
        ), 8, 75)
    end

end

return M
