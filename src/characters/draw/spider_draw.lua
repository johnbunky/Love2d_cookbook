-- draw/spider_draw.lua
-- 8 legs attached around a compact oval body.
-- Knee direction per leg: left-side legs have dir=+1, right-side dir=-1
-- (all knees splay outward from the body)

local IK = require "src.systems.ik"
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

    local bob     = hints.bob    or 0
    local squash  = hints.squash or 1

    local bx = pos.x
    local by = pos.y
    local bz = pos.z + bob

    local br  = rig.body_r   or 18
    local blen= rig.body_len or 28

    -- draw back legs first (indices 5-8), then front (1-4)
    local draw_order = {5,6,7,8, 1,2,3,4}

    for _, i in ipairs(draw_order) do
        local foot = c.stepper.feet[i]
        if foot then
            -- attachment point: offset from body centre by angle
            local ang     = rig.attach_angles[i] or 0
            local ax      = bx + math.cos(ang) * br * 0.8
            local az      = bz + math.sin(ang) * br * 0.3

            -- knee splays outward: left-side (odd) = dir 1, right-side (even) = dir -1
            local kdir = (i % 2 == 1) and 1 or -1

            local kx, kz = IK.solve2(ax, az, foot.x, foot.z, rig.ul, rig.ll, kdir)

            -- back legs slightly dimmed
            local alpha = (i >= 5) and 0.45 or 1.0
            love.graphics.setColor(col[1], col[2], col[3], alpha)
            love.graphics.setLineWidth(2)
            seg(camera, ax,by,az, kx,by,kz)
            seg(camera, kx,by,kz, foot.x,foot.y,foot.z)
        end
    end

    -- body oval
    love.graphics.setColor(col[1], col[2], col[3])
    local csx,csy = camera:toScreen(bx, by, bz)
    love.graphics.setLineWidth(2)
    love.graphics.ellipse("fill", csx, csy, blen * squash * 0.5, br * 0.55)
    love.graphics.setColor(col[1]*0.7, col[2]*0.7, col[3]*0.7)
    love.graphics.ellipse("line", csx, csy, blen * squash * 0.5, br * 0.55)

    -- eyes (two small dots at the front)
    love.graphics.setColor(0.1, 0.1, 0.1)
    local facing = c.facing
    local ex1,ey1 = camera:toScreen(bx + facing * blen*0.4,  by, bz + br*0.3)
    local ex2,ey2 = camera:toScreen(bx + facing * blen*0.35, by, bz + br*0.5)
    love.graphics.circle("fill", ex1,ey1, 2.5)
    love.graphics.circle("fill", ex2,ey2, 2.5)
end

return M
