-- src/states/examples/dialog.lua
-- Demonstrates: conversation trees, typewriter, choices, state flags, branching

local Utils  = require("src.utils")
local Timer  = require("src.systems.timer")
local Dialog = require("src.systems.dialog")
local Example = {}

local W, H
local timer
local dlg        -- active dialog instance
local world      -- simple world state
local npcs       -- list of NPCs to talk to
local selected   -- currently highlighted NPC
local message    -- floating world message { text, life }

-- -------------------------
-- Dialog box layout
-- -------------------------
local BOX = {
    margin  = 40,
    h       = 180,
    pad     = 16,
    choiceH = 30,
}

local function boxY() return H - BOX.h - BOX.margin end

-- -------------------------
-- NPC scripts
-- -------------------------

-- GUARD: changes based on quest state
local guardScript = {
    start = {
        speaker = "Guard",
        text    = function(s)
            if s.questDone then
                return "The village is safe thanks to you. Safe travels!"
            elseif s.questAccepted then
                return "The wolf den is north of the old mill. Be careful."
            else
                return "Halt, traveler. The road ahead is dangerous."
            end
        end,
        choices = {
            { text = "What's the danger?",
              condition = function(s) return not s.questAccepted and not s.questDone end,
              goto = "danger" },
            { text = "I'm ready for the quest.",
              condition = function(s) return not s.questAccepted and not s.questDone end,
              goto = "accept" },
            { text = "Any news?",
              condition = function(s) return s.questAccepted and not s.questDone end,
              goto = "hint" },
            { text = "Farewell.",
              goto = "bye" },
        }
    },
    danger = {
        speaker = "Guard",
        text    = "A pack of wolves has been attacking travelers. We need someone brave to deal with them.",
        choices = {
            { text = "I'll do it.",   goto = "accept" },
            { text = "Sounds risky.", goto = "risky"  },
        }
    },
    risky = {
        speaker = "Guard",
        text    = "Aye, it is. But the reward is worth it - 50 gold coins.",
        choices = {
            { text = "Fine, I'll help.", goto = "accept" },
            { text = "Not interested.",  goto = "bye"    },
        }
    },
    accept = {
        speaker = "Guard",
        text    = "Excellent! Find the wolf den north of the old mill and clear it out. Return when it's done.",
        onEnter = function(s) s.questAccepted = true end,
        choices = { { text = "I'm on my way.", goto = "bye" } }
    },
    hint = {
        speaker = "Guard",
        text    = "Follow the river north until you see the old mill. The den is just beyond it. Watch your back.",
        choices = { { text = "Thanks.", goto = "bye" } }
    },
    bye = {
        speaker = "Guard",
        text    = "Stay safe out there.",
        next    = "END",
    },
}

-- MERCHANT: shop-style dialog with state
local merchantScript = {
    start = {
        speaker = "Merchant",
        text    = function(s)
            if s.bought then
                return "Back so soon? I might have restocked... for the right price."
            else
                return "Welcome, welcome! Finest goods in the region. What can I do for you?"
            end
        end,
        choices = {
            { text = "What are you selling?",  goto = "wares"   },
            { text = "I'd like to sell items.", goto = "sell"    },
            { text = "Just browsing.",          goto = "browse"  },
            { text = "Goodbye.",                goto = "bye"     },
        }
    },
    wares = {
        speaker = "Merchant",
        text    = "Today I have health potions for 10 gold, and a fine shortsword for 85 gold. Interested?",
        choices = {
            { text = "I'll take a potion (10g).",
              condition = function(s) return (s.gold or 0) >= 10 end,
              goto = "buyPotion",
              onChoose = function(s) s.gold = s.gold - 10; s.potions = (s.potions or 0) + 1; s.bought = true end },
            { text = "I'll take the sword (85g).",
              condition = function(s) return (s.gold or 0) >= 85 end,
              goto = "buySword",
              onChoose = function(s) s.gold = s.gold - 85; s.hasSword = true; s.bought = true end },
            { text = "Too rich for my blood.", goto = "start" },
        }
    },
    buyPotion = {
        speaker = "Merchant",
        text    = function(s) return string.format("Wise choice! You now have %d potion(s). Anything else?", s.potions or 0) end,
        choices = {
            { text = "Another potion.",
              condition = function(s) return (s.gold or 0) >= 10 end,
              goto = "buyPotion",
              onChoose = function(s) s.gold = s.gold - 10; s.potions = (s.potions or 0) + 1 end },
            { text = "That'll do.", goto = "bye" },
        }
    },
    buySword = {
        speaker = "Merchant",
        text    = "A fine weapon! Treat her well. Now, anything else?",
        choices = {
            { text = "A potion too.",
              condition = function(s) return (s.gold or 0) >= 10 end,
              goto = "buyPotion",
              onChoose = function(s) s.gold = s.gold - 10; s.potions = (s.potions or 0) + 1 end },
            { text = "That's all.", goto = "bye" },
        }
    },
    sell = {
        speaker = "Merchant",
        text    = "Ha! I don't buy junk off travelers. Come back when you have something worth selling.",
        choices = { { text = "Charming.", goto = "start" } }
    },
    browse = {
        speaker = "Merchant",
        text    = "Take your time. But don't touch anything.",
        next    = "END",
    },
    bye = {
        speaker = "Merchant",
        text    = function(s)
            return string.format("Come back anytime! (Your gold: %dg)", s.gold or 0)
        end,
        next    = "END",
    },
}

