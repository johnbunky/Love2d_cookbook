-- src/states/menu.lua
-- Main menu with keyboard, mouse and touch support

local Menu = {}

local entries = {
    { header = "-- CORE --" },
    { label = "Top-down Movement",    state = "topdown_movement"    },
    { label = "Platformer Movement",  state = "platformer_movement" },
    { label = "Camera",               state = "camera"              },
    { label = "Tilemap",              state = "tilemap"             },
    { label = "Collision Detection",  state = "collision_demo"      },
    { label = "Platformer Level",     state = "platformer_level"    },
    { header = "-- POLISH --" },
    { label = "Spritesheet Animation",state = "animation"           },
    { label = "Screen Shake",         state = "screen_shake"        },
    { label = "Transitions",          state = "transitions"         },
    { label = "HUD",                  state = "hud"                 },
    { header = "-- COMBAT --" },
    { label = "Shooter / Bullets",    state = "shooter"             },
    { label = "Melee Attack",         state = "melee_attack"        },
    { label = "Enemy AI",             state = "enemy_ai"            },
    { label = "Pathfinding",          state = "pathfinding"         },
    { label = "Health & Damage",      state = "health_damage"       },
    { label = "Particles",            state = "particles"           },
    { header = "-- UI --" },
    { label = "Nav Menu",             state = "nav_menu"            },
    { label = "Inventory",            state = "inventory"           },
    { label = "Dialog Box",           state = "dialog"              },
    { header = "-- VISUAL --" },
    { label = "Parallax",             state = "parallax"            },
    { label = "Day / Night",          state = "day_night"           },
    { label = "Lighting",             state = "lighting"            },
    { label = "Shaders",              state = "shaders"             },
    { label = "Post FX",              state = "post_fx"             },
    { label = "3D Basics",            state = "basics_3d"           },
    { label = "Billboards",           state = "billboards"          },
    { label = "Iso / Top-Down",       state = "iso_topdown"         },
    { header = "-- AUDIO --" },
    { label = "Audio Demo",           state = "audio_demo"          },
    { label = "Volume Control",       state = "volume_control"      },
    { header = "-- INPUT --" },
    { label = "Keyboard & Mouse",     state = "keyboard_mouse_demo" },
    { label = "Gamepad",              state = "gamepad_demo"        },
    { label = "Virtual Joystick",     state = "virtual_joystick"    },
    { header = "-- DATA --" },
    { label = "Save / Load",          state = "save_load"           },
    { label = "High Score",           state = "high_score"          },
    { label = "Settings Persistence", state = "settings_persist"    },
}

-- Build selectable index list
local selectable = {}
for i, e in ipairs(entries) do
    if e.state then table.insert(selectable, i) end
end

local selectedIdx = 1
local scrollY     = 0
local W, H
local lineH       = 40    -- taller rows = easier to tap on mobile
local startY      = 0     -- computed in enter()
local VISIBLE_H   = 0     -- computed in enter()
local itemW       = 0     -- computed in enter()

-- Touch state — three separate concerns:
-- 1. scroll: finger drag moves the list
-- 2. hover:  finger position highlights item under finger
-- 3. select: clean tap (no drag) launches item
local touch = {
    id       = nil,    -- active finger id
    startX   = 0,
    startY   = 0,
    scrollY0 = 0,
    dragging = false,  -- true once finger moved > threshold
    hoverIdx = nil,    -- item currently under finger
}

local function updateLayout()
    W        = love.graphics.getWidth()
    H        = love.graphics.getHeight()
    startY   = math.floor(H * 0.18)
    VISIBLE_H= H - startY - 10
    itemW    = math.min(500, math.floor(W * 0.85))
end

function Menu.enter()
    updateLayout()
    selectedIdx = 1
    scrollY     = 0
    Log.info("menu W="..W.." H="..H.." startY="..startY.." VH="..VISIBLE_H)
end

function Menu.exit() end

local padScrollAcc = 0

