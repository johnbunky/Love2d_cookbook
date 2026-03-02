-- src/states/examples/shaders.lua
-- Demonstrates: GLSL shaders in LÖVE, uniforms, canvas, live editing

local Utils  = require("src.utils")
local Timer  = require("src.systems.timer")
local Example = {}

local W, H
local timer
local canvas       -- scene drawn here, shader applied on top
local time = 0

-- -------------------------
-- Shader catalogue
-- Each entry: name, description, uniforms, code
-- -------------------------
local shaderDefs = {}

table.insert(shaderDefs, {
    name = "Passthrough",
    desc = "No effect. Raw canvas output.",
    uniforms = {},
    code = [[
        vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
            return Texel(tex, tc);
        }
    ]],
})

table.insert(shaderDefs, {
    name = "Invert",
    desc = "Inverts all RGB channels.",
    uniforms = { { name="amount", label="Amount", min=0, max=1, value=1.0 } },
    code = [[
        extern float amount;
        vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
            vec4 c = Texel(tex, tc);
            vec3 inv = 1.0 - c.rgb;
            return vec4(mix(c.rgb, inv, amount), c.a);
        }
    ]],
})

table.insert(shaderDefs, {
    name = "Grayscale",
    desc = "Desaturates using luminance weights.",
    uniforms = { { name="amount", label="Amount", min=0, max=1, value=1.0 } },
    code = [[
        extern float amount;
        vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
            vec4 c  = Texel(tex, tc);
            float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
            return vec4(mix(c.rgb, vec3(g), amount), c.a);
        }
    ]],
})

table.insert(shaderDefs, {
    name = "Vignette",
    desc = "Darkens screen edges. Strength controls falloff.",
    uniforms = { { name="strength", label="Strength", min=0, max=3, value=1.2 } },
    code = [[
        extern float strength;
        vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
            vec4 c  = Texel(tex, tc);
            vec2 uv = tc - 0.5;
            float v = 1.0 - smoothstep(0.3, 0.85, length(uv) * (1.0 + strength));
            return vec4(c.rgb * v, c.a);
        }
    ]],
})

table.insert(shaderDefs, {
    name = "Blur",
    desc = "3x3 Gaussian blur kernel.",
    uniforms = { { name="spread", label="Spread", min=0.5, max=4, value=1.0 } },
    code = [[
        extern vec2 resolution;
        extern float spread;
        vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
            vec2 px = spread / resolution;
            vec4 c = vec4(0.0);
            c += Texel(tex, tc+vec2(-px.x,-px.y))*0.077;
            c += Texel(tex, tc+vec2( 0.0, -px.y))*0.123;
            c += Texel(tex, tc+vec2( px.x,-px.y))*0.077;
            c += Texel(tex, tc+vec2(-px.x, 0.0 ))*0.123;
            c += Texel(tex, tc                  )*0.200;
            c += Texel(tex, tc+vec2( px.x, 0.0 ))*0.123;
            c += Texel(tex, tc+vec2(-px.x, px.y))*0.077;
            c += Texel(tex, tc+vec2( 0.0,  px.y))*0.123;
            c += Texel(tex, tc+vec2( px.x, px.y))*0.077;
            return c;
        }
    ]],
})

table.insert(shaderDefs, {
    name = "Chromatic Aberration",
    desc = "Splits RGB channels outward from center.",
    uniforms = { { name="strength", label="Strength", min=0, max=5, value=1.5 } },
    code = [[
        extern float strength;
        vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
            vec2 offset = (tc - 0.5) * strength * 0.012;
            float r = Texel(tex, tc + offset).r;
            float g = Texel(tex, tc).g;
            float b = Texel(tex, tc - offset).b;
            return vec4(r, g, b, 1.0);
        }
    ]],
})

table.insert(shaderDefs, {
    name = "Pixelate",
    desc = "Snaps pixels to a grid. Bigger = blockier.",
    uniforms = { { name="pixelSize", label="Pixel Size", min=1, max=20, value=4 } },
    code = [[
        extern vec2 resolution;
        extern float pixelSize;
        vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
            vec2 px      = pixelSize / resolution;
            vec2 snapped = floor(tc / px) * px + px * 0.5;
            return Texel(tex, snapped);
        }
    ]],
})

