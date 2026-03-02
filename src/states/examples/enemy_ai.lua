-- src/states/examples/enemy_ai.lua
-- Demonstrates: patrol, chase, attack, line-of-sight, state machine

local Utils   = require("src.utils")
local Shake   = require("src.systems.shake")
local Example = {}

local W, H
local player
local enemies   = {}
local bullets   = {}
local particles = {}
local shake
local walls     = {}

-- -------------------------
-- AI states per enemy type
-- PATROL  ? sees player ? CHASE ? in range ? ATTACK ? lost player ? SEARCH ? PATROL
-- -------------------------
local SIGHT_RANGE   = 180
local CHASE_RANGE   = 220
local ATTACK_RANGE  = 90
local SHOOT_RANGE   = 200
local LOSE_RANGE    = 280
local SEARCH_TIME   = 3.0
local PATROL_SPEED  = 55
local CHASE_SPEED   = 110
local IFRAME_TIME   = 0.5

-- -------------------------
-- Line of sight check (walls block vision)
-- -------------------------
local function hasLOS(ax, ay, bx, by)
    for _, w in ipairs(walls) do
        -- simple AABB vs segment (approximate)
        local mx = (ax + bx) / 2
        local my = (ay + by) / 2
        if Utils.rectOverlap(
            { x=math.min(ax,bx)-2, y=math.min(ay,by)-2,
              w=math.abs(bx-ax)+4, h=math.abs(by-ay)+4 },
            w) then
            -- more precise: check if wall center is near segment
            local wx = w.x + w.w/2
            local wy = w.y + w.h/2
            local dx = bx - ax
            local dy = by - ay
            local len = math.sqrt(dx*dx + dy*dy)
            if len > 0 then
                local t = ((wx-ax)*dx + (wy-ay)*dy) / (len*len)
                t = Utils.clamp(t, 0, 1)
                local px = ax + t*dx
                local py = ay + t*dy
                local dist = math.sqrt((wx-px)^2 + (wy-py)^2)
                if dist < math.max(w.w, w.h) * 0.5 then return false end
            end
        end
    end
    return true
end

local function dist(ax, ay, bx, by)
    return math.sqrt((bx-ax)^2 + (by-ay)^2)
end

local function spawnParticles(x, y, r, g, b, n)
    for _ = 1, n do
        local a = math.random() * math.pi * 2
        local s = math.random(50, 150)
        table.insert(particles, {
            x=x, y=y, vx=math.cos(a)*s, vy=math.sin(a)*s,
            life=0.35, maxLife=0.35, r=r, g=g, b=b,
        })
    end
end

-- -------------------------
-- Enemy types
-- -------------------------
local function newPatroller(x, y, p1x, p1y, p2x, p2y)
    return {
        type    = "patroller",
        x=x, y=y, w=24, h=24,
        hp=3, maxHp=3,
        vx=0, vy=0,
        state   = "patrol",
        stateT  = 0,
        flash   = 0,
        iframes = 0,
        angle   = 0,
        -- patrol waypoints
        wp      = { {x=p1x,y=p1y}, {x=p2x,y=p2y} },
        wpIdx   = 1,
        lastSeenX = 0, lastSeenY = 0,
        shootCd = 0,
        color   = {0.85, 0.35, 0.2},
    }
end

local function newGuard(x, y)
    return {
        type    = "guard",
        x=x, y=y, w=26, h=26,
        hp=5, maxHp=5,
        vx=0, vy=0,
        state   = "patrol",
        stateT  = 0,
        flash   = 0,
        iframes = 0,
        angle   = 0,
        wp      = { {x=x,y=y} },
        wpIdx   = 1,
        lastSeenX = 0, lastSeenY = 0,
        shootCd = 0,
        color   = {0.3, 0.5, 0.9},
        attackCd= 0,
    }
end

local function spawnLevel()
    -- Walls
    walls = {
        { x=150, y=100, w=20, h=200 },
        { x=400, y=80,  w=20, h=180 },
        { x=550, y=200, w=180, h=20 },
        { x=200, y=350, w=180, h=20 },
        { x=500, y=350, w=20,  h=180 },
        { x=100, y=480, w=280, h=20 },
    }

    enemies = {
        newPatroller(80,  60,  80,  60,  80,  300),
        newPatroller(460, 60,  300, 60,  600, 60),
        newPatroller(620, 280, 620, 220, 620, 500),
        newGuard(320, 200),
        newGuard(320, 450),
    }
