-- src/systems/postfx.lua
-- Canvas-based post-processing pipeline.
-- Wraps LÖVE canvas management — this one DOES use LÖVE calls.
--
-- Usage:
--   local PostFX = require("src.systems.postfx")
--   local fx = PostFX.new()
--
--   PostFX.addEffect(fx, "vignette", { strength=0.6 })
--   PostFX.addEffect(fx, "blur",     { passes=2 })
--   PostFX.addEffect(fx, "crt",      { scanlines=0.4, warp=0.015 })
--
--   -- In love.draw():
--   PostFX.beginCapture(fx)
--       -- draw your scene here
--   PostFX.endCapture(fx)
--   PostFX.render(fx)    -- draws final result to screen
--
--   -- Toggle effects at runtime:
--   PostFX.setEnabled(fx, "blur", false)
--   PostFX.setParam(fx, "vignette", "strength", 0.9)

local PostFX = {}

-- -------------------------
-- Built-in effect shaders
-- -------------------------
local SHADERS = {}

SHADERS.vignette = [[
    extern float strength;
    extern vec2 resolution;
    vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
        vec4 c = Texel(tex, tc);
        vec2 uv = tc - 0.5;
        float v = 1.0 - smoothstep(0.3, 0.8, length(uv) * (1.0 + strength));
        return vec4(c.rgb * v, c.a);
    }
]]

SHADERS.blur = [[
    extern vec2 resolution;
    vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
        vec2 px = 1.0 / resolution;
        vec4 c = vec4(0.0);
        c += Texel(tex, tc + vec2(-px.x,-px.y)) * 0.077;
        c += Texel(tex, tc + vec2( 0.0, -px.y)) * 0.123;
        c += Texel(tex, tc + vec2( px.x,-px.y)) * 0.077;
        c += Texel(tex, tc + vec2(-px.x, 0.0))  * 0.123;
        c += Texel(tex, tc)                      * 0.200;
        c += Texel(tex, tc + vec2( px.x, 0.0))  * 0.123;
        c += Texel(tex, tc + vec2(-px.x, px.y)) * 0.077;
        c += Texel(tex, tc + vec2( 0.0,  px.y)) * 0.123;
        c += Texel(tex, tc + vec2( px.x, px.y)) * 0.077;
        return c;
    }
]]

SHADERS.crt = [[
    extern float scanlines;
    extern float warp;
    extern float time;
    vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
        // Barrel distortion
        vec2 uv = tc - 0.5;
        uv *= 1.0 + warp * dot(uv, uv);
        uv += 0.5;
        if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0)
            return vec4(0.0, 0.0, 0.0, 1.0);
        vec4 c = Texel(tex, uv);
        // Scanlines
        float s = sin(uv.y * 800.0) * scanlines;
        c.rgb *= 1.0 - s;
        // Slight RGB shift
        c.r = Texel(tex, uv + vec2(0.001, 0.0)).r;
        c.b = Texel(tex, uv - vec2(0.001, 0.0)).b;
        return c;
    }
]]

SHADERS.pixelate = [[
    extern float pixelSize;
    extern vec2 resolution;
    vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
        vec2 px = pixelSize / resolution;
        vec2 snapped = floor(tc / px) * px + px * 0.5;
        return Texel(tex, snapped);
    }
]]

SHADERS.chromatic = [[
    extern float strength;
    vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
        vec2 offset = (tc - 0.5) * strength * 0.015;
        float r = Texel(tex, tc + offset).r;
        float g = Texel(tex, tc).g;
        float b = Texel(tex, tc - offset).b;
        return vec4(r, g, b, 1.0);
    }
]]

SHADERS.grayscale = [[
    extern float amount;
    vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
        vec4 c = Texel(tex, tc);
        float grey = dot(c.rgb, vec3(0.299, 0.587, 0.114));
        return vec4(mix(c.rgb, vec3(grey), amount), c.a);
    }
]]

SHADERS.wave = [[
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
]]

SHADERS.tint = [[
    extern float tintR;
    extern float tintG;
    extern float tintB;
    vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
        vec4 c = Texel(tex, tc);
        return vec4(c.r*tintR, c.g*tintG, c.b*tintB, c.a);
    }
]]

