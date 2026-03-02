-- src/states/examples/pathfinding.lua
-- Demonstrates: A* pathfinding on a grid, path smoothing, dynamic obstacles

local Utils   = require("src.utils")
local Timer   = require("src.systems.timer")
local PF      = require("src.systems.pathfinding")
local Example = {}

local W, H
local COLS  = 25
local ROWS  = 17
local TS    -- tile size, computed in enter()

local grid        = {}   -- 0=open 1=wall
local path        = {}   -- list of {col,row} world centers
local agent       = {}
local goalCol, goalRow
local dirty       = true  -- recompute path next frame
local enemies     = {}    -- moving obstacles
local showGrid    = true

-- -------------------------
-- Grid helpers
-- -------------------------
-- Pathfinding via PF system (initialised in buildGrid)
local pf  -- PF instance, created after grid size known

-- Local grid helpers (used by buildGrid for direct array writes)
local function idx(col, row) return (row-1)*COLS + col end
local function inBounds(col, row)
    return col >= 1 and col <= COLS and row >= 1 and row <= ROWS
end

-- Delegate to PF system after init
local function tileCenter(col, row) return pf:tileCenter(col, row) end
local function worldToTile(wx, wy)  return pf:worldToTile(wx, wy)  end
local function isWalkable(col, row) return pf:isWalkable(col, row) end


-- -------------------------

-- -------------------------
-- Level generation
-- -------------------------
local function buildGrid()
    pf = PF.new(COLS, ROWS, TS)
    grid = {}
    for i = 1, COLS*ROWS do grid[i] = 0 end

    -- Border walls
    for c = 1, COLS do
        grid[idx(c,1)]    = 1
        grid[idx(c,ROWS)] = 1
    end
    for r = 1, ROWS do
        grid[idx(1,r)]    = 1
        grid[idx(COLS,r)] = 1
    end

    -- Interior walls (hand-crafted maze-like)
    local walls = {
        {3,3,3,8},  {5,3,10,3}, {10,3,10,8},
        {3,10,8,10},{5,12,5,16},{12,5,12,10},
        {14,3,19,3},{19,3,19,8},{14,10,19,10},
        {21,5,21,12},{8,13,13,13},{15,13,20,13},
    }
    for _, w in ipairs(walls) do
        local c1,r1,c2,r2 = w[1],w[2],w[3],w[4]
        for c = math.min(c1,c2), math.max(c1,c2) do
            for r = math.min(r1,r2), math.max(r1,r2) do
                if inBounds(c,r) then grid[idx(c,r)] = 1 end
            end
        end
    end
    pf:setGrid(grid)   -- sync grid data into PF system
end

function Example.enter()
    W  = love.graphics.getWidth()
    H  = love.graphics.getHeight()
    TS = math.floor(math.min(W/COLS, (H-60)/ROWS))

    buildGrid()

    agent = {
        x=tileCenter(2,2), y=select(2,tileCenter(2,2)),
        pathIdx=1, speed=120,
        col=2, row=2,
    }
    agent.x, agent.y = tileCenter(2, 2)

    goalCol, goalRow = COLS-1, ROWS-1
    dirty = true

    -- A few wandering enemies as moving obstacles (just visual for now)
    enemies = {
        { x=tileCenter(12,8), y=select(2,tileCenter(12,8)),
          col=12, row=8, targetC=12, targetR=4, speed=60 },
        { x=tileCenter(20,12), y=select(2,tileCenter(20,12)),
          col=20, row=12, targetC=22, targetR=6, speed=50 },
    }
end

function Example.exit() end

function Example.update(dt)
    -- Recompute path if dirty
    if dirty then
        dirty = false
        local ac, ar = worldToTile(agent.x, agent.y)
        local rawPath = pf:find(ac, ar, goalCol, goalRow)
        path = pf:smooth(rawPath)
        agent.pathIdx = 2  -- skip first node (current pos)
    end

    -- Move agent along path
    if agent.pathIdx <= #path then
        local wp    = path[agent.pathIdx]
        local wx, wy = tileCenter(wp.col, wp.row)
        local dx    = wx - agent.x
        local dy    = wy - agent.y
        local d     = math.sqrt(dx*dx + dy*dy)

        if d < 4 then
            agent.x, agent.y = wx, wy
            agent.pathIdx = agent.pathIdx + 1
        else
            agent.x = agent.x + (dx/d) * agent.speed * dt
            agent.y = agent.y + (dy/d) * agent.speed * dt
        end
    end

    -- Move enemies (bounce between two waypoints)
    for _, e in ipairs(enemies) do
        local tx, ty = tileCenter(e.targetC, e.targetR)
        local dx = tx - e.x
        local dy = ty - e.y
        local d  = math.sqrt(dx*dx + dy*dy)
        if d < 4 then
            -- swap targets
            e.targetC, e.col  = e.col, e.targetC
            e.targetR, e.row  = e.row, e.targetR
        else
            e.x = e.x + (dx/d) * e.speed * dt
            e.y = e.y + (dy/d) * e.speed * dt
        end
    end