table.insert(shaderDefs, {
    name = "CRT",
    desc = "Barrel distortion, scanlines, RGB shift.",
    uniforms = {
        { name="scanlines", label="Scanlines", min=0, max=0.8, value=0.25 },
        { name="warp",      label="Warp",      min=0, max=0.2, value=0.04 },
    },
    code = [[
        extern float scanlines;
        extern float warp;
        extern float time;
        vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
            vec2 uv = tc - 0.5;
            uv *= 1.0 + warp * dot(uv, uv);
            uv += 0.5;
            if (uv.x<0.0||uv.x>1.0||uv.y<0.0||uv.y>1.0)
                return vec4(0.0,0.0,0.0,1.0);
            vec4 c = Texel(tex, uv);
            c.rgb *= 1.0 - sin(uv.y * 800.0) * scanlines;
            c.r    = Texel(tex, uv+vec2( 0.0015,0.0)).r;
            c.b    = Texel(tex, uv+vec2(-0.0015,0.0)).b;
            return c;
        }
    ]],
})

table.insert(shaderDefs, {
    name = "Wave",
    desc = "Animated sine wave distortion.",
    uniforms = {
        { name="amplitude", label="Amplitude", min=0, max=20, value=6  },
        { name="frequency", label="Frequency", min=1, max=30, value=10 },
        { name="speed",     label="Speed",     min=0, max=10, value=3  },
    },
    code = [[
        extern float amplitude;
        extern float frequency;
        extern float speed;
        extern float time;
        extern vec2  resolution;
        vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
            vec2 uv  = tc;
            uv.x    += sin(uv.y * frequency + time * speed) * amplitude / resolution.x;
            uv.y    += sin(uv.x * frequency + time * speed) * amplitude / resolution.y;
            return Texel(tex, clamp(uv, 0.0, 1.0));
        }
    ]],
})

table.insert(shaderDefs, {
    name = "Tint",
    desc = "Multiplies all pixels by a chosen color.",
    uniforms = {
        { name="tintR", label="Red",   min=0, max=1, value=1.0 },
        { name="tintG", label="Green", min=0, max=1, value=0.4 },
        { name="tintB", label="Blue",  min=0, max=1, value=0.4 },
    },
    code = [[
        extern float tintR;
        extern float tintG;
        extern float tintB;
        vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
            vec4 c = Texel(tex, tc);
            return vec4(c.r*tintR, c.g*tintG, c.b*tintB, c.a);
        }
    ]],
})

-- -------------------------
-- Compile all shaders
-- -------------------------
local compiled = {}
local function compileAll()
    compiled = {}
    for i, def in ipairs(shaderDefs) do
        local ok, sh = pcall(love.graphics.newShader, def.code)
        if ok then
            compiled[i] = sh
        else
            compiled[i] = nil
            print("Shader error ["..def.name.."]: "..tostring(sh))
        end
    end
end

-- -------------------------
-- State
-- -------------------------
local selected = 1
local scene_objs = {}

local function buildScene()
    scene_objs = {}
    math.randomseed(77)
    -- Colorful shapes as test scene
    for _ = 1, 18 do
        table.insert(scene_objs, {
            type  = math.random(1,3),
            x     = math.random(60, W-60),
            y     = math.random(80, H-80),
            size  = math.random(20, 60),
            r     = math.random(30,100)/100,
            g     = math.random(30,100)/100,
            b     = math.random(30,100)/100,
            rot   = math.random()*math.pi*2,
            rotV  = (math.random()-0.5)*1.5,
        })
    end
end

function Example.enter()
    W = love.graphics.getWidth()
    H = love.graphics.getHeight()
    timer   = Timer.new()
    time    = 0
    canvas  = love.graphics.newCanvas(W, H)
    selected = 1
    buildScene()
    compileAll()
end

function Example.exit()
    Timer.clear(timer)
end