-- -------------------------
-- Create PostFX pipeline
-- -------------------------
function PostFX.new()
    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()
    local fx = {
        W       = W,
        H       = H,
        canvas1 = love.graphics.newCanvas(W, H),
        canvas2 = love.graphics.newCanvas(W, H),
        effects = {},   -- ordered list
        _time   = 0,
    }
    fx.canvas1:setFilter("nearest","nearest")
    fx.canvas2:setFilter("nearest","nearest")
    return fx
end

-- -------------------------
-- Add an effect to the pipeline
-- name   : "vignette","blur","crt","pixelate","chromatic","grayscale"
--          or a custom love.graphics.newShader(code) shader
-- params : table of uniform values
-- -------------------------
function PostFX.addEffect(fx, name, params)
    params = params or {}
    local shader
    if type(name) == "string" then
        assert(SHADERS[name], "Unknown effect: "..name)
        shader = love.graphics.newShader(SHADERS[name])
    else
        shader = name  -- raw shader object
        name   = "custom_"..#fx.effects
    end
    local effect = {
        name    = name,
        shader  = shader,
        params  = params,
        enabled = true,
    }
    table.insert(fx.effects, effect)
    -- Push initial params
    PostFX._sendParams(fx, effect)
    return effect
end

-- -------------------------
-- Send params to shader
-- -------------------------
function PostFX._sendParams(fx, effect)
    local sh = effect.shader
    local ok, _ = pcall(function()
        sh:send("resolution", {fx.W, fx.H})
    end)
    for k, v in pairs(effect.params) do
        local sent, _ = pcall(function() sh:send(k, v) end)
    end
end

-- -------------------------
-- Toggle effect
-- -------------------------
function PostFX.setEnabled(fx, name, enabled)
    for _, e in ipairs(fx.effects) do
        if e.name == name then e.enabled = enabled end
    end
end

-- -------------------------
-- Set a shader param at runtime
-- -------------------------
function PostFX.setParam(fx, name, key, value)
    for _, e in ipairs(fx.effects) do
        if e.name == name then
            e.params[key] = value
            pcall(function() e.shader:send(key, value) end)
        end
    end
end

-- -------------------------
-- Begin capturing scene
-- -------------------------
function PostFX.beginCapture(fx)
    love.graphics.setCanvas(fx.canvas1)
    love.graphics.clear()
end

-- -------------------------
-- End capturing
-- -------------------------
function PostFX.endCapture(fx)
    love.graphics.setCanvas()
end

-- -------------------------
-- Apply all effects and draw to screen
-- -------------------------
function PostFX.render(fx)
    fx._time = fx._time + 0.016  -- approx dt; good enough for shaders
    local src = fx.canvas1
    local dst = fx.canvas2

    for _, effect in ipairs(fx.effects) do
        if effect.enabled then
            -- Send time and resolution if shader uses them
            pcall(function() effect.shader:send("time", fx._time) end)
            pcall(function() effect.shader:send("resolution", {fx.W, fx.H}) end)
            -- Render src → dst through shader
            love.graphics.setCanvas(dst)
            love.graphics.clear()
            love.graphics.setShader(effect.shader)
            love.graphics.draw(src, 0, 0)
            love.graphics.setShader()
            love.graphics.setCanvas()
            -- Swap
            src, dst = dst, src
        end
    end

    -- Draw final result
    love.graphics.draw(src, 0, 0)
end

-- -------------------------
-- Resize (call from love.resize)
-- -------------------------
function PostFX.resize(fx, w, h)
    fx.W       = w
    fx.H       = h
    fx.canvas1 = love.graphics.newCanvas(w, h)
    fx.canvas2 = love.graphics.newCanvas(w, h)
    fx.canvas1:setFilter("nearest","nearest")
    fx.canvas2:setFilter("nearest","nearest")
    -- Re-send resolution to all shaders
    for _, effect in ipairs(fx.effects) do
        PostFX._sendParams(fx, effect)
    end
end

-- -------------------------
-- Remove all effects
-- -------------------------
function PostFX.clear(fx)
    fx.effects = {}
end

return PostFX