-- SAGE: lore dump with back navigation
local sageScript = {
    start = {
        speaker = "Ancient Sage",
        text    = "Ah, a seeker of knowledge. Ask, and I shall illuminate the darkness of your ignorance.",
        choices = {
            { text = "Tell me about this land.",  goto = "land"   },
            { text = "What is magic?",            goto = "magic"  },
            { text = "Who are you?",              goto = "self"   },
            { text = "Never mind.",               goto = "END"    },
        }
    },
    land = {
        speaker = "Ancient Sage",
        text    = "This realm was shaped by the First Fire, ten thousand years past. Three kingdoms rose and fell before your kind learned to write.",
        choices = {
            { text = "Tell me more.",     goto = "land2"  },
            { text = "Ask something else.", goto = "start" },
        }
    },
    land2 = {
        speaker = "Ancient Sage",
        text    = "The old wars left scars still visible today - the Blighted Wastes to the east, the Sunken City beneath the lake.",
        choices = { { text = "Fascinating. Back.", goto = "start" } }
    },
    magic = {
        speaker = "Ancient Sage",
        text    = "Magic is merely the universe remembering what it once was. Those sensitive to it can remind it more forcefully.",
        choices = {
            { text = "Can I learn it?",      goto = "learnMagic" },
            { text = "Ask something else.",  goto = "start"      },
        }
    },
    learnMagic = {
        speaker = "Ancient Sage",
        text    = function(s)
            if s.askedMagic then
                return "I already told you - patience and suffering. Were you not listening?"
            else
                s.askedMagic = true
                return "You already possess the spark. What you lack is patience. And suffering. Mostly suffering."
            end
        end,
        choices = { { text = "...thanks.", goto = "start" } }
    },
    self = {
        speaker = "Ancient Sage",
        text    = "I am the memory of a civilization that forgot itself. I am the answer to questions nobody thought to ask. I am... very old.",
        choices = { { text = "Right. Back.", goto = "start" } }
    },
}

-- -------------------------
-- NPC definitions
-- -------------------------
local function makeNPCs()
    return {
        {
            label   = "GUARD",
            x       = W * 0.25,
            y       = H * 0.45,
            color   = {0.5, 0.65, 0.9},
            script  = guardScript,
            start   = "start",
        },
        {
            label   = "MERCHANT",
            x       = W * 0.5,
            y       = H * 0.42,
            color   = {0.9, 0.75, 0.3},
            script  = merchantScript,
            start   = "start",
        },
        {
            label   = "SAGE",
            x       = W * 0.75,
            y       = H * 0.44,
            color   = {0.7, 0.4, 0.9},
            script  = sageScript,
            start   = "start",
        },
    }
end

-- -------------------------
-- Open dialog with an NPC
-- -------------------------
local function openDialog(npc)
    -- Shared world state passed into every dialog
    dlg = Dialog.new(npc.script, npc.start, 38, world)
    dlg.onClose = function()
        dlg = nil
        message = { text="[SPACE / click to talk]", life=2.0 }
    end
    Dialog.open(dlg)
end

-- -------------------------
-- State
-- -------------------------
function Example.enter()
    W = love.graphics.getWidth()
    H = love.graphics.getHeight()
    timer   = Timer.new()
    world   = { gold=120, potions=0, questAccepted=false, questDone=false }
    npcs    = makeNPCs()
    dlg     = nil
    selected= nil
    message = { text="Walk up to an NPC and press SPACE or click", life=999 }