end

function Example.draw()
    love.graphics.setColor(0.08, 0.10, 0.14)
    love.graphics.rectangle("fill", 0, 0, W, H)

    -- Grid tiles
    for row = 1, ROWS do
        for col = 1, COLS do
            local tx = (col-1)*TS
            local ty = (row-1)*TS
            if grid[idx(col,row)] == 1 then
                love.graphics.setColor(0.30, 0.35, 0.45)
                love.graphics.rectangle("fill", tx, ty, TS, TS)
                love.graphics.setColor(0.40, 0.45, 0.55)
                love.graphics.rectangle("line", tx, ty, TS, TS)
            elseif showGrid then
                love.graphics.setColor(0.12, 0.14, 0.18)
                love.graphics.rectangle("line", tx, ty, TS, TS)
            end
        end
    end

    -- Closed tiles visited by A* (skip for performance — just show result)

    -- Path
    if #path > 1 then
        -- Filled path tiles
        for i, node in ipairs(path) do
            if i >= (agent.pathIdx or 1) then
                local tx = (node.col-1)*TS
                local ty = (node.row-1)*TS
                local t  = (i-1) / #path
                love.graphics.setColor(0.2+t*0.4, 0.6+t*0.2, 0.3, 0.25)
                love.graphics.rectangle("fill", tx+2, ty+2, TS-4, TS-4, 3,3)
            end
        end

        -- Path line
        love.graphics.setColor(0.3, 0.85, 0.5, 0.7)
        love.graphics.setLineWidth(2)
        for i = math.max(1, agent.pathIdx-1), #path-1 do
            local ax, ay = tileCenter(path[i].col,   path[i].row)
            local bx, by = tileCenter(path[i+1].col, path[i+1].row)
            love.graphics.line(ax, ay, bx, by)
        end
        love.graphics.setLineWidth(1)

        -- Waypoint dots
        for i = agent.pathIdx, #path do
            local wx, wy = tileCenter(path[i].col, path[i].row)
            love.graphics.setColor(0.3, 0.9, 0.5, 0.8)
            love.graphics.circle("fill", wx, wy, 3)
        end
    end

    -- Goal
    local gx, gy = tileCenter(goalCol, goalRow)
    love.graphics.setColor(1, 0.85, 0.1, 0.35)
    love.graphics.rectangle("fill", (goalCol-1)*TS, (goalRow-1)*TS, TS, TS)
    love.graphics.setColor(1, 0.85, 0.1)
    love.graphics.circle("fill", gx, gy, 7)
    love.graphics.setColor(1,1,1,0.8)
    love.graphics.printf("GOAL", (goalCol-1)*TS, (goalRow-1)*TS+TS/2-6, TS, "center")

    -- Moving enemies
    for _, e in ipairs(enemies) do
        love.graphics.setColor(0.85, 0.3, 0.3)
        love.graphics.circle("fill", e.x, e.y, TS/2-4)
        love.graphics.setColor(1, 0.4, 0.4)
        love.graphics.circle("line", e.x, e.y, TS/2-4)
    end

    -- Agent
    love.graphics.setColor(0.25, 0.75, 1.0)
    love.graphics.circle("fill", agent.x, agent.y, TS/2-3)
    love.graphics.setColor(0.5, 0.95, 1.0)
    love.graphics.circle("line", agent.x, agent.y, TS/2-3)

    -- HUD
    love.graphics.setColor(0.15, 0.15, 0.2)
    love.graphics.rectangle("fill", 0, H-56, W, 56)

    love.graphics.setColor(0.5, 0.5, 0.6)
    love.graphics.print(
        string.format("Path nodes: %d   waypoint: %d/%d   G key toggle grid",
            #path, math.min(agent.pathIdx, #path), #path),
        10, H-48)

    Utils.drawHUD("PATHFINDING  (A*)",
        "Click to set goal    R reset agent    G toggle grid    P pause    ESC back")
end

function Example.keypressed(key)
    if key == "r" then
        agent.x, agent.y = tileCenter(2, 2)
        agent.pathIdx = 1
        dirty = true
    end
    if key == "g" then showGrid = not showGrid end
    Utils.handlePause(key, Example)
end

function Example.mousepressed(x, y, button)
    if button == 1 then
        local c, r = worldToTile(x, y)
        if inBounds(c, r) and isWalkable(c, r) then
            goalCol, goalRow = c, r
            dirty = true
        end
    end
    if button == 2 then
        -- Right click: toggle wall
        local c, r = worldToTile(x, y)
        if inBounds(c, r) and c > 1 and c < COLS and r > 1 and r < ROWS then
            grid[idx(c,r)] = grid[idx(c,r)] == 0 and 1 or 0
            pf:setGrid(grid)   -- keep PF system in sync
            dirty = true
        end
    end
end

function Example.touchpressed(id, x, y)
    local c, r = worldToTile(x, y)
    if inBounds(c, r) and isWalkable(c, r) then
        goalCol, goalRow = c, r
        dirty = true
    end
end

return Example
