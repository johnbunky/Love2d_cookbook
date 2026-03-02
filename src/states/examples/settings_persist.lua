-- src/states/examples/settings_persist.lua
-- Demonstrates: settings file, live apply, reset to defaults, categories

local Utils    = require("src.utils")
local Timer    = require("src.systems.timer")
local Settings = require("src.systems.settings")
local Example = {}

local W, H
local timer
local time = 0

-- -------------------------
-- Settings schema + defaults
-- -------------------------
local SETTINGS_FILE = "settings.cfg"

local DEFAULTS = {
    video  = {
        fullscreen   = false,
        vsync        = true,
        brightness   = 1.0,
        gamma        = 1.0,
        showFPS      = false,
    },
    audio  = {
        masterVolume = 1.0,
        musicVolume  = 0.8,
        sfxVolume    = 1.0,
        muteAll      = false,
    },
    gameplay = {
        difficulty   = 2,      -- 1=easy 2=normal 3=hard
        autosave     = true,
        autosaveFreq = 5,      -- minutes
        language     = 1,      -- index into LANGUAGES
        showHints    = true,
    },
    controls = {
        mouseSensitivity = 1.0,
        invertY          = false,
        vibration        = true,
        keyRepeatDelay   = 0.4,
    },
}

local LANGUAGES    = {"English","Spanish","French","German","Japanese"}
local DIFFICULTIES = {"Easy","Normal","Hard","Nightmare"}

-- Settings management delegated to Settings system
-- (setup called in enter)

-- -------------------------
-- UI state
-- -------------------------
local settings     = {}
local dirtyFlag    = false   -- unsaved changes
local selectedCat  = 1
local selectedItem = 1
local flashMsg     = nil
local flashTimer   = 0

local CATEGORIES = {"video","audio","gameplay","controls"}
local CAT_LABELS  = {video="?? Video", audio="?? Audio", gameplay="?? Gameplay", controls="?? Controls"}

-- Schema for display order and control type
local SCHEMA = {
    video = {
        { key="brightness",  label="Brightness",     type="slider",  min=0.2, max=2.0, step=0.05 },
        { key="gamma",       label="Gamma",          type="slider",  min=0.5, max=2.0, step=0.05 },
        { key="vsync",       label="VSync",          type="toggle" },
        { key="fullscreen",  label="Fullscreen",     type="toggle" },
        { key="showFPS",     label="Show FPS",       type="toggle" },
    },
    audio = {
        { key="masterVolume",label="Master Volume",  type="slider",  min=0, max=1, step=0.05 },
        { key="musicVolume", label="Music Volume",   type="slider",  min=0, max=1, step=0.05 },
        { key="sfxVolume",   label="SFX Volume",     type="slider",  min=0, max=1, step=0.05 },
        { key="muteAll",     label="Mute All",       type="toggle" },
    },
    gameplay = {
        { key="difficulty",  label="Difficulty",     type="enum",    values=DIFFICULTIES },
        { key="language",    label="Language",       type="enum",    values=LANGUAGES },
        { key="autosave",    label="Auto Save",      type="toggle" },
        { key="autosaveFreq",label="Save Interval",  type="slider",  min=1, max=30, step=1 },
        { key="showHints",   label="Show Hints",     type="toggle" },
    },
    controls = {
        { key="mouseSensitivity", label="Mouse Sensitivity", type="slider", min=0.1, max=3.0, step=0.1 },
        { key="invertY",     label="Invert Y Axis",  type="toggle" },
        { key="vibration",   label="Controller Vibration", type="toggle" },
        { key="keyRepeatDelay", label="Key Repeat",  type="slider", min=0.1, max=1.0, step=0.05 },
    },
}

local function setFlash(msg, ok)
    flashMsg   = msg
    flashTimer = 2.5
    dirtyFlag  = (ok == "dirty") or dirtyFlag
    if ok == true then dirtyFlag = false end
end

local function currentSchema()
    return SCHEMA[CATEGORIES[selectedCat]]
end

local function currentValue()
    local cat = CATEGORIES[selectedCat]
    local sch = currentSchema()[selectedItem]
    if not sch then return nil end
    return settings[cat][sch.key]
end

local function modifyValue(delta)
    local cat = CATEGORIES[selectedCat]
    local sch = currentSchema()[selectedItem]
    if not sch then return end
    local v   = settings[cat][sch.key]
    if sch.type == "toggle" then
        settings[cat][sch.key] = not v
    elseif sch.type == "slider" then
        settings[cat][sch.key] = Utils.clamp(
            math.floor((v + delta*sch.step)*100+0.5)/100,
            sch.min, sch.max)
    elseif sch.type == "enum" then
        local count = #sch.values
        settings[cat][sch.key] = (v - 1 + delta + count) % count + 1
    end
    dirtyFlag = true