end

function Example.exit()
    Timer.clear(timer)
    dlg = nil
end

function Example.update(dt)
    Timer.update(timer, dt)

    if message then
        message.life = message.life - dt
        if message.life <= 0 then message = nil end
    end

    -- Find nearest NPC to center of screen (simulate player)
    local px, py = W/2, H/2 + 60
    selected = nil
    local bestDist = 120  -- activation radius
    for _, npc in ipairs(npcs) do
        local dx = npc.x - px
        local dy = npc.y - py
        local d  = math.sqrt(dx*dx + dy*dy)
        if d < bestDist then
            bestDist = d
            selected = npc
        end
    end

    if dlg then Dialog.update(dlg, dt) end
end

-- -------------------------
-- Draw dialog box
-- -------------------------
local function drawDialogBox()
    if not dlg or not dlg.active then return end

    local bx = BOX.margin
    local by = boxY()
    local bw = W - BOX.margin * 2
    local bh = BOX.h

    -- Box bg
    love.graphics.setColor(0.07, 0.09, 0.15, 0.97)
    love.graphics.rectangle("fill", bx, by, bw, bh, 8, 8)
    love.graphics.setColor(0.3, 0.45, 0.7)
    love.graphics.rectangle("line", bx, by, bw, bh, 8, 8)

    -- Speaker name
    local npcColor = {0.5, 0.8, 1.0}
    for _, npc in ipairs(npcs) do
        if npc.script == dlg.script then npcColor = npc.color end
    end
    love.graphics.setColor(npcColor)
    love.graphics.print(dlg.speaker or "", bx + BOX.pad, by + BOX.pad)

    -- Dialog text
    love.graphics.setColor(0.92, 0.92, 0.95)
    love.graphics.printf(dlg.displayText or "",
        bx + BOX.pad, by + BOX.pad + 22,
        bw - BOX.pad * 2, "left")

    -- Choices (only when revealed)
    if dlg.revealed and #dlg.choices > 0 then
        local choiceY = by + bh - #dlg.choices * BOX.choiceH - BOX.pad
        for i, choice in ipairs(dlg.choices) do
            local cy     = choiceY + (i-1) * BOX.choiceH
            local hover  = Input.mouseY >= cy and Input.mouseY <= cy + BOX.choiceH
                        and Input.mouseX >= bx and Input.mouseX <= bx + bw

            if hover then
                love.graphics.setColor(0.2, 0.3, 0.5, 0.6)
                love.graphics.rectangle("fill", bx+4, cy, bw-8, BOX.choiceH-2, 4,4)
            end

            love.graphics.setColor(hover and 1 or 0.75,
                                   hover and 1 or 0.85,
                                   hover and 1 or 0.6)
            love.graphics.print(
                string.format("[%d] %s", i, choice.text),
                bx + BOX.pad, cy + 6)
        end

    elseif dlg.revealed and #dlg.choices == 0 then
        -- Continue prompt
        local pulse = 0.6 + math.sin(love.timer.getTime() * 4) * 0.4
        love.graphics.setColor(0.5, 0.7, 1.0, pulse)
        love.graphics.printf("[ SPACE / click to continue ]",
            bx, by + bh - 24, bw - BOX.pad, "right")
    else
        -- Typing indicator
        local dots = string.rep(".", math.floor(love.timer.getTime()*4) % 4)
        love.graphics.setColor(0.4, 0.5, 0.6)
        love.graphics.printf(dots, bx, by + bh - 24, bw - BOX.pad, "right")
    end
end