end

function Example.enter()
    W = love.graphics.getWidth()
    H = love.graphics.getHeight()

    player = {
        x=350, y=300, w=24, h=24,
        speed=170, hp=6, maxHp=6,
        iframes=0, angle=0,
    }
    particles = {}
    bullets   = {}
    shake     = Shake.new({ decay=7 })
    spawnLevel()
end

function Example.exit() end

-- -------------------------
-- Enemy AI update
-- -------------------------
local function updateEnemy(e, p, dt)
    local ex = e.x + e.w/2
    local ey = e.y + e.h/2
    local px = p.x + p.w/2
    local py = p.y + p.h/2
    local d  = dist(ex, ey, px, py)
    local los = hasLOS(ex, ey, px, py)

    e.flash   = math.max(0, e.flash - dt)
    e.iframes = math.max(0, e.iframes - dt)
    e.shootCd = math.max(0, e.shootCd - dt)
    if e.attackCd then e.attackCd = math.max(0, e.attackCd - dt) end

    -- ---- State transitions ----
    if e.state == "patrol" then
        if d < SIGHT_RANGE and los then
            e.state = "chase"
            e.lastSeenX, e.lastSeenY = px, py
        end

    elseif e.state == "chase" then
        if los then e.lastSeenX, e.lastSeenY = px, py end
        if d > LOSE_RANGE then
            e.state  = "search"
            e.stateT = SEARCH_TIME
        elseif e.type == "guard" and d < ATTACK_RANGE then
            e.state = "attack"
        elseif e.type == "patroller" and d < SHOOT_RANGE and los then
            e.state = "attack"
        end

    elseif e.state == "attack" then
        if los then e.lastSeenX, e.lastSeenY = px, py end
        if d > (e.type == "guard" and ATTACK_RANGE*1.3 or SHOOT_RANGE*1.2) then
            e.state = "chase"
        end

    elseif e.state == "search" then
        e.stateT = e.stateT - dt
        if e.stateT <= 0 then
            e.state = "patrol"
        end
        if d < SIGHT_RANGE and los then
            e.state = "chase"
        end
    end

    -- ---- State behaviours ----
    local moveX, moveY = 0, 0

    if e.state == "patrol" then
        local wp = e.wp[e.wpIdx]
        local tdx = wp.x - ex
        local tdy = wp.y - ey
        local td  = math.sqrt(tdx*tdx + tdy*tdy)
        if td < 12 then
            e.wpIdx = (e.wpIdx % #e.wp) + 1
        else
            moveX = (tdx/td) * PATROL_SPEED
            moveY = (tdy/td) * PATROL_SPEED
            e.angle = math.atan2(tdy, tdx)
        end

    elseif e.state == "chase" then
        local tdx = e.lastSeenX - ex
        local tdy = e.lastSeenY - ey
        local td  = math.sqrt(tdx*tdx + tdy*tdy)
        if td > 8 then
            moveX = (tdx/td) * CHASE_SPEED
            moveY = (tdy/td) * CHASE_SPEED
            e.angle = math.atan2(tdy, tdx)
        end

    elseif e.state == "attack" then
        e.angle = math.atan2(py-ey, px-ex)

        if e.type == "patroller" then
            -- Ranged: shoot at player
            if e.shootCd <= 0 and los then
                e.shootCd = 1.2
                local da = e.angle + (math.random()-0.5)*0.3  -- slight spread
                table.insert(bullets, {
                    x=ex, y=ey,
                    vx=math.cos(da)*280, vy=math.sin(da)*280,
                    life=1.4, fromEnemy=true,
                })
            end
            -- Keep distance
            if d < SHOOT_RANGE * 0.6 then
                moveX = -math.cos(e.angle) * CHASE_SPEED * 0.7
                moveY = -math.sin(e.angle) * CHASE_SPEED * 0.7
            end

        elseif e.type == "guard" then
            -- Melee: charge and swipe
            if d < ATTACK_RANGE then
                if e.attackCd <= 0 then
                    e.attackCd = 0.9
                    -- knockback player
                    if Utils.rectOverlap(e, p) then
                        Shake.add(shake, 0.35)
                        p.hp = p.hp - 1
                        p.iframes = IFRAME_TIME
                        spawnParticles(px, py, 0.3, 0.6, 1, 8)
                    end
                end
            else
                moveX = math.cos(e.angle) * CHASE_SPEED * 1.2
                moveY = math.sin(e.angle) * CHASE_SPEED * 1.2
            end
        end

    elseif e.state == "search" then
        -- Wander toward last seen position
        local tdx = e.lastSeenX - ex
        local tdy = e.lastSeenY - ey
        local td  = math.sqrt(tdx*tdx + tdy*tdy)
        if td > 16 then
            moveX = (tdx/td) * PATROL_SPEED * 0.7
            moveY = (tdy/td) * PATROL_SPEED * 0.7
            e.angle = math.atan2(tdy, tdx)
        end
    end

    -- Apply movement
    e.x = Utils.clamp(e.x + moveX*dt, 0, W-e.w)
    e.y = Utils.clamp(e.y + moveY*dt, 0, H-e.h)
end

function Example.update(dt)
    local p = player

    -- Player movement
    local dx, dy = 0, 0
    if Input.isDown("left")  then dx = dx - 1 end
    if Input.isDown("right") then dx = dx + 1 end
    if Input.isDown("up")    then dy = dy - 1 end
    if Input.isDown("down")  then dy = dy + 1 end
    if dx ~= 0 and dy ~= 0 then dx=dx*0.7071; dy=dy*0.7071 end

    local newX = Utils.clamp(p.x + dx*p.speed*dt, 0, W-p.w)
    local newY = Utils.clamp(p.y + dy*p.speed*dt, 0, H-p.h)

    -- Wall collision
    local blocked = false
    for _, w in ipairs(walls) do
        if Utils.rectOverlap({x=newX, y=p.y, w=p.w, h=p.h}, w) then newX = p.x end
        if Utils.rectOverlap({x=newX, y=newY, w=p.w, h=p.h}, w) then newY = p.y end
    end
    p.x, p.y = newX, newY

    -- Mouse aim
    local cx = p.x + p.w/2
    local cy = p.y + p.h/2
    p.angle = math.atan2(Input.mouseY-cy, Input.mouseX-cx)
    p.iframes = math.max(0, p.iframes - dt)

    -- Update enemies
    for i = #enemies, 1, -1 do
        local e = enemies[i]
        updateEnemy(e, p, dt)
        if e.hp <= 0 then table.remove(enemies, i) end
    end

    -- Bullets (enemy projectiles)
    for i = #bullets, 1, -1 do
        local b = bullets[i]
        b.x = b.x + b.vx*dt
        b.y = b.y + b.vy*dt
        b.life = b.life - dt
        local hit = false
        -- Wall collision
        for _, w in ipairs(walls) do
            if Utils.rectOverlap({x=b.x-4,y=b.y-4,w=8,h=8}, w) then
                spawnParticles(b.x, b.y, 0.9, 0.5, 0.1, 3)
                hit = true; break
            end
        end
        -- Player hit
        if not hit and b.fromEnemy and p.iframes <= 0
        and Utils.rectOverlap({x=b.x-4,y=b.y-4,w=8,h=8}, p) then
            p.hp = p.hp - 1
            p.iframes = IFRAME_TIME
            Shake.add(shake, 0.3)
            spawnParticles(cx, cy, 0.9, 0.3, 0.3, 8)
            hit = true
        end
        if hit or b.life <= 0 or
           b.x<0 or b.x>W or b.y<0 or b.y>H then
            table.remove(bullets, i)
        end
    end

    -- Particles
    for i = #particles, 1, -1 do
        local pt = particles[i]
        pt.x = pt.x + pt.vx*dt
        pt.y = pt.y + pt.vy*dt
        pt.life = pt.life - dt
        if pt.life <= 0 then table.remove(particles, i) end
    end

    if p.hp <= 0 then
        Gamestate.switch(States.gameover, Example)
        return
    end

    if #enemies == 0 then
        spawnLevel()  -- respawn for demo
    end

    Shake.update(shake, dt)
end

-- State color coding
local stateColors = {
    patrol  = {0.3, 0.8, 0.3},
    chase   = {0.9, 0.7, 0.1},
    attack  = {0.9, 0.2, 0.2},
    search  = {0.4, 0.4, 0.9},
}

function Example.draw()
    Shake.apply(shake, W, H)

    love.graphics.setColor(0.08, 0.10, 0.14)
    love.graphics.rectangle("fill", 0, 0, W, H)

    -- Walls
    for _, w in ipairs(walls) do
        love.graphics.setColor(0.3, 0.35, 0.45)
        love.graphics.rectangle("fill", w.x, w.y, w.w, w.h)
        love.graphics.setColor(0.45, 0.5, 0.6)
        love.graphics.rectangle("line", w.x, w.y, w.w, w.h)
    end

    -- Particles
    for _, pt in ipairs(particles) do
        local a = pt.life/pt.maxLife
        love.graphics.setColor(pt.r, pt.g, pt.b, a)
        love.graphics.circle("fill", pt.x, pt.y, 3*a)
    end

    -- Bullets
    for _, b in ipairs(bullets) do
        love.graphics.setColor(0.9, 0.5, 0.1)
        love.graphics.circle("fill", b.x, b.y, 4)
    end

    -- Enemies
    for _, e in ipairs(enemies) do
        local ex = e.x + e.w/2
        local ey = e.y + e.h/2
        local sc = stateColors[e.state] or {1,1,1}

        -- Sight range circle (faint)
        if e.state == "patrol" or e.state == "search" then
            love.graphics.setColor(sc[1], sc[2], sc[3], 0.06)
            love.graphics.circle("fill", ex, ey, SIGHT_RANGE)
        end

        -- Body
        local r = e.flash>0 and 1   or e.color[1]
        local g = e.flash>0 and 0.5 or e.color[2]
        local b = e.flash>0 and 0.2 or e.color[3]
        love.graphics.setColor(r, g, b)
        love.graphics.rectangle("fill", e.x, e.y, e.w, e.h, 4, 4)

        -- State indicator dot
        love.graphics.setColor(sc)
        love.graphics.circle("fill", ex, e.y-8, 4)

        -- Facing direction
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.line(ex, ey,
            ex + math.cos(e.angle)*16,
            ey + math.sin(e.angle)*16)

        -- HP bar
        love.graphics.setColor(0.15, 0.15, 0.15)
        love.graphics.rectangle("fill", e.x, e.y-5, e.w, 3)
        love.graphics.setColor(e.color)
        love.graphics.rectangle("fill", e.x, e.y-5, e.w*(e.hp/e.maxHp), 3)

        -- State label (small)
        love.graphics.setColor(sc[1], sc[2], sc[3], 0.9)
        love.graphics.print(e.state, e.x, e.y - 20)
    end

    -- Player
    local p  = player
    local cx = p.x + p.w/2
    local cy = p.y + p.h/2
    local showP = p.iframes <= 0 or (math.floor(p.iframes*10)%2==0)
    if showP then
        love.graphics.setColor(0.25, 0.8, 1.0)
        love.graphics.rectangle("fill", p.x, p.y, p.w, p.h, 5, 5)
        love.graphics.setColor(0.5, 0.95, 1.0)
        love.graphics.rectangle("line", p.x, p.y, p.w, p.h, 5, 5)
        -- facing line
        love.graphics.setColor(1, 1, 1, 0.6)
        love.graphics.line(cx, cy,
            cx+math.cos(p.angle)*20, cy+math.sin(p.angle)*20)
    end

    Shake.clear()

    -- Player HP hearts
    for i = 1, p.maxHp do
        if i <= p.hp then love.graphics.setColor(0.9, 0.2, 0.2)
        else love.graphics.setColor(0.25, 0.25, 0.3) end
        love.graphics.circle("fill", 14 + (i-1)*18, 22, 6)
    end

    -- Legend
    love.graphics.setColor(0.25, 0.25, 0.3)
    love.graphics.rectangle("fill", W-200, 30, 190, 110, 4,4)
    local legend = {
        {"patrol",  "Patrolling"},
        {"chase",   "Chasing"},
        {"attack",  "Attacking"},
        {"search",  "Searching"},
    }
    for i, l in ipairs(legend) do
        local sc = stateColors[l[1]]
        love.graphics.setColor(sc)
        love.graphics.circle("fill", W-185, 44+(i-1)*22, 5)
        love.graphics.setColor(0.8,0.8,0.8)
        love.graphics.print(l[2], W-175, 37+(i-1)*22)
    end
    love.graphics.setColor(0.4,0.4,0.5)
    love.graphics.print("? orange = ranged", W-185, H-55)
    love.graphics.print("? blue   = melee",  W-185, H-38)

    Utils.drawHUD("ENEMY AI",
        "WASD move    Mouse aim    R reset    P pause    ESC back")
end

function Example.keypressed(key)
    if key == "r" then spawnLevel() end
    Utils.handlePause(key, Example)
end

return Example
