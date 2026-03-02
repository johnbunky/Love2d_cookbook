-- src/states/examples/audio_demo.lua
-- Demonstrates: procedural audio, SoundData, sources, pitch/volume/looping

local Utils   = require("src.utils")
local Timer   = require("src.systems.timer")
local Example = {}

local W, H
local timer
local time = 0

-- -------------------------
-- Procedural sound generation
-- All sounds built from SoundData  -  no asset files needed
-- -------------------------
local sounds = {}   -- { name, source, desc, playing }

-- Generate a sine wave tone
local function makeTone(freq, duration, volume, fadeOut)
    local rate    = 44100
    local samples = math.floor(rate * duration)
    local sd      = love.sound.newSoundData(samples, rate, 16, 1)
    volume = volume or 0.6
    for i = 0, samples - 1 do
        local t   = i / rate
        local env = fadeOut and (1 - t/duration) or 1.0
        local v   = math.sin(2 * math.pi * freq * t) * volume * env
        sd:setSample(i, v)
    end
    return love.audio.newSource(sd, "static")
end

-- Generate a noise burst (explosion/hit)
local function makeNoise(duration, volume, lowPass)
    local rate    = 44100
    local samples = math.floor(rate * duration)
    local sd      = love.sound.newSoundData(samples, rate, 16, 1)
    volume = volume or 0.5
    local prev = 0
    for i = 0, samples - 1 do
        local t   = i / rate
        local env = 1 - (t / duration)^0.5
        local raw = (math.random() * 2 - 1) * volume * env
        -- simple one-pole low-pass filter
        local alpha = lowPass or 1.0
        prev = prev + alpha * (raw - prev)
        sd:setSample(i, prev)
    end
    return love.audio.newSource(sd, "static")
end

-- Generate a chirp (rising/falling frequency sweep)
local function makeChirp(f0, f1, duration, volume)
    local rate    = 44100
    local samples = math.floor(rate * duration)
    local sd      = love.sound.newSoundData(samples, rate, 16, 1)
    volume = volume or 0.5
    local phase = 0
    for i = 0, samples - 1 do
        local t    = i / rate
        local env  = math.sin(math.pi * t / duration)  -- bell envelope
        local freq = f0 + (f1 - f0) * (t / duration)
        phase      = phase + 2 * math.pi * freq / rate
        sd:setSample(i, math.sin(phase) * volume * env)
    end
    return love.audio.newSource(sd, "static")
end

-- Generate a pulse wave (retro blip)
local function makePulse(freq, duration, duty, volume)
    local rate    = 44100
    local samples = math.floor(rate * duration)
    local sd      = love.sound.newSoundData(samples, rate, 16, 1)
    duty   = duty   or 0.5
    volume = volume or 0.4
    local period = rate / freq
    for i = 0, samples - 1 do
        local t   = i / rate
        local env = math.max(0, 1 - t/duration)
        local v   = (i % period < period * duty) and volume or -volume
        sd:setSample(i, v * env)
    end
    return love.audio.newSource(sd, "static")
end

-- Generate a simple "music" loop using additive sine waves
local function makeAmbient(duration)
    local rate    = 44100
    local samples = math.floor(rate * duration)
    local sd      = love.sound.newSoundData(samples, rate, 16, 1)
    -- A minor chord: A3(220) C4(261) E4(330) + some harmonics
    local freqs   = {220, 261, 330, 440, 110}
    local vols    = {0.15,0.12,0.10,0.06,0.08}
    for i = 0, samples - 1 do
        local t = i / rate
        local v = 0
        for fi, f in ipairs(freqs) do
            v = v + math.sin(2*math.pi*f*t) * vols[fi]
        end
        -- Soft tremolo
        v = v * (0.85 + math.sin(2*math.pi*1.5*t)*0.15)
        sd:setSample(i, v)
    end
    return love.audio.newSource(sd, "static")
end

-- Generate footstep
local function makeFootstep()
    local rate    = 44100
    local samples = math.floor(rate * 0.08)
    local sd      = love.sound.newSoundData(samples, rate, 16, 1)
    local prev    = 0
    for i = 0, samples - 1 do
        local t   = i / rate
        local env = math.exp(-t * 60)
        local raw = (math.random()*2-1) * 0.6 * env
        prev = prev + 0.15 * (raw - prev)
        sd:setSample(i, prev)
    end
    return love.audio.newSource(sd, "static")
end