function Example.draw()
    -- Sky gradient (simple)
    love.graphics.setColor(0.12, 0.16, 0.28)
    love.graphics.rectangle("fill", 0, 0, W, H)
    love.graphics.setColor(0.08, 0.10, 0.16)
    love.graphics.rectangle("fill", 0, H*0.55, W, H*0.45)

    -- Ground
    love.graphics.setColor(0.15, 0.22, 0.15)
    love.graphics.rectangle("fill", 0, H*0.55, W, H*0.45)

    -- Some scenery
    love.graphics.setColor(0.10, 0.15, 0.10)
    for i, x in ipairs({80, 200, 550, 700}) do
        love.graphics.rectangle("fill", x, H*0.35, 18, H*0.25)
        love.graphics.polygon("fill", x-20, H*0.35, x+9, H*0.18, x+38, H*0.35)
    end

    -- Player marker
    local px, py = W/2, H/2 + 60
    love.graphics.setColor(0.3, 0.9, 0.5)
    love.graphics.circle("fill", px, py, 14)
    love.graphics.setColor(0.5, 1.0, 0.7)
    love.graphics.circle("line", px, py, 14)
    love.graphics.setColor(0.1, 0.4, 0.2)
    love.graphics.printf("YOU", px-20, py-8, 40, "center")

    -- NPCs
    for _, npc in ipairs(npcs) do
        local isSel = (npc == selected and not dlg)
        local pulse = isSel and (0.7 + math.sin(love.timer.getTime()*3)*0.3) or 1

        -- Interaction ring
        if isSel then
            love.graphics.setColor(npc.color[1], npc.color[2], npc.color[3], 0.2)
            love.graphics.circle("fill", npc.x, npc.y, 120)
            love.graphics.setColor(npc.color[1], npc.color[2], npc.color[3], 0.5)
            love.graphics.circle("line", npc.x, npc.y, 120)
        end

        -- Body
        love.graphics.setColor(npc.color[1]*pulse, npc.color[2]*pulse, npc.color[3]*pulse)
        love.graphics.circle("fill", npc.x, npc.y, 18)
        love.graphics.setColor(1,1,1, 0.7)
        love.graphics.circle("line", npc.x, npc.y, 18)

        -- Label
        love.graphics.setColor(npc.color)
        love.graphics.printf(npc.label, npc.x-50, npc.y-38, 100, "center")

        -- Talk prompt
        if isSel then
            love.graphics.setColor(1, 1, 0.6)
            love.graphics.printf("[SPACE]", npc.x-40, npc.y+22, 80, "center")
        end
    end

    -- World state HUD
    love.graphics.setColor(0.10, 0.12, 0.20, 0.9)
    love.graphics.rectangle("fill", W-180, 30, 170, 80, 6,6)
    love.graphics.setColor(0.4, 0.55, 0.8)
    love.graphics.printf("WORLD STATE", W-180, 36, 170, "center")
    love.graphics.setColor(0.8, 0.8, 0.85)
    love.graphics.print(string.format(
        "Gold:    %dg\nPotions: %d\nQuest:   %s",
        world.gold or 0,
        world.potions or 0,
        world.questDone and "done!" or world.questAccepted and "active" or "none"),
        W-168, 54)

    -- Message
    if message and message.life > 0 then
        local a = math.min(1, message.life)
        love.graphics.setColor(0.7, 0.8, 1.0, a)
        love.graphics.printf(message.text, 0, H*0.55 - 28, W, "center")
    end

    drawDialogBox()

    Utils.drawHUD("DIALOG SYSTEM",
        "SPACE/click advance    1-4 choose    ESC close dialog    P pause")
end

-- -------------------------
-- Input
-- -------------------------
local function advance()
    if dlg and dlg.active then
        Dialog.advance(dlg)
    elseif selected then
        openDialog(selected)
    end
end

local function tryChoose(idx)
    if dlg and dlg.active and dlg.revealed then
        Dialog.choose(dlg, idx)
    end
end

function Example.keypressed(key)
    if key == "space" or key == "return" then
        advance()
        return
    end
    if key == "escape" then
        if dlg and dlg.active then
            Dialog.close(dlg)
            return
        end
    end
    local n = tonumber(key)
    if n then tryChoose(n) end
    Utils.handlePause(key, Example)
end

function Example.mousepressed(x, y, button)
    if button ~= 1 then return end
    if not dlg or not dlg.active then
        -- Click on NPC
        for _, npc in ipairs(npcs) do
            local dx = x - npc.x
            local dy = y - npc.y
            if math.sqrt(dx*dx+dy*dy) < 28 then
                openDialog(npc)
                return
            end
        end
        return
    end

    -- Click on choice
    if dlg.revealed and #dlg.choices > 0 then
        local bx     = BOX.margin
        local bw     = W - BOX.margin * 2
        local by     = boxY()
        local bh     = BOX.h
        local choiceY = by + bh - #dlg.choices * BOX.choiceH - BOX.pad
        for i = 1, #dlg.choices do
            local cy = choiceY + (i-1) * BOX.choiceH
            if x >= bx and x <= bx+bw and y >= cy and y <= cy+BOX.choiceH then
                tryChoose(i)
                return
            end
        end
    end

    advance()
end

function Example.touchpressed(id, x, y)
    Example.mousepressed(x, y, 1)
end

return Example
