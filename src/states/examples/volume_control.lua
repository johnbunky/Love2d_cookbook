-- src/states/examples/volume_control.lua
-- Demonstrates: master volume, per-channel volume, pitch, spatial audio, audio groups

local Utils  = require("src.utils")
local Timer  = require("src.systems.timer")
local Example = {}

local W, H
local timer
local time = 0

-- -------------------------
-- Audio channels / groups
-- -------------------------
local channels = {
    { name="Master",  volume=1.0, icon="M" },
    { name="Music",   volume=0.8, icon="~" },
    { name="SFX",     volume=1.0, icon="!" },
    { name="Voice",   volume=0.9, icon="v" },
    { name="Ambient", volume=0.6, icon="a" },
}

-- -------------------------
-- Procedural tones per channel
-- -------------------------
local function makeToneLoop(freq, wavetype)
    local rate    = 44100
    local samples = math.floor(rate * 2.0)  -- 2 second loop
    local sd      = love.sound.newSoundData(samples, rate, 16, 1)
    for i = 0, samples - 1 do
        local t = i / rate
        local v
        if wavetype == "sine" then
            v = math.sin(2*math.pi*freq*t) * 0.35
        elseif wavetype == "pulse" then
            v = ((i % math.floor(rate/freq)) < math.floor(rate/freq/2)) and 0.3 or -0.3
        elseif wavetype == "tri" then
            local p  = (i % math.floor(rate/freq)) / math.floor(rate/freq)
            v = (p < 0.5) and (4*p - 1) * 0.3 or (3 - 4*p) * 0.3
        elseif wavetype == "noise" then
            local prev = 0
            local raw  = (math.random()*2-1) * 0.2
            prev = prev + 0.02*(raw-prev)
            v = prev
        else
            v = math.sin(2*math.pi*freq*t) * 0.3
        end
        sd:setSample(i, v)
    end
    local src = love.audio.newSource(sd, "static")
    src:setLooping(true)
    return src
end

local channelSources = {}
local function buildSources()
    for _, src in ipairs(channelSources) do
        if src then src:stop() end
    end
    channelSources = {}
    -- Music: melodic sine
    channelSources[2] = makeToneLoop(330, "sine")
    -- SFX: pulse
    channelSources[3] = makeToneLoop(440, "pulse")
    -- Voice: triangle
    channelSources[4] = makeToneLoop(220, "tri")
    -- Ambient: low sine
    channelSources[5] = makeToneLoop(110, "sine")
end

-- Apply volumes: channel vol * master vol
local function applyVolumes()
    local master = channels[1].volume
    for i = 2, #channels do
        local src = channelSources[i]
        if src then
            src:setVolume(channels[i].volume * master)
        end
    end
end

-- -------------------------
-- Spatial audio demo
-- -------------------------
local spatialSource = nil
local emitter = { x=0, y=0, angle=0, radius=200 }
local listenerX, listenerY = 0, 0

local function makeSpatialTone()
    local rate    = 44100
    local samples = math.floor(rate * 1.0)
    local sd      = love.sound.newSoundData(samples, rate, 16, 1)
    for i = 0, samples-1 do
        local t = i/rate
        local v = math.sin(2*math.pi*660*t) * 0.4
               + math.sin(2*math.pi*880*t) * 0.2
        v = v * (0.8 + math.sin(2*math.pi*4*t)*0.2)
        sd:setSample(i, v)
    end
    local src = love.audio.newSource(sd, "static")
    src:setLooping(true)
    src:setRelative(false)
    return src
end

-- -------------------------
-- UI State
-- -------------------------
local selectedChannel = 1
local pitchValue      = 1.0
local showSpatial     = false

-- -------------------------
-- Enter / Exit
-- -------------------------
function Example.enter()
    W = love.graphics.getWidth()
    H = love.graphics.getHeight()
    timer  = Timer.new()
    time   = 0
    math.randomseed(42)
    buildSources()
    applyVolumes()

    spatialSource = makeSpatialTone()
    emitter.x     = W * 0.5
    emitter.y     = H * 0.5
    listenerX     = W * 0.5
    listenerY     = H * 0.5

    -- Autostart all channels so mixer is immediately audible
    for i = 2, #channels do
        if channelSources[i] then
            channelSources[i]:play()
        end
    end
    applyVolumes()
end

function Example.exit()
    Timer.clear(timer)
    for _, src in ipairs(channelSources) do
        if src then src:stop() end
    end
    if spatialSource then spatialSource:stop() end
    love.audio.stop()   -- kill anything still playing globally
    love.audio.setPosition(0, 0, 0)
end