function Menu.update(dt)
    updateLayout()
    -- Mouse wheel scroll
    if Input.mouseWheelY ~= 0 then
        scrollY = scrollY - Input.mouseWheelY * lineH * 2
        local maxScroll = math.max(0, #entries * lineH - VISIBLE_H)
        scrollY = math.max(0, math.min(scrollY, maxScroll))
    end

    -- Gamepad left stick scroll
    for _, js in ipairs(love.joystick.getJoysticks()) do
        if js:isGamepad() then
            local axis = js:getGamepadAxis("lefty")
            if math.abs(axis) > 0.2 then
                padScrollAcc = padScrollAcc + axis * 300 * dt
                if math.abs(padScrollAcc) >= lineH then
                    local steps = math.floor(math.abs(padScrollAcc) / lineH)
                    local dir   = padScrollAcc > 0 and 1 or -1
                    for _ = 1, steps do
                        selectedIdx = ((selectedIdx - 1 + dir + #selectable) % #selectable) + 1
                    end
                    scrollToSelected()
                    padScrollAcc = padScrollAcc - steps * lineH * dir
                end
            else
                padScrollAcc = 0
            end
        end
    end

    -- Hover: mouse only, skip on mobile
    if not IS_MOBILE and Input.mouseX > 0 then
        local mx, my = Input.mouseX, Input.mouseY
        for si, ei in ipairs(selectable) do
            local ey = startY + (ei-1) * lineH - scrollY
            local ex = (W - itemW) / 2
            if my >= ey and my < ey + lineH
            and mx >= ex and mx < ex + itemW
            and ey >= startY and ey < startY + VISIBLE_H then
                selectedIdx = si
                break
            end
        end
    end
end

function Menu.draw()
    updateLayout()
    -- Title
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("== L?2D COOKBOOK ==", 0, startY * 0.15, W, "center")
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.printf(
        "^v / stick scroll     ENTER / tap launch     ESC quit",
        0, startY * 0.42, W, "center")
    love.graphics.setColor(0.3, 0.3, 0.35)
    love.graphics.printf("[ " .. selectedIdx .. " / " .. #selectable .. " ]",
        0, startY * 0.68, W, "center")

    -- Clipping
    -- Scissor must be in real screen pixels, not virtual
    local sc = Scale.factor()
    local sox, soy = Scale.offset()
    love.graphics.setScissor(sox, soy + startY * sc, W * sc, VISIBLE_H * sc)

    for i, entry in ipairs(entries) do
        local y  = startY + (i-1) * lineH - scrollY
        local ex = (W - itemW) / 2

        if entry.header then
            love.graphics.setColor(0.35, 0.5, 0.85)
            love.graphics.printf(entry.header, 0, y + 6, W, "center")
        else
            -- touch.hoverIdx highlights finger position; selectedIdx for keyboard/gamepad
            local si = 0
            for s, ei in ipairs(selectable) do if ei == i then si = s break end end
            local isSelected = (si == selectedIdx)
            local isTouchHover = (touch.hoverIdx ~= nil and si == touch.hoverIdx)
            local isMouseHover = (not IS_MOBILE)
                                 and (touch.id == nil)
                                 and Input.isHover(ex, y, itemW, lineH)
                                 and y >= startY and y < startY + VISIBLE_H

            if isTouchHover then
                -- finger is currently over this item
                love.graphics.setColor(0.15, 0.35, 0.2)
                love.graphics.rectangle("fill", ex, y+2, itemW, lineH-4, 4, 4)
                love.graphics.setColor(0.2, 0.85, 0.4)
                love.graphics.printf("> " .. entry.label .. " <", 0, y + 8, W, "center")
            elseif isSelected then
                love.graphics.setColor(0.15, 0.35, 0.2)
                love.graphics.rectangle("fill", ex, y+2, itemW, lineH-4, 4, 4)
                love.graphics.setColor(0.2, 0.85, 0.4)
                love.graphics.printf("> " .. entry.label .. " <", 0, y + 8, W, "center")
            elseif isMouseHover then
                love.graphics.setColor(0.15, 0.2, 0.25)
                love.graphics.rectangle("fill", ex, y+2, itemW, lineH-4, 4, 4)
                love.graphics.setColor(0.9, 0.9, 0.9)
                love.graphics.printf(entry.label, 0, y + 8, W, "center")
            else
                love.graphics.setColor(0.65, 0.65, 0.65)
                love.graphics.printf(entry.label, 0, y + 8, W, "center")
            end
        end
    end

    love.graphics.setScissor()

    -- Scroll bar
    local totalH   = #entries * lineH
    if totalH > VISIBLE_H then
        local barH   = math.max(30, VISIBLE_H * (VISIBLE_H / totalH))
        local barY   = startY + (scrollY / totalH) * VISIBLE_H
        love.graphics.setColor(0.3, 0.3, 0.4)
        love.graphics.rectangle("fill", W-8, startY, 4, VISIBLE_H, 2, 2)
        love.graphics.setColor(0.5, 0.5, 0.65)
        love.graphics.rectangle("fill", W-8, barY, 4, barH, 2, 2)
    end
end

local function scrollToSelected()
    local entryI = selectable[selectedIdx]
    local y = (entryI-1) * lineH
    if y < scrollY then
        scrollY = math.max(0, y - lineH)
    elseif y > scrollY + VISIBLE_H - lineH then
        scrollY = y - VISIBLE_H + lineH * 2
    end
end

local function launch()
    local entry  = entries[selectable[selectedIdx]]
    local target = States[entry.state]
    if target then
        Transition.to(target, "fade", 0.3)
    else
        print("State not found: " .. entry.state)
    end
end

function Menu.keypressed(key)
    if key == "up" then
        selectedIdx = (selectedIdx - 2) % #selectable + 1
        scrollToSelected()
    elseif key == "down" then
        selectedIdx = selectedIdx % #selectable + 1
        scrollToSelected()
    elseif key == "return" then
        launch()
    end
end

function Menu.mousepressed(x, y, button)
    if IS_MOBILE then return end
    if button == 1 then launch() end
end

-- Find which selectable index is at screen position y
local function itemAtY(y)
    local ex = (W - itemW) / 2
    for si, ei in ipairs(selectable) do
        local ey = startY + (ei-1) * lineH - scrollY
        if ey >= startY and ey < startY + VISIBLE_H
        and y >= ey and y < ey + lineH then
            return si
        end
    end
    return nil
end

-- STEP 1: finger down — record start position only
function Menu.touchpressed(id, x, y)
    if touch.id then return end   -- ignore second finger
    touch.id       = id
    touch.startX   = x
    touch.startY   = y
    touch.scrollY0 = scrollY
    touch.dragging = false
    touch.hoverIdx = itemAtY(y)
end

-- STEP 2: finger moves — scroll the list, update hover
function Menu.touchmoved(id, x, y)
    if id ~= touch.id then return end
    local dy = touch.startY - y
    -- Start dragging after 10px threshold
    if math.abs(dy) > 10 then touch.dragging = true end
    if touch.dragging then
        -- Scroll
        local maxScroll = math.max(0, #entries * lineH - VISIBLE_H)
        scrollY = math.max(0, math.min(touch.scrollY0 + dy, maxScroll))
        touch.hoverIdx = nil   -- no hover while scrolling
    else
        -- Not dragging yet — update hover to finger position
        touch.hoverIdx = itemAtY(y)
    end
end

-- STEP 3: finger up — launch only if no drag happened
function Menu.touchreleased(id, x, y)
    if id ~= touch.id then return end
    if not touch.dragging and touch.hoverIdx then
        selectedIdx = touch.hoverIdx
        launch()
    end
    touch.id       = nil
    touch.hoverIdx = nil
    touch.dragging = false
end

function Menu.gamepadpressed(joystick, button)
    if button == "dpup" or button == "leftshoulder" then
        selectedIdx = (selectedIdx - 2) % #selectable + 1
        scrollToSelected()
    elseif button == "dpdown" or button == "rightshoulder" then
        selectedIdx = selectedIdx % #selectable + 1
        scrollToSelected()
    elseif button == "dpleft" then
        -- page up
        selectedIdx = math.max(1, selectedIdx - 5)
        scrollToSelected()
    elseif button == "dpright" then
        -- page down
        selectedIdx = math.min(#selectable, selectedIdx + 5)
        scrollToSelected()
    elseif button == "a" or button == "start" then
        launch()
    end
end

return Menu
