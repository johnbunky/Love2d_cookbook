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
    local wave    = hints.wave       or 0
    local spExtra = hints.spineExtra or 0
    local airTuck = hints.airTuck    or 0
    local legExt  = hints.legExtend  or 0

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
    rig = rig2

    local spineLen = (rig.spine + spExtra) * squash
    local hw = rig.hip_w
    local sw = rig.shoulder_w

    local vx, vy = c.vel.x, c.vel.y
    local vlen   = math.sqrt(vx*vx + vy*vy)
    local dx, dy
    if vlen > 4 then
        dx, dy = vx/vlen, vy/vlen
        c.lastDx, c.lastDy = dx, dy
    else
        dx, dy = c.lastDx or f, c.lastDy or 0
    end
    local px, py = -dy, dx

    local hx = pos.x + sway + dx * wave
    local hy = pos.y         + dy * wave
    local hz = pos.z + bob

    local arch       = p.posture_arch or 0
    local lean_dist  = math.sin(lean) * spineLen
    local arch_dist  = math.sin(arch) * spineLen * 0.4
    local sx = hx + dx * lean_dist - dx * arch_dist
    local sy = hy + dy * lean_dist - dy * arch_dist
    local sz = hz + math.cos(lean) * spineLen + math.sin(math.abs(arch)) * spineLen * 0.06

    local sr    = hints.shoulderRotate or 0
    local cos_r = math.cos(sr)
    local sin_r = math.sin(sr)
    local spx   = px * cos_r - py * sin_r
    local spy   = px * sin_r + py * cos_r

    local hr_ang  = hints.hipRotate or 0
    local hcos    = math.cos(hr_ang); local hsin = math.sin(hr_ang)
    local hpx     = px*hcos - py*hsin
    local hpy     = px*hsin + py*hcos
    local hl_x = hx - hpx*hw;  local hl_y = hy - hpy*hw
    local hr_x = hx + hpx*hw;  local hr_y = hy + hpy*hw
    local sl_x = sx - spx*sw;  local sl_y = sy - spy*sw
    local sr_x = sx + spx*sw;  local sr_y = sy + spy*sw

    local function camDepth(wx, wy)
        if camera.view == "isometric"        then return wx + wy
        elseif camera.view == "threequarter" then return wy
        else return -wx * f  end
    end

    local left_near = camDepth(hl_x, hl_y) >= camDepth(hr_x, hr_y)

    local hn_x = left_near and hl_x or hr_x;  local hn_y = left_near and hl_y or hr_y
    local hf_x = left_near and hr_x or hl_x;  local hf_y = left_near and hr_y or hl_y
    local sn_x = left_near and sl_x or sr_x;  local sn_y = left_near and sl_y or sr_y
    local sf_x = left_near and sr_x or sl_x;  local sf_y = left_near and sr_y or sl_y

    local f1 = c.stepper.feet[1]
    local f2 = c.stepper.feet[2]
    local d1n = (f1.x-hn_x)^2 + (f1.y-hn_y)^2
    local d1f = (f1.x-hf_x)^2 + (f1.y-hf_y)^2
    local fn, ff
    if d1n <= d1f then fn=f1; ff=f2 else fn=f2; ff=f1 end

    local tuck_lift = airTuck * (rig.ul + rig.ll) * 0.55
    local ext_drop  = legExt  * (rig.ul + rig.ll) * 0.12

    local fn_fz = fn.z + tuck_lift - ext_drop
    local ff_fz = ff.z + tuck_lift - ext_drop

    local nkx,nky,nkz = IK.solveLeg(hn_x,hn_y,hz, fn.x,fn.y,fn_fz, rig.ul,rig.ll, dx,dy)
    local fkx,fky,fkz = IK.solveLeg(hf_x,hf_y,hz, ff.x,ff.y,ff_fz, rig.ul,rig.ll, dx,dy)

    local as  = swing * f
    local nex = sn_x + dx*(as* 35);  local ney = sn_y + dy*(as* 35);  local nez = sz - rig.ua
    local nhx = nex  + dx*(as* 18);  local nhy = ney  + dy*(as* 18);  local nhz = nez - rig.la
    local fex = sf_x + dx*(as*-35);  local fey = sf_y + dy*(as*-35);  local fez = sz - rig.ua
    local fhx = fex  + dx*(as*-18);  local fhy = fey  + dy*(as*-18);  local fhz = fez - rig.la

    love.graphics.setLineWidth(3)

    -- =========================================================================
    -- SKIN STACK DISPATCH
    -- Supports both single skin and layered stack:
    --
    --   skin  = "soft"                              -- single, backward compat
    --   skins = {                                   -- layered stack
    --       "soft",
    --       { name="particles", blend="add", alpha=0.6 },
    --   }
    --
    -- blend: "alpha"(default) | "add" | "multiply" | "subtract"
    -- alpha: master opacity 0-1 (default 1)
    -- Stack cached on c._skin_stack, invalidated when profile changes.
    -- =========================================================================

    local function resolve_entries(profile)
        local raw = profile.skins or { profile.skin or "wire" }
        local out = {}
        for _, v in ipairs(raw) do
            if type(v) == "string" then
                out[#out+1] = { name=v, blend="alpha", alpha=1.0 }
            elseif type(v) == "table" and v.name then
                out[#out+1] = { name=v.name, blend=v.blend or "alpha", alpha=v.alpha or 1.0 }
            end
        end
        return out
    end

    local function stack_key(entries)
        local t = {}
        for _, e in ipairs(entries) do t[#t+1] = e.name.."|"..e.blend.."|"..e.alpha end
        return table.concat(t, "+")
    end

    local entries = resolve_entries(p)
    local key     = stack_key(entries)

    if c._skin_stack_key ~= key then
        c._skin_stack_key = key
        c._skin_stack     = {}
        for _, e in ipairs(entries) do
            local ok, mod = pcall(require, "src.characters.skins." .. e.name)
            if ok then
                c._skin_stack[#c._skin_stack+1] = { mod=mod, name=e.name, blend=e.blend, alpha=e.alpha }
            else
                print("[skin] WARNING: '" .. e.name .. "' not found, skipping")
            end
        end
        if #c._skin_stack == 0 then
            c._skin_stack[1] = { mod=require"src.characters.skins.wire", name="wire", blend="alpha", alpha=1.0 }
        end
    end

    local bones = {
        -- spine
        hip           = { x = hx,    y = hy,    z = hz              },
        chest         = { x = sx,    y = sy,    z = sz              },
        head          = { x = sx,    y = sy,    z = sz + rig.head_r },
        -- near arm
        near_shoulder = { x = sn_x,  y = sn_y,  z = sz   },
        near_elbow    = { x = nex,   y = ney,   z = nez  },
        near_hand     = { x = nhx,   y = nhy,   z = nhz  },
        -- far arm
        far_shoulder  = { x = sf_x,  y = sf_y,  z = sz   },
        far_elbow     = { x = fex,   y = fey,   z = fez  },
        far_hand      = { x = fhx,   y = fhy,   z = fhz  },
        -- near leg
        near_hip      = { x = hn_x,  y = hn_y,  z = hz    },
        near_knee     = { x = nkx,   y = nky,   z = nkz   },
        near_foot     = { x = fn.x,  y = fn.y,  z = fn_fz },
        -- far leg
        far_hip       = { x = hf_x,  y = hf_y,  z = hz    },
        far_knee      = { x = fkx,   y = fky,   z = fkz   },
        far_foot      = { x = ff.x,  y = ff.y,  z = ff_fz },
        -- full bars (wire skin draws these as thick lines)
        hip_left      = { x = hl_x,  y = hl_y,  z = hz },
        hip_right     = { x = hr_x,  y = hr_y,  z = hz },
        shoulder_left = { x = sl_x,  y = sl_y,  z = sz },
        shoulder_right = { x = sr_x, y = sr_y,  z = sz },
        -- orientation
        facing    = f,
        left_near = left_near,
    }

    -- secondary: added only when character has them.
    -- Springs live on c.springs, ticked in c:update().
    -- Skin reads what it needs and ignores the rest.

    -- breast: spring-driven z offset, only when profile.secondary.breast is defined
    if p.secondary and p.secondary.breast and c.springs.breast_l then
        local sec    = p.secondary.breast
        local b_fwd  = sec.fwd  or 12   -- forward push from chest
        local b_lat  = sw * 0.28        -- lateral spread (fraction of shoulder width)
        local b_drop = (rig.head_r or 17) * 0.45   -- drop below shoulder level

        -- anchor: chest center pushed forward, spread left/right along shoulder bar
        -- spx,spy = shoulder bar perpendicular (already computed above)
        bones.breast_l = {
            x = sx - spx * b_lat + dx * b_fwd,
            y = sy - spy * b_lat + dy * b_fwd,
            z = sz - b_drop + c.springs.breast_l.value,
        }
        bones.breast_r = {
            x = sx + spx * b_lat + dx * b_fwd,
            y = sy + spy * b_lat + dy * b_fwd,
            z = sz - b_drop + c.springs.breast_r.value,
        }
    end

    -- ponytail: verlet chain, root=head, points flow toward tip
    -- c.chain.ponytail.pts is [{x,y,z,ox,oy,oz}, ...] — skin only needs x,y,z
    if p.secondary and p.secondary.ponytail and c.chain and c.chain.ponytail then
        local pts = c.chain.ponytail.pts
        local out = {}
        for i, pt in ipairs(pts) do
            out[i] = { x=pt.x, y=pt.y, z=pt.z }
        end
        bones.ponytail = out
    end

    -- belly: single spring point below chest
    if p.secondary and p.secondary.belly and c.springs.belly then
        bones.belly = {
            x = hx,
            y = hy,
            z = hz + (rig.spine * 0.25) + c.springs.belly.value,
        }
    end

    -- run the skin stack
    local prev_blend = love.graphics.getBlendMode()
    for _, entry in ipairs(c._skin_stack) do
        -- set blend mode and master alpha
        love.graphics.setBlendMode(entry.blend)
        love.graphics.setColor(1, 1, 1, entry.alpha)   -- skins multiply into this

        -- stateful skins declare update()
        if entry.mod.update then
            entry.mod.update(bones, rig, p, hints.dt or love.timer.getDelta(), c)
        end

        entry.mod.draw(bones, rig, p, camera, c)
    end
    love.graphics.setBlendMode(prev_blend)
    love.graphics.setColor(1, 1, 1, 1)

    -- =========================================================================
    -- DEBUG: hold G  (always runs regardless of skin)
    -- =========================================================================
    if love.keyboard.isDown("g") then
        local function dbdot(wx,wy,wz, r, cr,cg,cb)
            local sx,sy = camera:toScreen(wx,wy,wz)
            love.graphics.setColor(cr,cg,cb,1)
            love.graphics.circle("fill", sx,sy, r)
            love.graphics.setColor(1,1,1,0.6)
            love.graphics.print(string.format("%.0f,%.0f,%.0f",wx,wy,wz), sx+4,sy-5, 0,0.65)
        end

        dbdot(hn_x,hn_y,hz,   6, 1,1,0)
        dbdot(hf_x,hf_y,hz,   6, 0.7,0.7,0)
        dbdot(fn.x,fn.y,fn.z, 6, 0,1,1)
        dbdot(ff.x,ff.y,ff.z, 6, 0.3,0.3,1)
        dbdot(nkx,nky,nkz,    5, 0,1,0)
        dbdot(fkx,fky,fkz,    5, 1,0,0)
        dbdot(sn_x,sn_y,sz,   6, 1,0.5,0)
        dbdot(sf_x,sf_y,sz,   6, 0.6,0.3,0)
        dbdot(nex,ney,nez,     5, 1,0,1)
        dbdot(fex,fey,fez,     5, 0.6,0,0.6)
        dbdot(nhx,nhy,nhz,     5, 0.5,1,0.5)
        dbdot(fhx,fhy,fhz,     5, 0.2,0.6,0.2)

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