-- -------------------------
-- Sound catalogue
-- -------------------------
local catalogue = {
    { name="Sine Tone",   desc="440 Hz sine, fade-out envelope",       key="1" },
    { name="Low Tone",    desc="110 Hz sine, bass rumble",             key="2" },
    { name="Explosion",   desc="White noise + low-pass + decay",       key="3" },
    { name="Laser",       desc="Chirp 800>80 Hz sweep",                key="4" },
    { name="Powerup",     desc="Chirp 200>1200 Hz sweep",              key="5" },
    { name="Blip",        desc="Pulse wave 880 Hz retro blip",         key="6" },
    { name="Jump",        desc="Pulse wave 220>440 Hz",                key="7" },
    { name="Footstep",    desc="Short filtered noise burst",           key="8" },
    { name="Ambient",     desc="A-minor chord loop (toggle)",          key="9" },
}

local sources   = {}
local selected  = 1
local ambientOn = false
local visualBars= {}  -- waveform visualization

-- Waveform display data
local waveData  = nil
local waveLen   = 200

local function buildSounds()
    -- Cleanup old
    for _, src in ipairs(sources) do
        if src then src:stop() end
    end
    sources = {}

    sources[1] = makeTone(440,  0.8, 0.5, true)
    sources[2] = makeTone(110,  1.0, 0.5, true)
    sources[3] = makeNoise(0.4, 0.6, 0.08)
    sources[4] = makeChirp(800, 80,  0.5, 0.5)
    sources[5] = makeChirp(200, 1200,0.4, 0.5)
    sources[6] = makePulse(880, 0.3, 0.5, 0.4)
    sources[7] = makeChirp(220, 440, 0.3, 0.5)
    sources[8] = makeFootstep()
    sources[9] = makeAmbient(4.0)
    sources[9]:setLooping(true)
end

local function playSound(idx)
    local src = sources[idx]
    if not src then return end
    if idx == 9 then
        -- Toggle ambient loop
        if src:isPlaying() then
            src:stop()
            ambientOn = false
        else
            src:play()
            ambientOn = true
        end
    else
        src:stop()
        src:seek(0)
        src:play()
    end
end

-- Waveform snapshot for display
local function captureWave(idx)
    local src = sources[idx]
    if not src then return end
    -- We can't read back from a Source directly  -  show a static preview
    -- from SoundData via re-synthesis for display only
    visualBars = {}
    local freq = ({440,110,200,400,600,880,300,100,220})[idx] or 440
    for i = 1, waveLen do
        local t = i / waveLen * 0.05
        local v
        if idx == 3 or idx == 8 then
            v = (math.random()*2-1) * math.exp(-t*20)
        else
            v = math.sin(2*math.pi*freq*t) * math.exp(-t*4)
        end
        table.insert(visualBars, v)
    end
end

-- -------------------------
-- Enter / Exit
-- -------------------------
function Example.enter()
    W = love.graphics.getWidth()
    H = love.graphics.getHeight()
    timer  = Timer.new()
    time   = 0
    math.randomseed(os.time())
    buildSounds()
    captureWave(1)
end

function Example.exit()
    Timer.clear(timer)
    for _, src in ipairs(sources) do
        if src then src:stop() end
    end
    love.audio.stop()   -- kill anything still playing globally
end

function Example.update(dt)
    Timer.update(timer, dt)
    time = time + dt

    -- Animate waveform when sound is playing
    if sources[selected] and sources[selected]:isPlaying() then
        local freq = ({440,110,200,400,600,880,300,100,220})[selected] or 440
        for i = 1, waveLen do
            local t = i/waveLen * 0.05 + time * 0.3
            local v
            if selected == 3 or selected == 8 then
                v = math.sin(time*20+i) * 0.3 * math.exp(-math.fmod(time,1)*3)
            else
                v = math.sin(2*math.pi*freq*t)
                  * math.exp(-math.fmod(time, 2)*1.5)
            end
            visualBars[i] = v
        end
    end
end

