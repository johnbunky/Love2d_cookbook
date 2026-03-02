-- src/states/examples/health_damage.lua
-- Demonstrates: health system, damage types, resistances, status effects,
--               death, respawn, regeneration, invincibility frames

local Utils  = require("src.utils")
local HUD    = require("src.systems.hud")
local Shake  = require("src.systems.shake")
local Example = {}

local W, H
local player
local shake
local floaters  = {}   -- floating damage numbers
local log       = {}   -- combat log lines
local LOG_MAX   = 6

-- -------------------------
-- Damage types
-- -------------------------
local DMG = {
    PHYSICAL = "physical",
    FIRE     = "fire",
    ICE      = "ice",
    POISON   = "poison",
    HEAL     = "heal",
}

local dmgColors = {
    physical = {0.9, 0.9, 0.9},
    fire     = {1.0, 0.45, 0.1},
    ice      = {0.3, 0.8, 1.0},
    poison   = {0.4, 0.9, 0.3},
    heal     = {0.2, 1.0, 0.5},
}

-- -------------------------
-- Status effects
-- -------------------------
local STATUS = {}  -- active: { type, duration, tickT, stacks }

local function hasStatus(t)
    for _, s in ipairs(STATUS) do
        if s.type == t then return s end
    end
    return nil
end

local function applyStatus(t, duration, stacks)
    local existing = hasStatus(t)
    if existing then
        existing.duration = math.max(existing.duration, duration)
        existing.stacks   = math.min((existing.stacks or 1) + (stacks or 1), 5)
    else
        table.insert(STATUS, {
            type=t, duration=duration,
            tickT=0, stacks=stacks or 1,
        })
    end
end

-- -------------------------
-- Combat log
-- -------------------------
local function addLog(msg, r, g, b)
    table.insert(log, 1, { text=msg, r=r or 1, g=g or 1, b=b or 1, life=4 })
    if #log > LOG_MAX then table.remove(log) end
end

-- -------------------------
-- Floating numbers
-- -------------------------
local function spawnFloater(x, y, text, r, g, b)
    table.insert(floaters, {
        x=x, y=y, vy=-55,
        text=text, r=r, g=g, b=b,
        life=1.0, maxLife=1.0,
        scale=1.4,
    })
end

-- -------------------------
-- Player creation
-- -------------------------
local function newPlayer()
    return {
        x=W/2-20, y=H/2-20, w=40, h=40,
        hp=100, maxHp=100,
        hpBar  = HUD.newBar({max=100, r=0.85,g=0.2,b=0.2}),
        armor  = 10,    -- flat physical reduction
        -- resistances 0..1 (1 = immune)
        resist = { fire=0.0, ice=0.0, poison=0.0 },
        iframes= 0,
        regenT = 0,     -- regen tick timer
        dead   = false,
        deathT = 0,
    }
end

-- -------------------------
-- Apply damage to player
-- -------------------------
local function dealDamage(amount, dtype, noLog)
    local p = player
    if p.dead then return end

    local actual = amount
    local label  = ""

    if dtype == DMG.PHYSICAL then
        actual = math.max(1, amount - p.armor)
        label  = string.format("-%d  phys", actual)
        if p.iframes > 0 then
            addLog("blocked by i-frames", 0.5,0.5,0.5)
            return
        end
        p.iframes = 0.4
        Shake.add(shake, 0.25)

    elseif dtype == DMG.FIRE then
        actual = math.floor(amount * (1 - p.resist.fire))
        label  = string.format("-%d  fire", actual)
        applyStatus("burning", 4.0, 1)
        Shake.add(shake, 0.15)

    elseif dtype == DMG.ICE then
        actual = math.floor(amount * (1 - p.resist.ice))
        label  = string.format("-%d  ice", actual)
        applyStatus("frozen", 2.5, 1)
        Shake.add(shake, 0.1)

    elseif dtype == DMG.POISON then
        actual = 0  -- poison deals damage over time via status
        applyStatus("poisoned", 6.0, 1)
        label  = "poisoned!"

    elseif dtype == DMG.HEAL then
        actual = -amount  -- negative = heal
        label  = string.format("+%d  heal", amount)
    end

    p.hp = Utils.clamp(p.hp + (-actual), 0, p.maxHp)
    HUD.setBar(p.hpBar, p.hp)

    local col = dmgColors[dtype] or {1,1,1}
    spawnFloater(p.x + p.w/2 + math.random(-20,20),
                 p.y + math.random(-10,0),
                 label, col[1], col[2], col[3])
    if not noLog then
        addLog(label, col[1], col[2], col[3])
    end

    if p.hp <= 0 then
        p.dead  = true
        p.deathT= 2.0
        addLog("DEAD — respawning in 2s", 1, 0.3, 0.3)
        Shake.add(shake, 0.8)
    end