function Example.update(dt)
    Timer.update(timer, dt)
    time = time + dt

    -- Orbit emitter
    if showSpatial then
        emitter.angle = emitter.angle + dt * 0.8
        emitter.x     = listenerX + math.cos(emitter.angle) * emitter.radius
        emitter.y     = listenerY + math.sin(emitter.angle) * emitter.radius
        -- Set 3D position (map 2D to XZ plane)
        local dx = (emitter.x - listenerX) / 100
        local dz = (emitter.y - listenerY) / 100
        spatialSource:setPosition(dx, 0, dz)
        love.audio.setPosition(0, 0, 0)
        love.audio.setOrientation(0, 0, -1, 0, 1, 0)
    end
end

-- -------------------------
-- Draw
-- -------------------------
local SLIDER_W = 320
local SLIDER_H = 18
local PANEL_X  = 60
local PANEL_Y  = 70

local function drawSlider(x, y, value, minV, maxV, label, active, color)
    local fill  = (value - minV) / (maxV - minV) * SLIDER_W
    color = color or {0.3, 0.55, 1.0}

    -- Track
    love.graphics.setColor(0.10, 0.14, 0.24)
    love.graphics.rectangle("fill", x, y, SLIDER_W, SLIDER_H, 4,4)

    -- Fill
    love.graphics.setColor(color[1], color[2], color[3], active and 1.0 or 0.5)
    love.graphics.rectangle("fill", x, y, fill, SLIDER_H, 4,4)

    -- Border
    love.graphics.setColor(active and 0.4 or 0.2,
                           active and 0.65 or 0.35,
                           active and 1.0 or 0.5)
    love.graphics.rectangle("line", x, y, SLIDER_W, SLIDER_H, 4,4)

    -- Thumb
    love.graphics.setColor(1, 1, 1, active and 1 or 0.6)
    love.graphics.circle("fill", x + fill, y + SLIDER_H/2, SLIDER_H*0.7)

    -- Label
    love.graphics.setColor(active and 0.9 or 0.55, active and 0.9 or 0.55, active and 1.0 or 0.7)
    love.graphics.print(label, x - 10, y + 1, 0, 1, 1, love.graphics.getFont():getWidth(label)+2, 0)
    -- Value
    love.graphics.setColor(active and 1 or 0.65, active and 1 or 0.65, active and 1 or 0.75)
    love.graphics.printf(string.format("%.2f", value), x + SLIDER_W + 8, y + 1, 50, "left")
end

