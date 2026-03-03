-- main.lua
-- Entry point. Stays thin — just hooks love callbacks into Gamestate.
-- All real logic lives in states and src/

-- Globals available to all states
Gamestate   = require("src.gamestate")
Input       = require("src.input")
Transition  = require("src.systems.transition")

local MenuState     = require("src.states.menu")
local PauseState    = require("src.states.pause")
local GameoverState = require("src.states.gameover")

-- Core
local TopdownMovement   = require("src.states.examples.topdown_movement")
local PlatformerMovement= require("src.states.examples.platformer_movement")
local Camera            = require("src.states.examples.camera")
local Tilemap           = require("src.states.examples.tilemap")
local CollisionDemo     = require("src.states.examples.collision_demo")
local PlatformerLevel   = require("src.states.examples.platformer_level")
-- Polish
local Animation         = require("src.states.examples.animation")
local ScreenShake       = require("src.states.examples.screen_shake")
local Transitions       = require("src.states.examples.transitions")
local Hud               = require("src.states.examples.hud")
-- Combat
local Shooter           = require("src.states.examples.shooter")
local MeleeAttack       = require("src.states.examples.melee_attack")
local EnemyAI           = require("src.states.examples.enemy_ai")
local Pathfinding       = require("src.states.examples.pathfinding")
local HealthDamage      = require("src.states.examples.health_damage")
local Particles         = require("src.states.examples.particles")
-- UI
local NavMenu           = require("src.states.examples.nav_menu")
local Inventory         = require("src.states.examples.inventory")
local Dialog            = require("src.states.examples.dialog")
-- Visual
local Parallax          = require("src.states.examples.parallax")
local DayNight          = require("src.states.examples.day_night")
local Lighting          = require("src.states.examples.lighting")
local Shaders           = require("src.states.examples.shaders")
local PostFX            = require("src.states.examples.post_fx")
local Basics3D          = require("src.states.examples.basics_3d")
local Billboards        = require("src.states.examples.billboards")
local IsoTopdown        = require("src.states.examples.iso_topdown")
local SaveLoad          = require("src.states.examples.save_load")
local HighScore         = require("src.states.examples.high_score")
local SettingsPersist   = require("src.states.examples.settings_persist")
-- Audio
local AudioDemo         = require("src.states.examples.audio_demo")
local VolumeControl     = require("src.states.examples.volume_control")
-- Input
local VirtualJoystick   = require("src.states.examples.virtual_joystick")
local GamepadDemo       = require("src.states.examples.gamepad_demo")
local KeyboardMouseDemo = require("src.states.examples.keyboard_mouse_demo")
-- Data
local SaveLoad          = require("src.states.examples.save_load")
local HighScore         = require("src.states.examples.high_score")
local SettingsPersist   = require("src.states.examples.settings_persist")

States = {
    menu                = MenuState,
    pause               = PauseState,
    gameover            = GameoverState,
    -- core
    topdown_movement    = TopdownMovement,
    platformer_movement = PlatformerMovement,
    camera              = Camera,
    tilemap             = Tilemap,
    collision_demo      = CollisionDemo,
    platformer_level    = PlatformerLevel,
    -- polish
    animation           = Animation,
    screen_shake        = ScreenShake,
    transitions         = Transitions,
    hud                 = Hud,
    -- combat
    shooter             = Shooter,
    melee_attack        = MeleeAttack,
    enemy_ai            = EnemyAI,
    pathfinding         = Pathfinding,
    health_damage       = HealthDamage,
    particles           = Particles,
    -- ui
    nav_menu            = NavMenu,
    inventory           = Inventory,
    dialog              = Dialog,
    -- visual
    parallax            = Parallax,
    day_night           = DayNight,
    lighting            = Lighting,
    shaders             = Shaders,
    post_fx             = PostFX,
    basics_3d           = Basics3D,
    billboards          = Billboards,
    iso_topdown         = IsoTopdown,
    save_load           = SaveLoad,
    high_score          = HighScore,
    settings_persist    = SettingsPersist,
    -- audio
    audio_demo          = AudioDemo,
    volume_control      = VolumeControl,
    -- input
    virtual_joystick    = VirtualJoystick,
    gamepad_demo        = GamepadDemo,
    keyboard_mouse_demo = KeyboardMouseDemo,
    -- data
    save_load           = SaveLoad,
    high_score          = HighScore,
    settings_persist    = SettingsPersist,
}

function love.load()
    Gamestate.switch(States.menu)
end

function love.update(dt)
    Input.update(dt)
    Gamestate.update(dt)
    Transition.update(dt)
    Input.lateUpdate()
end

function love.draw()
    Gamestate.draw()
    Transition.draw()
end

function love.wheelmoved(x, y)
    Input.wheelmoved(x, y)
    Gamestate.wheelmoved(x, y)
end

function love.keypressed(key)
    if key == "escape" then
        if Gamestate.current() == States.menu then
            love.event.quit()
        elseif Gamestate.current() ~= States.pause then
            Gamestate.switch(States.menu)
        end
    end
    Gamestate.keypressed(key)
end

function love.mousepressed(x, y, button)
    if isTouchDevice then return end  -- Android fires both; touch handles it
    Gamestate.mousepressed(x, y, button)
end

function love.mousemoved(x, y, dx, dy)
    Input.mouseX, Input.mouseY = x, y
    Gamestate.mousemoved(x, y, dx, dy)
end
function love.mousereleased(x, y, button)
    Gamestate.mousereleased(x, y, button)
end

local isTouchDevice = false  -- set on first touch, used by states

function love.touchpressed(id, x, y, dx, dy, pressure)
    isTouchDevice = true
    Input.touchpressed(id, x, y)
    Gamestate.touchpressed(id, x, y, dx, dy, pressure)
end

function love.touchreleased(id, x, y)
    Input.touchreleased(id, x, y)
    Gamestate.touchreleased(id, x, y)
end

function love.touchmoved(id, x, y)
    Input.touchmoved(id, x, y)
    Gamestate.touchmoved(id, x, y)
end

function love.gamepadpressed(joystick, button)
    Gamestate.gamepadpressed(joystick, button)
end

function love.joystickadded(joystick)
    Input.gamepadAdded(joystick)
    Gamestate.joystickadded(joystick)
end

function love.joystickremoved(joystick)
    Input.gamepadRemoved(joystick)
    Gamestate.joystickremoved(joystick)
end

function love.keyreleased(key)
    Gamestate.keyreleased(key)
end

function love.textinput(text)
    Gamestate.textinput(text)
end
