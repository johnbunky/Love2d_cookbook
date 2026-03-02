-- src/states/examples/high_score.lua
-- Demonstrates: persistent leaderboard, name entry, sorting, file I/O

local Utils       = require("src.utils")
local Timer       = require("src.systems.timer")
local Leaderboard = require("src.systems.leaderboard")
local Example = {}

local W, H
local timer
local time = 0

-- -------------------------
-- Persistence
-- -------------------------
local SCORES_FILE = "highscores.sav"
local MAX_ENTRIES = 10

-- Score management delegated to Leaderboard system
Leaderboard.setup(SCORES_FILE, MAX_ENTRIES)

-- -------------------------
-- Mini-game: dodge falling blocks
-- -------------------------
local game = {
    active    = false,
    score     = 0,
    lives     = 3,
    speed     = 150,
    spawnRate = 1.2,
    spawnT    = 0,
    player    = { x=0, y=0, w=40, h=16 },
    blocks    = {},
    particles = {},
    highNew   = false,
}

local function startGame()
    game.active    = true
    game.score     = 0
    game.lives     = 3
    game.speed     = 150
    game.spawnRate = 1.2
    game.spawnT    = 0
    game.blocks    = {}
    game.particles = {}
    game.highNew   = false
    game.player.x  = W/2
    game.player.y  = H - 80
end

-- -------------------------
-- Name entry state
-- -------------------------
local scores      = {}
local nameBuffer  = "AAA"
local nameCursor  = 0
local enteringName= false
local lastScore   = 0
local newRankPos  = nil

-- -------------------------
-- Enter / Exit
-- -------------------------
function Example.enter()
    W, H  = love.graphics.getWidth(), love.graphics.getHeight()
    timer = Timer.new()
    time  = 0
    Leaderboard.load()
    scores = Leaderboard.entries()
    game.player.x = W/2
    game.player.y = H - 80
end

function Example.exit()
    Timer.clear(timer)
end

-- -------------------------
-- Update
-- -------------------------
function Example.update(dt)
    Timer.update(timer, dt)
    time = time + dt

    if not game.active then return end

    -- Move player
    if love.keyboard.isDown("a","left")  then game.player.x = game.player.x - 300*dt end
    if love.keyboard.isDown("d","right") then game.player.x = game.player.x + 300*dt end
    game.player.x = Utils.clamp(game.player.x, game.player.w/2, W - game.player.w/2)

    -- Spawn blocks
    game.spawnT = game.spawnT + dt
    if game.spawnT >= game.spawnRate then
        game.spawnT = 0
        table.insert(game.blocks, {
            x     = math.random(30, W-30),
            y     = -20,
            w     = math.random(20, 50),
            speed = game.speed * (0.8 + math.random()*0.6),
            color = { math.random()*0.5+0.5, math.random()*0.5, math.random()*0.3 },
        })
        game.spawnRate = math.max(0.3, game.spawnRate - 0.01)
        game.speed     = math.min(400, game.speed + 1)
    end

    -- Update blocks
    for i = #game.blocks, 1, -1 do
        local b = game.blocks[i]
        b.y = b.y + b.speed * dt

        -- Hit player
        local px, py = game.player.x, game.player.y
        local hw, hh = game.player.w/2, game.player.h/2
        if b.x+b.w/2 > px-hw and b.x-b.w/2 < px+hw
        and b.y+10   > py-hh and b.y-10    < py+hh then
            -- Explosion particles
            for _ = 1, 8 do
                table.insert(game.particles, {
                    x=b.x, y=b.y,
                    vx=(math.random()-0.5)*200,
                    vy=(math.random()-0.5)*200,
                    life=0.5, color=b.color,
                })
            end
            table.remove(game.blocks, i)
            game.lives = game.lives - 1
            if game.lives <= 0 then
                game.active = false
                lastScore   = game.score
                -- Check if qualifies
                if #scores < MAX_ENTRIES or game.score > scores[#scores].score then
                    enteringName = true
                    nameBuffer   = "AAA"
                    nameCursor   = 0
                end
            end
        elseif b.y > H + 20 then
            -- Missed — score point
            game.score = game.score + 10
            table.remove(game.blocks, i)
        end
    end

    -- Particles
    for i = #game.particles, 1, -1 do
        local p = game.particles[i]
        p.x    = p.x + p.vx*dt
        p.y    = p.y + p.vy*dt
        p.life = p.life - dt
        if p.life <= 0 then table.remove(game.particles, i) end
    end
end