end

-- -------------------------
-- Buttons
-- -------------------------
local buttons = {}
local function buildButtons()
    local defs = {
        { label="Physical\n-25",  dtype=DMG.PHYSICAL, amt=25 },
        { label="Fire\n-20",      dtype=DMG.FIRE,     amt=20 },
        { label="Ice\n-15",       dtype=DMG.ICE,      amt=15 },
        { label="Poison\n DoT",   dtype=DMG.POISON,   amt=0  },
        { label="Heal\n+30",      dtype=DMG.HEAL,     amt=30 },
        { label="+Armor\n+5",     dtype="armor",      amt=5  },
        { label="Fire Res\n+20%", dtype="resist_fire",amt=0.2},
    }
    buttons = {}
    local bw  = 90
    local bh  = 52
    local gap = 10
    local totalW = #defs*(bw+gap) - gap
    local sx  = (W - totalW) / 2
    local by  = H - 90
    for i, d in ipairs(defs) do
        table.insert(buttons, {
            x=sx+(i-1)*(bw+gap), y=by, w=bw, h=bh,
            label=d.label, dtype=d.dtype, amt=d.amt,
        })
    end
end

local function triggerButton(btn)
    local p = player
    if btn.dtype == "armor" then
        p.armor = math.min(p.armor + btn.amt, 50)
        addLog(string.format("armor +%d ? %d", btn.amt, p.armor), 0.8,0.8,0.4)
    elseif btn.dtype == "resist_fire" then
        p.resist.fire = math.min(p.resist.fire + btn.amt, 0.9)
        addLog(string.format("fire resist ? %.0f%%", p.resist.fire*100), 1,0.5,0.2)
    else
        dealDamage(btn.amt, btn.dtype)
    end
end

function Example.enter()
    W = love.graphics.getWidth()
    H = love.graphics.getHeight()
    player  = newPlayer()
    shake   = Shake.new({ decay=6 })
    floaters= {}
    log     = {}
    STATUS  = {}
    buildButtons()
    addLog("Click buttons or press 1-7 to apply effects", 0.6,0.6,0.7)
end

function Example.exit() end

