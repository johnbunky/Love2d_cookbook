-- src/states/examples/melee_attack.lua
-- Demonstrates: attack states, swing arc hitbox, knockback, i-frames, combos

local Utils   = require("src.utils")
local Shake   = require("src.systems.shake")
local Example = {}

local W, H
local player
local enemies   = {}
local particles = {}
local shake

-- Attack state machine
-- idle ? windup ? active ? recover ? idle
local WINDUP_TIME   = 0.10
local ACTIVE_TIME   = 0.12
local RECOVER_TIME  = 0.22
local COMBO_WINDOW  = 0.35   -- time after recover to chain next hit
local KNOCKBACK     = 260
local IFRAME_TIME   = 0.6
local SWORD_LEN     = 52
local SWORD_WIDTH   = 14

local function spawnEnemies()
    enemies = {}
    local positions = {
        {150,200},{500,150},{620,350},{200,400},
        {680,200},{350,480},{100,300},{580,420},
    }
    for _, pos in ipairs(positions) do
        table.insert(enemies, {
            x=pos[1], y=pos[2], w=28, h=28,
            hp=3, maxHp=3,
            vx=0, vy=0,
            flash=0,
            dead=false,
        })
    end
end

local function spawnParticles(x, y, r, g, b, count)
    for _ = 1, count do
        local angle = math.random() * math.pi * 2
        local speed = math.random(60, 180)
        table.insert(particles, {
            x=x, y=y,
            vx=math.cos(angle)*speed,
            vy=math.sin(angle)*speed,
            life=math.random(15,35)/100,
            maxLife=0.35,
            r=r, g=g, b=b,
        })
    end
end

-- Returns sword arc hitbox polygon points and a rect for overlap test
local function swordHitbox(p)
    local cx  = p.x + p.w/2
    local cy  = p.y + p.h/2
    local a   = p.angle
    local arc = math.pi * 0.55   -- sweep width

    -- rect approximation for hit detection
    local sx = cx + math.cos(a) * SWORD_LEN * 0.3
    local sy = cy + math.sin(a) * SWORD_LEN * 0.3
    return {
        rect = { x=sx - SWORD_LEN/2, y=sy - SWORD_LEN/2,
                 w=SWORD_LEN, h=SWORD_LEN },
        -- polygon for drawing
        cx=cx, cy=cy, angle=a, arc=arc,
    }
end

function Example.enter()
    W = love.graphics.getWidth()
    H = love.graphics.getHeight()

    player = {
        x=W/2-14, y=H/2-14, w=28, h=28,
        speed  = 170,
        angle  = 0,          -- facing direction
        state  = "idle",     -- idle/windup/active/recover
        stateT = 0,
        combo  = 0,          -- 0,1,2
        comboT = 0,
        iframes= 0,
        hp     = 5, maxHp=5,
        hitThisSwing = {},   -- enemies already hit this swing
    }

    shake     = Shake.new({ decay=7 })
    particles = {}
    spawnEnemies()
end

function Example.exit() end

local function startAttack(p)
    if p.state == "idle"
    or (p.state == "recover" and p.comboT > 0 and p.combo < 2) then
        p.combo  = (p.state == "recover") and p.combo + 1 or 0
        p.state  = "windup"
        p.stateT = WINDUP_TIME
        p.hitThisSwing = {}
        -- each combo hit slightly rotates the swing
        p.swingDir = (p.combo % 2 == 0) and 1 or -1
    end
end