-- -------------------------
-- Draw
-- -------------------------
local RANK_COLORS = {
    {1.0, 0.84, 0.0},   -- gold
    {0.75,0.75,0.80},   -- silver
    {0.80,0.50,0.20},   -- bronze
}

function Example.draw()
    love.graphics.setColor(0.06, 0.08, 0.14)
    love.graphics.rectangle("fill", 0, 0, W, H)

    if game.active then
        -- ---- Mini game ----
        love.graphics.setColor(0.08, 0.10, 0.18)
        love.graphics.rectangle("fill", 0, 0, W, H)

        -- Stars bg
        math.randomseed(42)
        love.graphics.setColor(1,1,1,0.3)
        for _ = 1,60 do
            love.graphics.circle("fill", math.random(0,W), math.random(0,H), math.random()*1.5)
        end

        -- Blocks
        for _, b in ipairs(game.blocks) do
            love.graphics.setColor(b.color)
            love.graphics.rectangle("fill", b.x-b.w/2, b.y-10, b.w, 20, 3,3)
            love.graphics.setColor(1,1,1,0.3)
            love.graphics.rectangle("line", b.x-b.w/2, b.y-10, b.w, 20, 3,3)
        end

        -- Particles
        for _, p in ipairs(game.particles) do
            love.graphics.setColor(p.color[1], p.color[2], p.color[3], p.life*2)
            love.graphics.rectangle("fill", p.x-4, p.y-4, 8, 8)
        end

        -- Player
        local px, py = game.player.x, game.player.y
        local hw, hh = game.player.w/2, game.player.h/2
        love.graphics.setColor(0.3, 0.8, 1.0)
        love.graphics.rectangle("fill", px-hw, py-hh, game.player.w, game.player.h, 4,4)
        love.graphics.setColor(0.6, 1.0, 1.0)
        love.graphics.rectangle("line", px-hw, py-hh, game.player.w, game.player.h, 4,4)
        -- Engine glow
        love.graphics.setColor(0.3, 0.6, 1.0, 0.5+math.sin(time*8)*0.3)
        love.graphics.circle("fill", px, py+hh+4, 6)

        -- HUD
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle("fill", 0, 0, W, 38)
        love.graphics.setColor(0.9, 0.85, 0.3)
        love.graphics.printf("SCORE: "..game.score, 0, 8, W/3, "center")
        for i = 1, 3 do
            local col = i <= game.lives and {0.9,0.3,0.3} or {0.25,0.15,0.15}
            love.graphics.setColor(col)
            love.graphics.circle("fill", W/2+30 + (i-1)*28, 18, 10)
        end
        love.graphics.setColor(0.6, 0.75, 0.95)
        love.graphics.printf("A/D or ?/? to dodge    ESC quit", 0, 8, W, "right")
        return
    end

    -- ---- Leaderboard view ----
    love.graphics.setColor(0.5, 0.7, 1.0)
    love.graphics.printf("HIGH SCORES", 0, 20, W, "center")

    -- Leaderboard table
    local lx = W/2 - 220
    local ly = 60
    love.graphics.setColor(0.08, 0.12, 0.24, 0.95)
    love.graphics.rectangle("fill", lx-10, ly-4, 440, MAX_ENTRIES*34+44, 8,8)
    love.graphics.setColor(0.3, 0.45, 0.75)
    love.graphics.rectangle("line", lx-10, ly-4, 440, MAX_ENTRIES*34+44, 8,8)

    -- Header
    love.graphics.setColor(0.4, 0.55, 0.85)
    love.graphics.printf("#",     lx,      ly+4, 30,  "center")
    love.graphics.printf("Name",  lx+40,   ly+4, 140, "left")
    love.graphics.printf("Score", lx+190,  ly+4, 80,  "right")
    love.graphics.printf("Date",  lx+290,  ly+4, 120, "right")
    love.graphics.setColor(0.2, 0.32, 0.55)
    love.graphics.line(lx-8, ly+22, lx+430, ly+22)

    -- Entries
    for i, entry in ipairs(scores) do
        local ey  = ly + 28 + (i-1)*34
        local sel = (newRankPos == i)

        -- Highlight new entry
        if sel then
            love.graphics.setColor(0.15, 0.28, 0.12, 0.8)
            love.graphics.rectangle("fill", lx-8, ey-2, 436, 30, 4,4)
        end

        -- Rank color
        local rc = RANK_COLORS[i] or {0.55, 0.65, 0.85}
        love.graphics.setColor(rc)
        love.graphics.printf(i == 1 and "??" or i == 2 and "??" or i == 3 and "??" or tostring(i),
            lx, ey+4, 30, "center")

        love.graphics.setColor(i <= 3 and rc or (sel and {0.5,1.0,0.6} or {0.75,0.82,1.0}))
        love.graphics.printf(entry.name,  lx+40,  ey+4, 140, "left")
        love.graphics.printf(tostring(entry.score), lx+190, ey+4, 80, "right")
        love.graphics.setColor(0.4, 0.5, 0.7)
        love.graphics.printf(os.date("%m/%d %H:%M", entry.date),
            lx+290, ey+4, 120, "right")
    end

    if #scores == 0 then
        love.graphics.setColor(0.35, 0.45, 0.65)
        love.graphics.printf("No scores yet — play a game!", lx, ly+60, 420, "center")
    end

    -- Last score / result
    if lastScore > 0 then
        love.graphics.setColor(0.5, 0.7, 0.95)
        love.graphics.printf("Last score: " .. lastScore, 0, ly + MAX_ENTRIES*34 + 56, W, "center")
    end

    -- Name entry modal
    if enteringName then
        -- Dimmer
        love.graphics.setColor(0, 0, 0, 0.65)
        love.graphics.rectangle("fill", 0, 0, W, H)

        local mx, my, mw, mh = W/2-160, H/2-80, 320, 160
        love.graphics.setColor(0.08, 0.12, 0.24)
        love.graphics.rectangle("fill", mx, my, mw, mh, 10,10)
        love.graphics.setColor(0.4, 0.6, 1.0)
        love.graphics.rectangle("line", mx, my, mw, mh, 10,10)

        love.graphics.setColor(0.9, 0.85, 0.3)
        love.graphics.printf("NEW HIGH SCORE!", mx, my+14, mw, "center")
        love.graphics.setColor(0.7, 0.75, 0.95)
        love.graphics.printf("Score: "..lastScore, mx, my+36, mw, "center")
        love.graphics.printf("Enter your name:", mx, my+58, mw, "center")

        -- Name display with cursor
        local chars = {}
        for i = 1, #nameBuffer do chars[i] = nameBuffer:sub(i,i) end
        while #chars < 3 do chars[#chars+1] = "_" end
        for i, c in ipairs(chars) do
            local cx = mx + mw/2 - 45 + (i-1)*40
            local sel2 = (i-1 == nameCursor)
            love.graphics.setColor(sel2 and 0.3 or 0.12,
                                   sel2 and 0.6 or 0.2,
                                   sel2 and 1.0 or 0.4)
            love.graphics.rectangle("fill", cx-16, my+80, 32, 38, 4,4)
            love.graphics.setColor(1,1,1)
            love.graphics.printf(c, cx-16, my+88, 32, "center")
        end

        love.graphics.setColor(0.45, 0.60, 0.85)
        love.graphics.printf("?/? cursor   ?/? letter   ENTER confirm", mx, my+128, mw, "center")
    end

    Utils.drawHUD("HIGH SCORES",
        "SPACE / ENTER play game    DEL clear scores    ESC back")