function Example.update(dt)
    Timer.update(timer, dt)
    time = time + dt
    for _, obj in ipairs(scene_objs) do
        obj.rot = obj.rot + obj.rotV * dt
    end
end

-- -------------------------
-- Draw the test scene to canvas
-- -------------------------
local function drawScene()
    love.graphics.setColor(0.08, 0.09, 0.14)
    love.graphics.rectangle("fill", 0, 0, W, H)

    -- Grid
    love.graphics.setColor(0.12, 0.14, 0.20)
    for x = 0, W, 40 do love.graphics.line(x,0,x,H) end
    for y = 0, H, 40 do love.graphics.line(0,y,W,y) end

    -- Gradient circle in center
    for i = 8, 1, -1 do
        local t = i/8
        love.graphics.setColor(t*0.3, t*0.5, t*0.9, 0.6)
        love.graphics.circle("fill", W/2, H/2, i*35)
    end

    -- Shapes
    for _, obj in ipairs(scene_objs) do
        love.graphics.push()
        love.graphics.translate(obj.x, obj.y)
        love.graphics.rotate(obj.rot)
        love.graphics.setColor(obj.r, obj.g, obj.b)
        if obj.type == 1 then
            love.graphics.rectangle("fill", -obj.size/2, -obj.size/2, obj.size, obj.size, 4,4)
        elseif obj.type == 2 then
            love.graphics.circle("fill", 0, 0, obj.size/2)
        else
            love.graphics.polygon("fill",
                0, -obj.size/2,
                obj.size/2, obj.size/2,
                -obj.size/2, obj.size/2)
        end
        love.graphics.pop()
    end

    -- Text samples (good for blur/CRT)
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.printf("SHADER TEST SCENE", 0, H*0.08, W, "center")
    love.graphics.setColor(0.5, 0.7, 1.0)
    love.graphics.printf("abcdefghijklmnopqrstuvwxyz  0123456789", 0, H*0.88, W, "center")
end