end

-- -------------------------
-- Enter / Exit
-- -------------------------
function Example.enter()
    W, H  = love.graphics.getWidth(), love.graphics.getHeight()
    timer = Timer.new()
    time  = 0
    Settings.setup(SETTINGS_FILE, DEFAULTS)
    Settings.load()
    settings  = Settings.all()
    dirtyFlag = false
end

function Example.exit()
    Timer.clear(timer)
end

function Example.update(dt)
    Timer.update(timer, dt)
    time = time + dt
    if flashTimer > 0 then flashTimer = flashTimer - dt end
end

-- -------------------------
-- Draw
-- -------------------------
local function drawSliderControl(x, y, w, val, minV, maxV)
    local fill = (val - minV) / (maxV - minV) * w
    love.graphics.setColor(0.10, 0.14, 0.24)
    love.graphics.rectangle("fill", x, y, w, 14, 4,4)
    love.graphics.setColor(0.3, 0.6, 1.0)
    love.graphics.rectangle("fill", x, y, fill, 14, 4,4)
    love.graphics.setColor(0.4, 0.65, 1.0)
    love.graphics.rectangle("line", x, y, w, 14, 4,4)
    love.graphics.setColor(1,1,1)
    love.graphics.circle("fill", x+fill, y+7, 7)
end