-- -------------------------
-- Draw
-- -------------------------
function Example.draw()
    love.graphics.setColor(0.06, 0.08, 0.14)
    love.graphics.rectangle("fill", 0, 0, W, H)

    -- Title
    love.graphics.setColor(0.5, 0.7, 1.0)
    love.graphics.printf("AUDIO DEMO", 0, 24, W, "center")
    love.graphics.setColor(0.35, 0.45, 0.65)
    love.graphics.printf("All sounds generated procedurally from math  -  no audio files", 0, 46, W, "center")

    -- Sound list
    local listX  = W/2 - 280
    local listY  = 80
    local itemH  = 36

    for i, cat in ipairs(catalogue) do
        local y   = listY + (i-1)*itemH
        local sel = (i == selected)
        local playing = sources[i] and sources[i]:isPlaying()

        -- Background
        if sel then
            love.graphics.setColor(0.12, 0.25, 0.48)
            love.graphics.rectangle("fill", listX, y+2, 320, itemH-2, 4,4)
            love.graphics.setColor(0.3, 0.55, 1.0)
            love.graphics.rectangle("line", listX, y+2, 320, itemH-2, 4,4)
        end

        -- Playing indicator
        if playing then
            love.graphics.setColor(0.2, 1.0, 0.4)
            local pulse = 0.6 + math.sin(time*8)*0.4
            love.graphics.circle("fill", listX+14, y+itemH/2, 5*pulse)
        else
            love.graphics.setColor(0.25, 0.35, 0.5)
            love.graphics.circle("fill", listX+14, y+itemH/2, 4)
        end

        -- Key hint
        love.graphics.setColor(sel and 0.5 or 0.3, sel and 0.7 or 0.45, sel and 1.0 or 0.6)
        love.graphics.print("["..cat.key.."]", listX+24, y+10)

        -- Name
        love.graphics.setColor(sel and 1 or 0.75, sel and 1 or 0.75, sel and 1 or 0.85)
        love.graphics.print(cat.name, listX+60, y+10)

        -- Loop badge
        if i == 9 then
            love.graphics.setColor(ambientOn and 0.2 or 0.15,
                                   ambientOn and 0.8 or 0.4,
                                   ambientOn and 0.4 or 0.3)
            love.graphics.rectangle("fill", listX+190, y+10, 50, 16, 3,3)
            love.graphics.setColor(1,1,1,0.9)
            love.graphics.printf(ambientOn and "LOOP ON" or "LOOP", listX+190, y+11, 50, "center")
        end
    end

    -- Description panel
    local cat   = catalogue[selected]
    local descX = listX + 330
    local descY = listY

    love.graphics.setColor(0.08, 0.12, 0.22, 0.95)
    love.graphics.rectangle("fill", descX, descY, 280, 180, 6,6)
    love.graphics.setColor(0.3, 0.45, 0.75)
    love.graphics.rectangle("line", descX, descY, 280, 180, 6,6)

    love.graphics.setColor(0.6, 0.75, 1.0)
    love.graphics.printf(cat.name, descX+10, descY+12, 260, "left")
    love.graphics.setColor(0.45, 0.55, 0.75)
    love.graphics.printf(cat.desc, descX+10, descY+34, 260, "left")

    -- Waveform display
    local wx  = descX + 10
    local wy  = descY + 90
    local ww  = 260
    local wh  = 70
    love.graphics.setColor(0.05, 0.08, 0.16)
    love.graphics.rectangle("fill", wx, wy, ww, wh, 3,3)
    love.graphics.setColor(0.18, 0.25, 0.40)
    love.graphics.rectangle("line", wx, wy, ww, wh, 3,3)

    -- Center line
    love.graphics.setColor(0.2, 0.3, 0.5)
    love.graphics.line(wx, wy+wh/2, wx+ww, wy+wh/2)

    -- Wave
    if #visualBars >= 2 then
        local isPlaying = sources[selected] and sources[selected]:isPlaying()
        local r = isPlaying and 0.3 or 0.2
        local g = isPlaying and 1.0 or 0.5
        local b = isPlaying and 0.5 or 0.7
        love.graphics.setColor(r, g, b)
        local pts = {}
        for i, v in ipairs(visualBars) do
            local px = wx + (i-1) / (waveLen-1) * ww
            local py = wy + wh/2 - v * wh * 0.45
            table.insert(pts, px)
            table.insert(pts, py)
        end
        if #pts >= 4 then
            love.graphics.line(pts)
        end
    end

    -- Volume/pitch info
    if sources[selected] then
        local src = sources[selected]
        love.graphics.setColor(0.4, 0.55, 0.8)
        love.graphics.printf(
            string.format("Vol: %.1f  Pitch: %.1f  Loop: %s",
                src:getVolume(), src:getPitch(),
                src:isLooping() and "yes" or "no"),
            descX+10, descY+165, 260, "left")
    end

    Utils.drawHUD("AUDIO DEMO",
        "1-9 select+play    ENTER play    UP/DOWN navigate    ESC back")
end

function Example.keypressed(key)
    local n = tonumber(key)
    if n and n >= 1 and n <= #catalogue then
        selected = n
        playSound(n)
        captureWave(n)
        return
    end

    if key == "return" or key == "space" then
        playSound(selected)
        captureWave(selected)
    elseif key == "up" then
        selected = (selected - 2) % #catalogue + 1
        captureWave(selected)
    elseif key == "down" then
        selected = selected % #catalogue + 1
        captureWave(selected)
    end

    Utils.handlePause(key, Example)
end

function Example.mousepressed(x, y, button)
    if button ~= 1 then return end
    local listX = W/2 - 280
    local listY = 80
    local itemH = 36
    for i = 1, #catalogue do
        local iy = listY + (i-1)*itemH
        if y >= iy and y < iy+itemH and x >= listX and x < listX+320 then
            selected = i
            playSound(i)
            captureWave(i)
            return
        end
    end
end

return Example