-- -------------------------
-- Draw shader selector panel
-- -------------------------
local PANEL_W = 200
local function drawPanel()
    local px = W - PANEL_W
    love.graphics.setColor(0.06, 0.08, 0.14, 0.96)
    love.graphics.rectangle("fill", px, 0, PANEL_W, H)
    love.graphics.setColor(0.25, 0.35, 0.55)
    love.graphics.line(px, 0, px, H)

    love.graphics.setColor(0.5, 0.7, 1.0)
    love.graphics.printf("SHADERS", px, 10, PANEL_W, "center")

    local itemH = 32
    for i, def in ipairs(shaderDefs) do
        local iy  = 38 + (i-1)*itemH
        local sel = (i == selected)
        if sel then
            love.graphics.setColor(0.18, 0.30, 0.55)
            love.graphics.rectangle("fill", px+4, iy, PANEL_W-8, itemH-2, 4,4)
            love.graphics.setColor(0.4, 0.65, 1.0)
            love.graphics.rectangle("line", px+4, iy, PANEL_W-8, itemH-2, 4,4)
        end
        love.graphics.setColor(sel and 1 or 0.65, sel and 1 or 0.65, sel and 1 or 0.7)
        love.graphics.printf(def.name, px+6, iy+8, PANEL_W-12, "left")
        -- Keyboard hint
        love.graphics.setColor(0.3, 0.4, 0.6)
        love.graphics.printf("["..i.."]", px+6, iy+8, PANEL_W-12, "right")
    end

    -- Description + uniforms for selected
    local def = shaderDefs[selected]
    local uy  = 38 + #shaderDefs*itemH + 14

    love.graphics.setColor(0.25, 0.35, 0.55)
    love.graphics.line(px, uy-8, W, uy-8)

    love.graphics.setColor(0.55, 0.70, 0.90)
    love.graphics.printf(def.name, px+8, uy, PANEL_W-16, "left")
    uy = uy + 18

    love.graphics.setColor(0.50, 0.55, 0.65)
    love.graphics.printf(def.desc, px+8, uy, PANEL_W-16, "left")
    uy = uy + 36

    -- Uniform sliders
    for _, u in ipairs(def.uniforms) do
        love.graphics.setColor(0.55, 0.65, 0.80)
        love.graphics.print(u.label..":", px+10, uy)
        love.graphics.setColor(0.75, 0.85, 1.0)
        love.graphics.printf(string.format("%.2f", u.value), px+10, uy, PANEL_W-20, "right")
        uy = uy + 16

        -- Track
        local tw = PANEL_W - 20
        love.graphics.setColor(0.15, 0.20, 0.35)
        love.graphics.rectangle("fill", px+10, uy, tw, 8, 3,3)
        local fill = (u.value - u.min) / (u.max - u.min) * tw
        love.graphics.setColor(0.35, 0.60, 1.0)
        love.graphics.rectangle("fill", px+10, uy, fill, 8, 3,3)
        uy = uy + 18
    end

    -- GLSL code snippet
    if uy + 20 < H - 50 then
        love.graphics.setColor(0.25, 0.35, 0.55)
        love.graphics.line(px, uy+4, W, uy+4)
        uy = uy + 12
        love.graphics.setColor(0.30, 0.40, 0.55)
        love.graphics.printf("GLSL:", px+8, uy, PANEL_W-16, "left")
        uy = uy + 16
        -- Show a trimmed version of the code
        local codeLines = {}
        for line in def.code:gmatch("[^\n]+") do
            line = line:match("^%s*(.-)%s*$")
            if line ~= "" then table.insert(codeLines, line) end
        end
        love.graphics.setColor(0.40, 0.55, 0.45)
        for i = 1, math.min(#codeLines, 8) do
            if uy + 14 > H - 40 then break end
            love.graphics.print(codeLines[i]:sub(1, 26), px+8, uy)
            uy = uy + 13
        end
    end
end

function Example.draw()
    local def = shaderDefs[selected]
    local sh  = compiled[selected]

    -- Draw scene to canvas
    love.graphics.setCanvas(canvas)
    love.graphics.clear()
    drawScene()
    love.graphics.setCanvas()

    -- Apply shader
    if sh then
        -- Send uniforms
        pcall(function() sh:send("resolution", {W - PANEL_W, H}) end)
        pcall(function() sh:send("time", time) end)
        for _, u in ipairs(def.uniforms) do
            pcall(function() sh:send(u.name, u.value) end)
        end
        love.graphics.setShader(sh)
    end
    -- Draw canvas (only scene area, not panel)
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(canvas, 0, 0)
    love.graphics.setShader()

    drawPanel()

    Utils.drawHUD("SHADERS",
        "1-"..#shaderDefs.." select    <- -> adjust uniform    ESC back")
end

function Example.keypressed(key)
    local n = tonumber(key)
    if n and n >= 1 and n <= #shaderDefs then
        selected = n
        return
    end

    local def = shaderDefs[selected]
    -- Adjust first uniform with left/right
    local u = def.uniforms[1]
    if u then
        local step = (u.max - u.min) / 20
        if key == "right" or key == "d" then
            u.value = math.min(u.max, u.value + step)
        elseif key == "left" or key == "a" then
            u.value = math.max(u.min, u.value - step)
        end
        -- Adjust second uniform with up/down
        local u2 = def.uniforms[2]
        if u2 then
            local step2 = (u2.max - u2.min) / 20
            if key == "up" or key == "w" then
                u2.value = math.min(u2.max, u2.value + step2)
            elseif key == "down" or key == "s" then
                u2.value = math.max(u2.min, u2.value - step2)
            end
        end
    end

    Utils.handlePause(key, Example)
end

function Example.mousepressed(x, y, button)
    if button ~= 1 then return end
    local px  = W - PANEL_W
    local itemH = 32
    if x >= px then
        for i = 1, #shaderDefs do
            local iy = 38 + (i-1)*itemH
            if y >= iy and y < iy+itemH then
                selected = i
                return
            end
        end
    end
end

function Example.touchpressed(id, x, y)
    Example.mousepressed(x, y, 1)
end

return Example
