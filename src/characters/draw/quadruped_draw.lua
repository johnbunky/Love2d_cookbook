-- draw/quadruped_draw.lua
-- Four-legged body. Uses IK.solveLeg for correct 3D knees.
-- Feet: 1=front-left, 2=front-right, 3=back-left, 4=back-right

local IK = require "src.systems.ik"
local M  = {}

local function seg(cam, x1,y1,z1, x2,y2,z2)
    local sx1,sy1 = cam:toScreen(x1,y1,z1)
    local sx2,sy2 = cam:toScreen(x2,y2,z2)
    love.graphics.line(sx1,sy1, sx2,sy2)
    love.graphics.circle("fill", sx2,sy2, 4)
end

local function camDepth(camera, wx, wy, f)
    if camera.view == "isometric"        then return  wx + wy
    elseif camera.view == "threequarter" then return  wy
    else return wx * f end
end

function M.render(c, hints, camera)
    hints = hints or {}
    local p   = c.profile
    local rig = c.rig
    local pos = c.pos
    local col = p.color
    local f   = c.facing

    local swing  = hints.swingAngle or 0
    local bob    = hints.bob        or 0
    local squash = hints.squash     or 1

    -- movement direction (same logic as humanoid)
    local vx, vy = c.vel.x, c.vel.y
    local vlen   = math.sqrt(vx*vx + vy*vy)
    local dx, dy
    if vlen > 4 then dx, dy = vx/vlen, vy/vlen
    else              dx, dy = f, 0 end
    local px, py = -dy, dx   -- perpendicular

    local body_len = rig.body_len or 70
    local hw       = rig.hip_w    or 12

    -- hip rotation: rear hip rotates with stride, front counter-rotates
    -- produces the characteristic rolling gait of quadrupeds
    local hip_rot   = p.hip_rotation or 0.3
    local rear_rot  = math.sin(swing) * hip_rot
    local front_rot = -rear_rot * 0.6   -- front opposes rear, smaller amplitude

    local function rotPerp(base_px, base_py, angle)
        local c2 = math.cos(angle); local s2 = math.sin(angle)
        return base_px*c2 - base_py*s2,
               base_px*s2 + base_py*c2
    end
    local rpx, rpy = rotPerp(px, py, rear_rot)
    local fpx, fpy = rotPerp(px, py, front_rot)

    -- rear hip = physics position
    local rx, ry, rz = pos.x, pos.y, pos.z + bob

    -- front hip = body_len ahead in movement direction
    local fx = rx + dx * body_len * squash
    local fy = ry + dy * body_len * squash
    local fz = rz + math.sin(swing * 0.3) * 6

    -- spine midpoint arcs upward
    local mx = (rx+fx)*0.5
    local my = (ry+fy)*0.5
    local mz = (rz+fz)*0.5 + (rig.spine_h or 20)

    -- neck + head — nz goes UP (positive z) from front hip
    local neck_len = rig.neck_len or 28
    local nang     = rig.neck_ang or -0.5
    local nx = fx + dx * math.cos(math.abs(nang)) * neck_len
    local ny = fy + dy * math.cos(math.abs(nang)) * neck_len
    local nz = fz - math.sin(nang) * neck_len   -- nang negative = head goes UP

    -- tail FK from rear hip, swings with stride
    local tail_segs = {}
    if rig.tail then
        local tx, ty, tz = rx, ry, rz
        for i, sd in ipairs(rig.tail) do
            local wave   = math.sin(swing + i * 0.8) * 0.3
            local ex = tx - dx * sd.length + py * wave * sd.length * 0.5
            local ey = ty - dy * sd.length - px * wave * sd.length * 0.5
            local ez = tz + math.abs(wave) * sd.length * 0.2
            tail_segs[#tail_segs+1] = {px=tx,py=ty,pz=tz, x=ex,y=ey,z=ez}
            tx,ty,tz = ex,ey,ez
        end
    end

    -- expose hip positions for stepper (quadruped needs front+rear separately)
    c.rear_hip  = {x=rx, y=ry, z=rz}
    c.front_hip = {x=fx, y=fy, z=fz}

    -- hip bar endpoints using rotated perpendiculars
    local rhl_x=rx-rpx*hw; local rhl_y=ry-rpy*hw
    local rhr_x=rx+rpx*hw; local rhr_y=ry+rpy*hw
    local fhl_x=fx-fpx*hw; local fhl_y=fy-fpy*hw
    local fhr_x=fx+fpx*hw; local fhr_y=fy+fpy*hw

    -- near/far side per hip (camera depth)
    local r_left_near = camDepth(camera,rhl_x,rhl_y,f) >= camDepth(camera,rhr_x,rhr_y,f)
    local f_left_near = camDepth(camera,fhl_x,fhl_y,f) >= camDepth(camera,fhr_x,fhr_y,f)

    local rn_x = r_left_near and rhl_x or rhr_x; local rn_y = r_left_near and rhl_y or rhr_y
    local rf_x = r_left_near and rhr_x or rhl_x; local rf_y = r_left_near and rhr_y or rhl_y
    local fn_x = f_left_near and fhl_x or fhr_x; local fn_y = f_left_near and fhl_y or fhr_y
    local ff_x = f_left_near and fhr_x or fhl_x; local ff_y = f_left_near and fhr_y or fhl_y

    -- assign stepper feet to near/far sides by proximity
    local feet = c.stepper.feet
    -- front feet: indices 1,2
    local d1fn = (feet[1].x-fn_x)^2+(feet[1].y-fn_y)^2
    local d1ff = (feet[1].x-ff_x)^2+(feet[1].y-ff_y)^2
    local front_near, front_far
    if d1fn<=d1ff then front_near=feet[1]; front_far=feet[2]
    else               front_near=feet[2]; front_far=feet[1] end

    -- back feet: indices 3,4
    local d3rn = (feet[3].x-rn_x)^2+(feet[3].y-rn_y)^2
    local d3rf = (feet[3].x-rf_x)^2+(feet[3].y-rf_y)^2
    local back_near, back_far
    if d3rn<=d3rf then back_near=feet[3]; back_far=feet[4]
    else               back_near=feet[4]; back_far=feet[3] end

    -- IK: pole vector — front knees forward, back knees backward
    local fnkx,fnky,fnkz = IK.solveLeg(fn_x,fn_y,fz, front_near.x,front_near.y,front_near.z, rig.f_ul,rig.f_ll, dx,dy)
    local ffkx,ffky,ffkz = IK.solveLeg(ff_x,ff_y,fz, front_far.x, front_far.y, front_far.z,  rig.f_ul,rig.f_ll, dx,dy)
    local bnkx,bnky,bnkz = IK.solveLeg(rn_x,rn_y,rz, back_near.x, back_near.y, back_near.z,  rig.b_ul,rig.b_ll, -dx,-dy)
    local bfkx,bfky,bfkz = IK.solveLeg(rf_x,rf_y,rz, back_far.x,  back_far.y,  back_far.z,   rig.b_ul,rig.b_ll, -dx,-dy)

    love.graphics.setLineWidth(3)

    local paw_r = rig.paw_r or 5

    local function paw(wx, wy, wz, alpha)
        local sx,sy = camera:toScreen(wx,wy,wz)
        love.graphics.setColor(col[1]*0.7, col[2]*0.7, col[3]*0.7, alpha)
        love.graphics.ellipse("fill", sx, sy, paw_r * 1.4, paw_r * 0.8)
        love.graphics.setColor(col[1]*0.4, col[2]*0.4, col[3]*0.4, alpha)
        love.graphics.setLineWidth(1)
        love.graphics.ellipse("line", sx, sy, paw_r * 1.4, paw_r * 0.8)
        love.graphics.setLineWidth(3)
    end

    -- === far layer (dimmed) ===
    love.graphics.setColor(col[1]*0.5, col[2]*0.5, col[3]*0.5, 0.40)

    seg(camera, ff_x,ff_y,fz,        ffkx,ffky,ffkz)
    seg(camera, ffkx,ffky,ffkz,      front_far.x,front_far.y,front_far.z)
    paw(front_far.x,front_far.y,front_far.z, 0.35)
    seg(camera, rf_x,rf_y,rz,        bfkx,bfky,bfkz)
    seg(camera, bfkx,bfky,bfkz,      back_far.x, back_far.y, back_far.z)
    paw(back_far.x,back_far.y,back_far.z, 0.35)

    -- tail
    for _, ts in ipairs(tail_segs) do
        local psx,psy = camera:toScreen(ts.px,ts.py,ts.pz)
        local esx,esy = camera:toScreen(ts.x, ts.y, ts.z)
        love.graphics.line(psx,psy, esx,esy)
        love.graphics.circle("fill", esx,esy, 3)
    end

    -- === body ===
    love.graphics.setColor(col[1], col[2], col[3])

    -- spine arc: rear → mid → front
    local rsx,rsy = camera:toScreen(rx,ry,rz)
    local msx,msy = camera:toScreen(mx,my,mz)
    local fsx,fsy = camera:toScreen(fx,fy,fz)
    love.graphics.setLineWidth(4)
    love.graphics.line(rsx,rsy, msx,msy)
    love.graphics.line(msx,msy, fsx,fsy)
    love.graphics.setLineWidth(3)

    -- hip bars (full 2-point world projection)
    local function drawBar(x1,y1, x2,y2, z)
        local sx1,sy1 = camera:toScreen(x1,y1,z)
        local sx2,sy2 = camera:toScreen(x2,y2,z)
        love.graphics.setLineWidth(4)
        love.graphics.line(sx1,sy1, sx2,sy2)
        love.graphics.circle("fill", sx1,sy1, 5)
        love.graphics.circle("fill", sx2,sy2, 5)
        love.graphics.setLineWidth(3)
    end
    drawBar(rhl_x,rhl_y, rhr_x,rhr_y, rz)
    drawBar(fhl_x,fhl_y, fhr_x,fhr_y, fz)

    -- neck + head
    local nsx,nsy = camera:toScreen(nx,ny,nz)
    love.graphics.line(fsx,fsy, nsx,nsy)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", nsx,nsy, rig.head_r or 12)
    love.graphics.setLineWidth(3)

    -- === near layer ===
    love.graphics.setColor(col[1], col[2], col[3])

    seg(camera, fn_x,fn_y,fz,        fnkx,fnky,fnkz)
    seg(camera, fnkx,fnky,fnkz,      front_near.x,front_near.y,front_near.z)
    paw(front_near.x,front_near.y,front_near.z, 1.0)
    seg(camera, rn_x,rn_y,rz,        bnkx,bnky,bnkz)
    seg(camera, bnkx,bnky,bnkz,      back_near.x, back_near.y, back_near.z)
    paw(back_near.x,back_near.y,back_near.z, 1.0)

    -- === DEBUG: hold G ===
    if love.keyboard.isDown("g") then
        local function dbdot(wx,wy,wz, r, cr,cg,cb)
            local sx,sy = camera:toScreen(wx,wy,wz)
            love.graphics.setColor(cr,cg,cb,1)
            love.graphics.circle("fill", sx,sy, r)
            love.graphics.setColor(1,1,1,0.6)
            love.graphics.print(string.format("%.0f,%.0f,%.0f",wx,wy,wz), sx+4,sy-5, 0, 0.65)
        end
        -- body pivots
        dbdot(rx,ry,rz,  6, 1,0.8,0)     -- rear hip (yellow)
        dbdot(fx,fy,fz,  6, 0.8,1,0)     -- front hip (green-yellow)
        dbdot(nx,ny,nz,  5, 0.6,0.9,1)   -- neck tip (cyan)
        -- feet: near=cyan, far=blue, front=bright, back=dim
        dbdot(front_near.x,front_near.y,front_near.z, 6, 0,1,1)
        dbdot(front_far.x, front_far.y, front_far.z,  6, 0,0.4,0.8)
        dbdot(back_near.x, back_near.y, back_near.z,  6, 0,0.8,0.5)
        dbdot(back_far.x,  back_far.y,  back_far.z,   6, 0,0.3,0.5)
        -- knees: front green, back red
        dbdot(fnkx,fnky,fnkz, 5, 0,1,0)
        dbdot(ffkx,ffky,ffkz, 5, 0,0.5,0)
        dbdot(bnkx,bnky,bnkz, 5, 1,0,0)
        dbdot(bfkx,bfky,bfkz, 5, 0.5,0,0)
        -- velocity arrow
        love.graphics.setColor(1,0.5,0,0.9)
        love.graphics.setLineWidth(1.5)
        local ax,ay = camera:toScreen(rx,ry,rz)
        local bx2,by2 = camera:toScreen(rx+c.vel.x*0.3, ry+c.vel.y*0.3, rz)
        love.graphics.line(ax,ay, bx2,by2)
        -- text
        love.graphics.setColor(1,1,1,0.85)
        love.graphics.print(string.format(
            "facing:%+d  vx:%+.0f vy:%+.0f\n"..
            "dx:%.2f dy:%.2f\n"..
            "rear(%.0f,%.0f,%.0f) front(%.0f,%.0f,%.0f)\n"..
            "fn(%.0f,%.0f) ff(%.0f,%.0f)\n"..
            "rn(%.0f,%.0f) rf(%.0f,%.0f)",
            f, c.vel.x, c.vel.y,
            dx, dy,
            rx,ry,rz, fx,fy,fz,
            fn_x,fn_y, ff_x,ff_y,
            rn_x,rn_y, rf_x,rf_y
        ), 8, 75)
    end
end

return M