end

-- -------------------------
-- Input
-- -------------------------
function Example.keypressed(key)
    if enteringName then
        if key == "left"  then nameCursor = math.max(0, nameCursor-1) end
        if key == "right" then nameCursor = math.min(#nameBuffer-1, nameCursor+1) end
        if key == "up" then
            local c   = nameBuffer:sub(nameCursor+1, nameCursor+1)
            local n   = string.char((string.byte(c)-65+1)%26+65)
            nameBuffer = nameBuffer:sub(1,nameCursor)..n..nameBuffer:sub(nameCursor+2)
        end
        if key == "down" then
            local c   = nameBuffer:sub(nameCursor+1, nameCursor+1)
            local n   = string.char((string.byte(c)-65+25)%26+65)
            nameBuffer = nameBuffer:sub(1,nameCursor)..n..nameBuffer:sub(nameCursor+2)
        end
        if key == "return" then
            Leaderboard.add(nameBuffer, lastScore)
            scores    = Leaderboard.entries()
            -- Find rank
            for i, e in ipairs(scores) do
                if e.score == lastScore and e.name == nameBuffer then
                    newRankPos = i; break
                end
            end
            Leaderboard.save()
            enteringName = false
        end
        if key == "escape" then enteringName = false end
        return
    end

    if game.active then
        if key == "escape" then
            game.active = false
            lastScore   = game.score
        end
        return
    end

    if key == "space" or key == "return" then
        newRankPos = nil
        startGame()
    elseif key == "delete" or key == "backspace" then
        Leaderboard.deleteFile()
        scores     = Leaderboard.entries()
        newRankPos = nil
        lastScore  = 0
    end

    Utils.handlePause(key, Example)
end

return Example