function Example.draw()
    love.graphics.setColor(0.06, 0.08, 0.14)
    love.graphics.rectangle("fill", 0, 0, W, H)

    -- Title
    love.graphics.setColor(0.5, 0.7, 1.0)
    love.graphics.printf("VOLUME CONTROL", 0, 18, W, "center")

    if not showSpatial then
        -- ---- Channel mixer ----
        love.graphics.setColor(0.35, 0.50, 0.80)
        love.graphics.printf("Channel Mixer", PANEL_X, PANEL_Y - 22, 400, "left")

        for i, ch in ipairs(channels) do
            local y      = PANEL_Y + (i-1) * 54
            local active = (i == selectedChannel)

            -- Row bg
            if active then
                love.graphics.setColor(0.10, 0.16, 0.30, 0.8)
                love.graphics.rectangle("fill", PANEL_X-10, y-4, SLIDER_W+100, 46, 6,6)
            end

            -- Icon badge
            local bcolor = active and {0.3,0.6,1.0} or {0.2,0.3,0.5}
            love.graphics.setColor(bcolor)
            love.graphics.rectangle("fill", PANEL_X-10, y+4, 28, 28, 4,4)
            love.graphics.setColor(1,1,1, active and 1 or 0.6)
            love.graphics.printf(ch.icon, PANEL_X-10, y+8, 28, "center")

            -- Channel name
            love.graphics.setColor(active and 1 or 0.65, active and 1 or 0.65, active and 1 or 0.8)
            love.graphics.print(ch.name, PANEL_X+26, y+8)

            -- Playing badge (channels 2-5)
            if i > 1 then
                local src     = channelSources[i]
                local playing = src and src:isPlaying()
                love.graphics.setColor(playing and 0.15 or 0.08,
                                       playing and 0.50 or 0.20,
                                       playing and 0.25 or 0.15)
                love.graphics.rectangle("fill", PANEL_X+110, y+6, 44, 18, 3,3)
                love.graphics.setColor(playing and 0.3 or 0.2,
                                       playing and 1.0 or 0.4,
                                       playing and 0.5 or 0.3)
                love.graphics.printf(playing and "ON" or "OFF",
                    PANEL_X+110, y+8, 44, "center")
            end

            -- Volume slider
            local sliderColor = i==1 and {0.9,0.6,0.2}
                              or i==2 and {0.3,0.7,0.5}
                              or {0.3,0.55,1.0}
            drawSlider(PANEL_X, y+28, ch.volume, 0, 1,
                string.format("%-8s", ch.name), active, sliderColor)
        end

        -- Pitch slider (applies to SFX channel)
        local pitchY = PANEL_Y + #channels * 54 + 10
        love.graphics.setColor(0.35, 0.50, 0.80)
        love.graphics.printf("Pitch (SFX channel)", PANEL_X, pitchY - 18, 400, "left")
        drawSlider(PANEL_X, pitchY, pitchValue, 0.25, 2.0,
            "Pitch   ", selectedChannel == 3, {0.8, 0.5, 1.0})

        -- Instructions panel
        local ix = W - 280
        love.graphics.setColor(0.08, 0.12, 0.22, 0.95)
        love.graphics.rectangle("fill", ix, PANEL_Y-30, 240, 260, 6,6)
        love.graphics.setColor(0.3, 0.45, 0.75)
        love.graphics.rectangle("line", ix, PANEL_Y-30, 240, 260, 6,6)
        love.graphics.setColor(0.5, 0.7, 1.0)
        love.graphics.printf("Controls", ix+10, PANEL_Y-18, 220, "left")
        love.graphics.setColor(0.55, 0.65, 0.85)
        local lines = {
            "UP/DOWN  select channel",
            "LEFT/RIGHT  adjust volume",
            "SPACE  toggle channel on/off",
            "]  pitch up (SFX)",
            "[  pitch down (SFX)",
            "S  toggle spatial demo",
            "",
            "All channels multiply",
            "against Master vol.",
        }
        for i, line in ipairs(lines) do
            love.graphics.print(line, ix+12, PANEL_Y + (i-1)*22)
        end

    else
        -- ---- Spatial audio demo ----
        love.graphics.setColor(0.35, 0.50, 0.80)
        love.graphics.printf("Spatial Audio", 0, PANEL_Y-22, W, "center")
        love.graphics.setColor(0.45, 0.55, 0.75)
        love.graphics.printf("Sound orbits the listener — panning simulates 3D position", 0, PANEL_Y, W, "center")

        -- Draw listener
        local lx = W/2
        local ly = H/2
        love.graphics.setColor(0.3, 0.6, 1.0, 0.3)
        love.graphics.circle("fill", lx, ly, emitter.radius)
        love.graphics.setColor(0.3, 0.6, 1.0, 0.5)
        love.graphics.circle("line", lx, ly, emitter.radius)
        love.graphics.setColor(0.4, 0.7, 1.0)
        love.graphics.circle("fill", lx, ly, 14)
        love.graphics.setColor(0,0,0,0.5)
        love.graphics.printf("L", lx-6, ly-8, 12, "center")

        -- Draw emitter
        love.graphics.setColor(1.0, 0.7, 0.2, 0.8)
        local pulse = 0.7 + math.sin(time*6)*0.3
        love.graphics.circle("fill", emitter.x, emitter.y, 14*pulse)
        love.graphics.setColor(1,1,1,0.9)
        love.graphics.printf("S", emitter.x-6, emitter.y-8, 12, "center")

        -- Line from listener to emitter
        love.graphics.setColor(0.5, 0.5, 0.5, 0.4)
        love.graphics.line(lx, ly, emitter.x, emitter.y)

        -- Distance label
        local dist = math.sqrt((emitter.x-lx)^2 + (emitter.y-ly)^2)
        love.graphics.setColor(0.6, 0.7, 0.9)
        love.graphics.printf(string.format("dist: %.0fpx", dist),
            (lx+emitter.x)/2, (ly+emitter.y)/2 - 16, 80, "center")
    end

    Utils.drawHUD("VOLUME CONTROL",
        "UP/DOWN select    LT/RT volume    SPACE on/off    [/] pitch    S spatial    ESC back")
end

function Example.keypressed(key)
    if key == "s" then
        showSpatial = not showSpatial
        if showSpatial then
            if spatialSource and not spatialSource:isPlaying() then
                spatialSource:play()
            end
        else
            if spatialSource then spatialSource:stop() end
        end

    elseif key == "up" then
        selectedChannel = (selectedChannel - 2) % #channels + 1
    elseif key == "down" then
        selectedChannel = selectedChannel % #channels + 1

    elseif key == "left" then
        channels[selectedChannel].volume =
            math.max(0, channels[selectedChannel].volume - 0.05)
        applyVolumes()
    elseif key == "right" then
        channels[selectedChannel].volume =
            math.min(1, channels[selectedChannel].volume + 0.05)
        applyVolumes()

    elseif key == "space" then
        -- Toggle channel playback (2-5 only)
        local i = selectedChannel
        if i > 1 and channelSources[i] then
            if channelSources[i]:isPlaying() then
                channelSources[i]:stop()
            else
                channelSources[i]:play()
            end
        end

    elseif key == "]" then
        pitchValue = math.min(2.0, pitchValue + 0.05)
        if channelSources[3] then channelSources[3]:setPitch(pitchValue) end
    elseif key == "[" then
        pitchValue = math.max(0.25, pitchValue - 0.05)
        if channelSources[3] then channelSources[3]:setPitch(pitchValue) end
    end

    Utils.handlePause(key, Example)
end

return Example