function Example.update(dt)
    local p = player
    p.iframes = math.max(0, p.iframes - dt)

    -- Death / respawn
    if p.dead then
        p.deathT = p.deathT - dt
        if p.deathT <= 0 then
            player  = newPlayer()
            STATUS  = {}
            HUD.fillBar(player.hpBar)
            addLog("respawned", 0.3,0.9,0.5)
        end
        Shake.update(shake, dt)
        return
    end

    -- Status effects tick
    for i = #STATUS, 1, -1 do
        local s = STATUS[i]
        s.duration = s.duration - dt
        s.tickT    = s.tickT - dt

        if s.type == "burning" and s.tickT <= 0 then
            s.tickT = 0.5
            dealDamage(4 * s.stacks, DMG.FIRE, true)
            spawnFloater(p.x+p.w/2, p.y-10, "-4 burn",
                dmgColors.fire[1], dmgColors.fire[2], dmgColors.fire[3])
        end
        if s.type == "poisoned" and s.tickT <= 0 then
            s.tickT = 1.0
            dealDamage(6 * s.stacks, DMG.POISON, true)
            spawnFloater(p.x+p.w/2, p.y-10, "-6 poison",
                dmgColors.poison[1], dmgColors.poison[2], dmgColors.poison[3])
        end
        if s.type == "frozen" then
            -- no tick damage, just a slow debuff (visual only here)
        end

        if s.duration <= 0 then
            addLog(s.type .. " wore off", 0.6,0.6,0.6)
            table.remove(STATUS, i)
        end
    end

    -- Passive regen (1hp/2s when no status)
    if #STATUS == 0 and p.hp < p.maxHp then
        p.regenT = p.regenT - dt
        if p.regenT <= 0 then
            p.regenT = 2.0
            p.hp = math.min(p.hp + 1, p.maxHp)
            HUD.setBar(p.hpBar, p.hp)
        end
    end

    -- Update bars
    HUD.updateBar(p.hpBar, dt)

    -- Floaters
    for i = #floaters, 1, -1 do
        local f = floaters[i]
        f.y     = f.y + f.vy * dt
        f.life  = f.life - dt
        f.scale = Utils.lerp(f.scale, 1.0, 8*dt)
        if f.life <= 0 then table.remove(floaters, i) end
    end

    -- Log fade
    for i = #log, 1, -1 do
        log[i].life = log[i].life - dt
        if log[i].life <= 0 then table.remove(log, i) end
    end

    Shake.update(shake, dt)
end