function Example.update(dt)
    local p = player

    -- Movement (only full speed when idle, slowed during attack)
    local speedMul = (p.state == "idle") and 1 or 0.4
    local dx, dy = 0, 0
    if Input.isDown("left")  then dx = dx - 1 end
    if Input.isDown("right") then dx = dx + 1 end
    if Input.isDown("up")    then dy = dy - 1 end
    if Input.isDown("down")  then dy = dy + 1 end
    if dx ~= 0 and dy ~= 0 then dx=dx*0.7071; dy=dy*0.7071 end
    p.x = Utils.clamp(p.x + dx*p.speed*speedMul*dt, 0, W-p.w)
    p.y = Utils.clamp(p.y + dy*p.speed*speedMul*dt, 0, H-p.h)

    -- Aim toward mouse
    local cx = p.x + p.w/2
    local cy = p.y + p.h/2
    local mdx = Input.mouseX - cx
    local mdy = Input.mouseY - cy
    if math.sqrt(mdx*mdx + mdy*mdy) > 8 then
        p.angle = math.atan2(mdy, mdx)
    elseif dx ~= 0 or dy ~= 0 then
        p.angle = math.atan2(dy, dx)
    end

    -- Attack input
    if Input.isPressed("attack") or love.mouse.isDown(1) then
        startAttack(p)
    end

    -- State machine
    p.stateT = p.stateT - dt
    p.comboT = math.max(0, p.comboT - dt)

    if p.state == "windup" and p.stateT <= 0 then
        p.state  = "active"
        p.stateT = ACTIVE_TIME
    elseif p.state == "active" then
        -- Hit detection during active frames
        local hb = swordHitbox(p)
        for _, e in ipairs(enemies) do
            if not e.dead and not p.hitThisSwing[e] then
                if Utils.rectOverlap(hb.rect, e) then
                    e.hp    = e.hp - 1
                    e.flash = 0.15
                    p.hitThisSwing[e] = true
                    -- Knockback away from player
                    local kx = (e.x+e.w/2) - cx
                    local ky = (e.y+e.h/2) - cy
                    local kl = math.sqrt(kx*kx + ky*ky)
                    if kl > 0 then
                        e.vx = (kx/kl) * KNOCKBACK
                        e.vy = (ky/kl) * KNOCKBACK
                    end
                    spawnParticles(e.x+e.w/2, e.y+e.h/2, 1, 0.5, 0.1, 6)
                    Shake.add(shake, e.hp <= 0 and 0.25 or 0.1)
                    if e.hp <= 0 then
                        e.dead = true
                        spawnParticles(e.x+e.w/2, e.y+e.h/2, 0.9, 0.2, 0.2, 14)
                    end
                end
            end
        end
        if p.stateT <= 0 then
            p.state  = "recover"
            p.stateT = RECOVER_TIME
            p.comboT = COMBO_WINDOW
        end
    elseif p.state == "recover" and p.stateT <= 0 then
        p.state = "idle"
        p.combo = 0
    end

    -- i-frames
    p.iframes = math.max(0, p.iframes - dt)

    -- Enemies
    for _, e in ipairs(enemies) do
        if not e.dead then
            e.flash = math.max(0, e.flash - dt)
            -- Friction on knockback
            e.vx = e.vx * (1 - math.min(1, dt * 10))
            e.vy = e.vy * (1 - math.min(1, dt * 10))
            -- Chase player when not knocked back
            if math.abs(e.vx) < 20 and math.abs(e.vy) < 20 then
                local tx = cx - (e.x+e.w/2)
                local ty = cy - (e.y+e.h/2)
                local td = math.sqrt(tx*tx+ty*ty)
                if td > 0 then
                    e.vx = (tx/td) * 65
                    e.vy = (ty/td) * 65
                end
            end
            e.x = Utils.clamp(e.x + e.vx*dt, 0, W-e.w)
            e.y = Utils.clamp(e.y + e.vy*dt, 0, H-e.h)

            -- Hit player
            if p.iframes <= 0 and Utils.rectOverlap(e, p) then
                p.hp      = p.hp - 1
                p.iframes = IFRAME_TIME
                Shake.add(shake, 0.4)
                spawnParticles(cx, cy, 0.2, 0.6, 1.0, 10)
                if p.hp <= 0 then
                    Gamestate.switch(States.gameover, Example)
                    return
                end
            end
        end
    end

    -- Particles
    for i = #particles, 1, -1 do
        local pt = particles[i]
        pt.x    = pt.x + pt.vx * dt
        pt.y    = pt.y + pt.vy * dt
        pt.life = pt.life - dt
        if pt.life <= 0 then table.remove(particles, i) end
    end

    Shake.update(shake, dt)
end

