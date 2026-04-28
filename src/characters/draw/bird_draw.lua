-- draw/bird_draw.lua
-- Horizontal body, backward-bending knees, folded wings, beak.

local IK = require "engine.ik"
local M  = {}

local function seg(cam, x1,y1,z1, x2,y2,z2)
    local sx1,sy1 = cam:toScreen(x1,y1,z1)
    local sx2,sy2 = cam:toScreen(x2,y2,z2)
    love.graphics.line(sx1,sy1, sx2,sy2)
    love.graphics.circle("fill", sx2,sy2, 3)
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
    local squash  = hints.squash     or 1
    local waddle  = p.waddle_amp and math.sin(c.breathTimer * p.waddle_freq) * p.waddle_amp or 0

    -- body is horizontal: tail at pos.x, chest ahead
    local spine = (rig.spine or 28) * squash
    local tx = pos.x;          local tz = pos.z + bob
    local cx = tx + f * spine; local cz = tz + math.abs(waddle) * 2

    -- neck + head bob
    local neck_len = rig.neck_len or 22
    local head_bob = math.sin(swing * 2) * 3  -- birds nod head when walking
    local nx = cx + f * neck_len * 0.7
    local nz = cz + neck_len * 0.6 + head_bob

    -- beak (short line from head forward)
    local bx = nx + f * (rig.head_r or 12) * 1.4
    local bz = nz

    -- wing (folded against body, slight flap when moving)
    local wfold = rig.wing_fold or 0.85
    local wlen  = rig.wing_len  or 34
    local wflap = math.sin(swing) * (1 - wfold) * 12
    local wx    = (tx + cx) * 0.5
    local wz    = tz + wflap

    -- feet from stepper
    local f1 = c.stepper.feet[1]
    local f2 = c.stepper.feet[2]
    local ff = (f ==  1) and f2 or f1
    local bf = (f == -1) and f2 or f1

    -- IK: backward-bending knees (knee_dir=-1)
    local kdir  = -rig.knee_dir * f   -- rig.knee_dir=-1 for birds
    local fkx,fkz = IK.solve2(cx, cz, ff.x, ff.z, rig.ul, rig.ll, kdir)
    local bkx,bkz = IK.solve2(cx, cz, bf.x, bf.z, rig.ul, rig.ll, kdir)

    love.graphics.setLineWidth(2.5)

    -- === back layer ===
    love.graphics.setColor(col[1]*0.5, col[2]*0.5, col[3]*0.5, 0.40)
    seg(camera, cx,pos.y,cz, bkx,pos.y,bkz)
    seg(camera, bkx,pos.y,bkz, bf.x,bf.y,bf.z)

    -- back wing (dimmed)
    love.graphics.setColor(col[1]*0.5, col[2]*0.5, col[3]*0.5, 0.30)
    local bwx = wx + f * 6;  local bwz = wz - 4
    local ex,ey = camera:toScreen(bwx, pos.y, bwz)
    local wx2,wy2 = camera:toScreen(bwx - f*wlen*wfold*0.5, pos.y, bwz - wlen*(1-wfold)*0.5)
    love.graphics.line(ex,ey, wx2,wy2)

    -- === body ===
    love.graphics.setColor(col[1], col[2], col[3])

    -- body line (tail to chest)
    local tsx,tsy = camera:toScreen(tx, pos.y, tz)
    local csx,csy = camera:toScreen(cx, pos.y, cz)
    love.graphics.setLineWidth(4)
    love.graphics.line(tsx,tsy, csx,csy)
    love.graphics.setLineWidth(2.5)

    -- wing folded
    love.graphics.setColor(col[1], col[2], col[3], 0.7)
    local wsx,wsy = camera:toScreen(wx,     pos.y, wz)
    local wex,wey = camera:toScreen(wx - f*wlen*wfold, pos.y, wz - wlen*(1-wfold))
    love.graphics.line(wsx,wsy, wex,wey)

    -- neck
    love.graphics.setColor(col[1], col[2], col[3])
    local ncx,ncy = camera:toScreen(nx, pos.y, nz)
    love.graphics.line(csx,csy, ncx,ncy)

    -- head circle + beak
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", ncx, ncy, rig.head_r or 12)
    local bsx,bsy = camera:toScreen(bx, pos.y, bz)
    love.graphics.setLineWidth(3)
    love.graphics.line(ncx,ncy, bsx,bsy)
    love.graphics.setLineWidth(2.5)

    -- front leg
    love.graphics.setColor(col[1], col[2], col[3])
    seg(camera, cx,pos.y,cz, fkx,pos.y,fkz)
    seg(camera, fkx,pos.y,fkz, ff.x,ff.y,ff.z)
end

return M