function Example.draw()
    Shake.apply(shake, W, H)

    love.graphics.setColor(0.09, 0.11, 0.16)
    love.graphics.rectangle("fill", 0, 0, W, H)

    local p = player

    -- Player body
    if not p.dead then
        local flicker = p.iframes > 0 and (math.floor(p.iframes*12)%2==0)
        if not flicker then
            -- Status tint
            local burning = hasStatus("burning")
            local frozen  = hasStatus("frozen")
            local poison  = hasStatus("poisoned")
            local r, g, b = 0.3, 0.75, 1.0
            if burning then r,g,b = 1.0, 0.4, 0.1
            elseif frozen then r,g,b = 0.4, 0.8, 1.0
            elseif poison then r,g,b = 0.4, 0.9, 0.3 end
            love.graphics.setColor(r, g, b)
            love.graphics.rectangle("fill", p.x, p.y, p.w, p.h, 8, 8)
            love.graphics.setColor(r*1.3, g*1.3, b*1.3, 0.8)
            love.graphics.rectangle("line", p.x, p.y, p.w, p.h, 8, 8)

            -- Status particle effects
            if burning then
                for _ = 1, 2 do
                    local fx = p.x + math.random()*p.w
                    local fy = p.y + math.random()*p.h
                    love.graphics.setColor(1, math.random()*0.5+0.3, 0, 0.6)
                    love.graphics.circle("fill", fx, fy, math.random(2,5))
                end
            end
            if frozen then
                love.graphics.setColor(0.5, 0.9, 1.0, 0.3)
                love.graphics.rectangle("fill", p.x-4, p.y-4, p.w+8, p.h+8, 8,8)
            end
        end
    else
        -- Death animation
        local t = 1 - p.deathT / 2.0
        love.graphics.setColor(0.6, 0.1, 0.1, 1-t)
        love.graphics.rectangle("fill", p.x, p.y + t*20, p.w, p.h*(1-t*0.5), 8,8)
    end

    -- HP Bar
    HUD.drawBar(p.hpBar, W/2-150, 20, 300, 22, "HP")

    -- Stats panel
    love.graphics.setColor(0.13, 0.15, 0.20)
    love.graphics.rectangle("fill", 10, 60, 170, 130, 4,4)
    love.graphics.setColor(0.5, 0.5, 0.6)
    love.graphics.print("STATS", 18, 66)
    love.graphics.setColor(0.8, 0.8, 0.8)
    love.graphics.print(string.format("HP:      %d / %d", p.hp, p.maxHp), 18, 84)
    love.graphics.print(string.format("Armor:   %d", p.armor), 18, 102)
    love.graphics.print(string.format("Fire:    %.0f%% res", p.resist.fire*100), 18, 120)
    love.graphics.print(string.format("i-frames:%.2fs", p.iframes), 18, 138)
    love.graphics.print(string.format("Regen:   %s", #STATUS==0 and "active" or "paused"),
        18, 156)

    -- Status effects panel
    if #STATUS > 0 then
        love.graphics.setColor(0.13, 0.15, 0.20)
        love.graphics.rectangle("fill", W-180, 60, 170, 20 + #STATUS*22, 4,4)
        love.graphics.setColor(0.6, 0.6, 0.7)
        love.graphics.print("STATUS EFFECTS", W-172, 66)
        for i, s in ipairs(STATUS) do
            local col = dmgColors[s.type] or {1,1,1}
            love.graphics.setColor(col)
            love.graphics.print(
                string.format("%-10s %.1fs x%d", s.type, s.duration, s.stacks),
                W-172, 66 + i*22)
        end
    end

    -- Combat log
    love.graphics.setColor(0.13, 0.15, 0.20)
    love.graphics.rectangle("fill", 10, H-220, 200, LOG_MAX*22+10, 4,4)
    love.graphics.setColor(0.45, 0.45, 0.55)
    love.graphics.print("COMBAT LOG", 18, H-214)
    for i, entry in ipairs(log) do
        local a = math.min(1, entry.life)
        love.graphics.setColor(entry.r, entry.g, entry.b, a)
        love.graphics.print(entry.text, 18, H-214 + i*20)
    end

    -- Floaters
    for _, f in ipairs(floaters) do
        local a = f.life / f.maxLife
        love.graphics.setColor(f.r, f.g, f.b, a)
        love.graphics.print(f.text, f.x, f.y)
    end

    -- Buttons
    for i, btn in ipairs(buttons) do
        local hover = Input.isHover(btn.x, btn.y, btn.w, btn.h)
        if hover then
            love.graphics.setColor(0.35, 0.5, 0.7)
        else
            love.graphics.setColor(0.2, 0.28, 0.4)
        end
        love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h, 6,6)
        local col = dmgColors[btn.dtype] or {0.7,0.8,0.5}
        love.graphics.setColor(col[1] or 0.7, col[2] or 0.7, col[3] or 0.7)
        love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h, 6,6)
        love.graphics.setColor(hover and 1 or 0.85, hover and 1 or 0.85, hover and 1 or 0.85)
        love.graphics.printf(btn.label, btn.x, btn.y+8, btn.w, "center")
        -- key hint
        love.graphics.setColor(0.4, 0.4, 0.5)
        love.graphics.printf("[" .. i .. "]", btn.x, btn.y+btn.h-14, btn.w, "center")
    end

    Shake.clear()

    Utils.drawHUD("HEALTH & DAMAGE",
        "Click buttons or press 1-7    P pause    ESC back")
end

function Example.keypressed(key)
    local n = tonumber(key)
    if n and buttons[n] then triggerButton(buttons[n]) end
    Utils.handlePause(key, Example)
end

function Example.mousepressed(x, y, button)
    if button == 1 then
        for _, btn in ipairs(buttons) do
            if Input.isHover(btn.x, btn.y, btn.w, btn.h) then
                triggerButton(btn)
                return
            end
        end
    end
end

function Example.touchpressed(id, x, y)
    for _, btn in ipairs(buttons) do
        if x >= btn.x and x <= btn.x+btn.w
        and y >= btn.y and y <= btn.y+btn.h then
            triggerButton(btn)
            return
        end
    end
end

return Example