function Example.draw()
    Shake.apply(shake, W, H)

    -- Background
    love.graphics.setColor(0.09, 0.11, 0.15)
    love.graphics.rectangle("fill", 0, 0, W, H)
    love.graphics.setColor(0.13, 0.15, 0.20)
    for x = 0, W, 48 do love.graphics.line(x, 0, x, H) end
    for y = 0, H, 48 do love.graphics.line(0, y, W, y) end

    -- Particles
    for _, pt in ipairs(particles) do
        local a = pt.life / pt.maxLife
        love.graphics.setColor(pt.r, pt.g, pt.b, a)
        love.graphics.circle("fill", pt.x, pt.y, 3*a)
    end

    -- Enemies
    for _, e in ipairs(enemies) do
        if not e.dead then
            local r = e.flash > 0 and 1   or 0.80
            local g = e.flash > 0 and 0.5 or 0.20
            local b = e.flash > 0 and 0.2 or 0.20
            love.graphics.setColor(r, g, b)
            love.graphics.rectangle("fill", e.x, e.y, e.w, e.h, 4, 4)
            love.graphics.setColor(1, 0.35, 0.35)
            love.graphics.rectangle("line", e.x, e.y, e.w, e.h, 4, 4)
            -- hp bar
            local bw = e.w
            love.graphics.setColor(0.2, 0.2, 0.2)
            love.graphics.rectangle("fill", e.x, e.y-8, bw, 4)
            love.graphics.setColor(0.9, 0.2, 0.2)
            love.graphics.rectangle("fill", e.x, e.y-8, bw*(e.hp/e.maxHp), 4)
        end
    end

    -- Player
    local p  = player
    local cx = p.x + p.w/2
    local cy = p.y + p.h/2

    -- i-frame flicker
    local showPlayer = p.iframes <= 0 or (math.floor(p.iframes*12)%2 == 0)
    if showPlayer then
        love.graphics.setColor(0.25, 0.75, 1.0)
        love.graphics.rectangle("fill", p.x, p.y, p.w, p.h, 5, 5)
        love.graphics.setColor(0.5, 0.9, 1.0)
        love.graphics.rectangle("line", p.x, p.y, p.w, p.h, 5, 5)
    end

    -- Sword
    local sAngle  = p.angle
    local arcSwing = math.pi * 0.55
    if p.state == "windup" then
        local t = 1 - p.stateT / WINDUP_TIME
        sAngle = p.angle - p.swingDir * arcSwing * 0.6 * (1-t)
    elseif p.state == "active" then
        local t = 1 - p.stateT / ACTIVE_TIME
        sAngle = p.angle + p.swingDir * arcSwing * t
        -- Draw swing arc
        love.graphics.setColor(1, 0.9, 0.3, 0.25)
        for i = 0, 8 do
            local aa = p.angle + p.swingDir * arcSwing * (i/8) * t
            local ax = cx + math.cos(aa) * SWORD_LEN * 0.5
            local ay = cy + math.sin(aa) * SWORD_LEN * 0.5
            love.graphics.circle("fill", ax, ay, SWORD_WIDTH*0.4*(1-i/8))
        end
    elseif p.state == "recover" then
        local t = p.stateT / RECOVER_TIME
        sAngle = p.angle + p.swingDir * arcSwing * t
    end

    -- Sword blade
    local ex = cx + math.cos(sAngle) * SWORD_LEN
    local ey = cy + math.sin(sAngle) * SWORD_LEN
    local col = p.state == "active" and {1,0.95,0.3} or {0.75,0.85,0.95}
    love.graphics.setColor(col)
    love.graphics.setLineWidth(p.state == "active" and SWORD_WIDTH or SWORD_WIDTH*0.7)
    love.graphics.line(cx + math.cos(sAngle)*10, cy + math.sin(sAngle)*10, ex, ey)
    love.graphics.setLineWidth(1)

    -- Combo indicator
    if p.combo > 0 or p.state ~= "idle" then
        for i = 0, 2 do
            if i < p.combo or p.state ~= "idle" and i == p.combo then
                love.graphics.setColor(1, 0.85, 0.2)
            else
                love.graphics.setColor(0.3, 0.3, 0.4)
            end
            love.graphics.circle("fill", cx - 10 + i*10, p.y - 14, 3)
        end
    end

    Shake.clear()

    -- Player HP
    local p = player
    for i = 1, p.maxHp do
        if i <= p.hp then love.graphics.setColor(0.9, 0.2, 0.2)
        else love.graphics.setColor(0.25, 0.25, 0.3) end
        love.graphics.circle("fill", 14 + (i-1)*20, 22, 7)
    end

    -- State debug
    love.graphics.setColor(0.4, 0.4, 0.5)
    love.graphics.print(string.format(
        "state: %-8s  combo: %d  iframes: %.2f",
        p.state, p.combo, p.iframes), 10, H-40)

    Utils.drawHUD("MELEE ATTACK",
        "WASD move    Z / LMB attack    Chain 3 hits for combo    P pause    ESC back")
end

function Example.keypressed(key)
    if key == "r" then spawnEnemies() end
    Utils.handlePause(key, Example)
end

function Example.mousepressed(x, y, button)
    if button == 1 then startAttack(player) end
end

function Example.touchpressed(id, x, y)
    startAttack(player)
end

return Example
