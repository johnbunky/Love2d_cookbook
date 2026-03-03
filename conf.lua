-- love.conf is called before love.load
function love.conf(t)
    t.title         = "LOVE2D Cookbook"
    t.version       = "11.5"
    t.window.width  = 960
    t.window.height = 540
    t.window.resizable  = true
    t.window.minwidth   = 480
    t.window.minheight  = 270
    t.window.vsync      = 1

    t.modules.joystick  = true
    t.modules.physics   = false
    t.modules.video     = false
end
