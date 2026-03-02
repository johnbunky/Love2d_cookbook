-- love.conf is called before love.load
-- All window and module settings go here

function love.conf(t)
    t.title        = "MyGame"
    t.version      = "11.5"       -- LÖVE version this game was made for
    t.window.width  = 800
    t.window.height = 600
    t.window.resizable = false
    t.window.vsync  = 1

    -- Disable unused modules to save memory
    t.modules.joystick  = true    -- needed for gamepad support
    t.modules.physics   = false   -- not using box2d
    t.modules.video     = false
end