function Example.draw()
    local brightness = settings.video and settings.video.brightness or 1.0
    love.graphics.setColor(0.06*brightness, 0.08*brightness, 0.14*brightness)
    love.graphics.rectangle("fill", 0, 0, W, H)

    love.graphics.setColor(0.5, 0.7, 1.0)
    love.graphics.printf("SETTINGS", 0, 18, W, "center")

    -- Dirty indicator
    dirtyFlag = Settings.isDirty()
    if dirtyFlag then
        love.graphics.setColor(0.9, 0.6, 0.2)
        love.graphics.printf("? unsaved changes", 0, 40, W, "center")
    end

    -- Category tabs
    local tabW = 160
    local tabX = W/2 - (#CATEGORIES * tabW)/2
    local tabY = 60
    for i, cat in ipairs(CATEGORIES) do
        local sel = (i == selectedCat)
        love.graphics.setColor(sel and 0.12 or 0.07,
                               sel and 0.20 or 0.10,
                               sel and 0.38 or 0.20, 0.95)
        love.graphics.rectangle("fill", tabX+(i-1)*tabW, tabY, tabW-4, 32, 6,6)
        love.graphics.setColor(sel and 0.4 or 0.22,
                               sel and 0.62 or 0.32,
                               sel and 1.0 or 0.55)
        love.graphics.rectangle("line", tabX+(i-1)*tabW, tabY, tabW-4, 32, 6,6)
        love.graphics.setColor(sel and 1 or 0.5, sel and 1 or 0.55, sel and 1 or 0.75)
        love.graphics.printf(CAT_LABELS[cat], tabX+(i-1)*tabW, tabY+7, tabW-4, "center")
    end

    -- Settings list
    local listX = W/2 - 300
    local listY = 106
    local listW = 600
    local itemH = 42

    local cat    = CATEGORIES[selectedCat]
    local schema = SCHEMA[cat]

    love.graphics.setColor(0.07, 0.10, 0.20, 0.95)
    love.graphics.rectangle("fill", listX-8, listY-4,
        listW+16, #schema*itemH+20, 6,6)
    love.graphics.setColor(0.22, 0.32, 0.55)
    love.graphics.rectangle("line", listX-8, listY-4,
        listW+16, #schema*itemH+20, 6,6)

    for i, sch in ipairs(schema) do
        local iy    = listY + (i-1)*itemH
        local sel   = (i == selectedItem)
        local val   = settings[cat][sch.key]

        if sel then
            love.graphics.setColor(0.10, 0.18, 0.35, 0.8)
            love.graphics.rectangle("fill", listX-6, iy+2, listW+12, itemH-4, 4,4)
        end

        -- Label
        love.graphics.setColor(sel and 0.9 or 0.65, sel and 0.9 or 0.72, sel and 1.0 or 0.88)
        love.graphics.print(sch.label, listX+10, iy+12)

        -- Control
        local cx = listX + listW - 220
        if sch.type == "toggle" then
            love.graphics.setColor(val and 0.2 or 0.1,
                                   val and 0.7 or 0.25,
                                   val and 0.4 or 0.2)
            love.graphics.rectangle("fill", cx, iy+10, 60, 22, 11,11)
            love.graphics.setColor(val and 0.4 or 0.25,
                                   val and 1.0 or 0.35,
                                   val and 0.6 or 0.35)
            love.graphics.rectangle("line", cx, iy+10, 60, 22, 11,11)
            love.graphics.setColor(1,1,1)
            love.graphics.circle("fill", val and cx+46 or cx+14, iy+21, 9)
            love.graphics.setColor(0.6,0.75,0.9)
            love.graphics.printf(val and "ON" or "OFF", cx+64, iy+13, 40, "left")

        elseif sch.type == "slider" then
            drawSliderControl(cx, iy+12, 200, val, sch.min, sch.max)
            love.graphics.setColor(0.7, 0.82, 1.0)
            love.graphics.printf(string.format("%.2f", val), cx+208, iy+10, 60, "left")

        elseif sch.type == "enum" then
            local label = sch.values[val] or "?"
            love.graphics.setColor(0.2, 0.35, 0.65)
            love.graphics.rectangle("fill", cx-20, iy+10, 220, 22, 4,4)
            love.graphics.setColor(0.35, 0.55, 0.9)
            love.graphics.rectangle("line", cx-20, iy+10, 220, 22, 4,4)
            love.graphics.setColor(sel and 0.3 or 0.2, sel and 0.6 or 0.35, sel and 1.0 or 0.65)
            love.graphics.printf("?", cx-16, iy+12, 20, "center")
            love.graphics.setColor(1,1,1)
            love.graphics.printf(label, cx+4, iy+12, 176, "center")
            love.graphics.setColor(sel and 0.3 or 0.2, sel and 0.6 or 0.35, sel and 1.0 or 0.65)
            love.graphics.printf("?", cx+182, iy+12, 20, "center")
        end
    end

    -- FPS counter (if enabled)
    if settings.video and settings.video.showFPS then
        love.graphics.setColor(0.3, 1.0, 0.5)
        love.graphics.printf("FPS: "..love.timer.getFPS(), W-90, 4, 80, "right")
    end

    -- Flash message
    if flashTimer > 0 then
        local a = math.min(1, flashTimer)
        love.graphics.setColor(0.08, 0.22, 0.12, a*0.9)
        love.graphics.rectangle("fill", W/2-180, H-90, 360, 38, 6,6)
        love.graphics.setColor(0.3, 1.0, 0.5, a)
        love.graphics.rectangle("line", W/2-180, H-90, 360, 38, 6,6)
        love.graphics.setColor(1,1,1,a)
        love.graphics.printf(flashMsg or "", W/2-170, H-80, 340, "center")
    end

    Utils.drawHUD("SETTINGS",
        "TAB/?/? category    ?/? item    ?/? adjust    F5 save    R reset    ESC back")
end

-- -------------------------
-- Input
-- -------------------------
function Example.keypressed(key)
    local catCount  = #CATEGORIES
    local itemCount = #currentSchema()

    if key == "tab" or key == "right" and selectedItem == 0 then
        selectedCat  = selectedCat % catCount + 1
        selectedItem = 1
    elseif key == "up" then
        selectedItem = (selectedItem - 2) % itemCount + 1
    elseif key == "down" then
        selectedItem = selectedItem % itemCount + 1
    elseif key == "left" then
        local sch = currentSchema()[selectedItem]
        if sch and sch.type == "slider" or (sch and sch.type == "enum") then
            modifyValue(-1)
        elseif sch and sch.type == "toggle" then
            modifyValue(0)  -- toggle on any direction
        end
    elseif key == "right" then
        modifyValue(1)
    elseif key == "space" or key == "return" then
        modifyValue(1)

    elseif key == "f5" then
        -- sync back then save
        for cat, vals in pairs(settings) do
            for k, v in pairs(vals) do Settings.set(cat, k, v) end
        end
        Settings.save()
        setFlash("Settings saved!", true)
    elseif key == "r" then
        Settings.reset()
        settings  = Settings.all()
        dirtyFlag = true
        setFlash("Reset to defaults")
    elseif key == "1" then selectedCat = 1; selectedItem = 1
    elseif key == "2" then selectedCat = 2; selectedItem = 1
    elseif key == "3" then selectedCat = 3; selectedItem = 1
    elseif key == "4" then selectedCat = 4; selectedItem = 1
    end

    Utils.handlePause(key, Example)
end

return Example
