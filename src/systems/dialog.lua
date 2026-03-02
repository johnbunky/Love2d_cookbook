-- src/systems/dialog.lua
-- Conversation tree system. Engine-agnostic — no LÖVE calls.
--
-- Concepts:
--   Script   : a complete conversation tree (table of nodes)
--   Node     : one beat of dialog { speaker, text, choices, onEnter, onExit }
--   Dialog   : a running instance of a script
--
-- Usage:
--   local Dialog = require("src.systems.dialog")
--
--   -- Define a script
--   local script = {
--       start = {
--           speaker = "Guard",
--           text    = "Halt! Who goes there?",
--           choices = {
--               { text="A friend.", goto="friendly" },
--               { text="None of your business.", goto="hostile" },
--               { text="...", goto="silent", condition=function(s) return s.mute end },
--           }
--       },
--       friendly = {
--           speaker = "Guard",
--           text    = "Very well. Pass.",
--           choices = { { text="Thanks.", goto="END" } },
--       },
--       hostile = {
--           speaker = "Guard",
--           text    = "Wrong answer!",
--           onEnter = function(state) state.guardHostile = true end,
--           choices = { { text="Wait—", goto="END" } },
--       },
--   }
--
--   local dlg = Dialog.new(script, "start")
--   Dialog.advance(dlg)          -- start / go to auto-next node
--   Dialog.choose(dlg, 1)        -- pick choice index
--   Dialog.update(dlg, dt)       -- drives typewriter effect
--
--   -- Read state each frame:
--   dlg.active          -- bool: is dialog running?
--   dlg.speaker         -- current speaker name
--   dlg.displayText     -- typewriter string so far
--   dlg.fullText        -- complete text of current line
--   dlg.revealed        -- bool: typewriter finished?
--   dlg.choices         -- filtered list of available choices
--   dlg.state           -- persistent data bag passed to conditions/callbacks

local Dialog = {}

-- -------------------------
-- Create a new dialog instance
-- script      : node table (see above)
-- startNode   : key of first node (default "start")
-- typeSpeed   : characters per second (default 40, 0 = instant)
-- sharedState : optional external state table (for flags, variables)
-- -------------------------
function Dialog.new(script, startNode, typeSpeed, sharedState)
    return {
        script      = script,
        startNode   = startNode or "start",
        typeSpeed   = typeSpeed or 40,
        state       = sharedState or {},

        active      = false,
        currentKey  = nil,
        currentNode = nil,

        -- Typewriter
        displayText = "",
        fullText    = "",
        charIndex   = 0,
        charTimer   = 0,
        revealed    = false,

        -- Filtered choices for current node
        choices     = {},

        -- History
        history     = {},

        -- Callbacks
        onOpen      = nil,  -- function(dlg)
        onClose     = nil,  -- function(dlg)
        onNode      = nil,  -- function(dlg, key, node)
        onChoice    = nil,  -- function(dlg, choiceIdx, choice)
        onReveal    = nil,  -- function(dlg)  fired when typewriter finishes
    }
end

-- -------------------------
-- Internal: enter a node by key
-- -------------------------
local function enterNode(dlg, key)
    if key == "END" or key == nil then
        Dialog.close(dlg)
        return
    end

    local node = dlg.script[key]
    assert(node, "Dialog: unknown node key '" .. tostring(key) .. "'")

    -- Exit previous node
    if dlg.currentNode and dlg.currentNode.onExit then
        dlg.currentNode.onExit(dlg.state, dlg)
    end

    -- Record history
    if dlg.currentKey then
        table.insert(dlg.history, dlg.currentKey)
    end

    dlg.currentKey  = key
    dlg.currentNode = node

    -- Resolve text (can be string or function)
    local text = type(node.text) == "function"
        and node.text(dlg.state, dlg)
        or  (node.text or "")

    dlg.fullText    = text
    dlg.displayText = ""
    dlg.charIndex   = 0
    dlg.charTimer   = 0
    dlg.revealed    = (dlg.typeSpeed == 0)

    if dlg.typeSpeed == 0 then
        dlg.displayText = text
    end

    -- Filter choices by condition
    dlg.choices = {}
    if node.choices then
        for _, choice in ipairs(node.choices) do
            local ok = true
            if choice.condition then
                ok = choice.condition(dlg.state, dlg)
            end
            if ok then
                table.insert(dlg.choices, choice)
            end
        end
    end

    -- onEnter callback
    if node.onEnter then node.onEnter(dlg.state, dlg) end

    -- Node callback
    if dlg.onNode then dlg.onNode(dlg, key, node) end

    -- Speaker
    dlg.speaker = type(node.speaker) == "function"
        and node.speaker(dlg.state, dlg)
        or  node.speaker or ""

    -- Auto-advance if no choices and has a next key
    -- (caller must call Dialog.advance to step forward)
end

-- -------------------------
-- Open / start the dialog
-- -------------------------
function Dialog.open(dlg, startNode)
    dlg.active   = true
    dlg.history  = {}
    dlg.state    = dlg.state or {}
    if dlg.onOpen then dlg.onOpen(dlg) end
    enterNode(dlg, startNode or dlg.startNode)
end

-- -------------------------
-- Close / end the dialog
-- -------------------------
function Dialog.close(dlg)
    if dlg.currentNode and dlg.currentNode.onExit then
        dlg.currentNode.onExit(dlg.state, dlg)
    end
    dlg.active      = false
    dlg.currentKey  = nil
    dlg.currentNode = nil
    dlg.choices     = {}
    dlg.displayText = ""
    dlg.fullText    = ""
    dlg.revealed    = false
    if dlg.onClose then dlg.onClose(dlg) end
end

-- -------------------------
-- Advance: reveal all text if typing, or go to next node
-- Call on confirm input (space/enter/click)
-- -------------------------
function Dialog.advance(dlg)
    if not dlg.active then
        Dialog.open(dlg)
        return
    end

    -- If still typing — reveal all
    if not dlg.revealed then
        dlg.displayText = dlg.fullText
        dlg.charIndex   = #dlg.fullText
        dlg.revealed    = true
        if dlg.onReveal then dlg.onReveal(dlg) end
        return
    end

    -- If no choices, auto-next
    local node = dlg.currentNode
    if node and #dlg.choices == 0 then
        if node.next then
            enterNode(dlg, node.next)
        else
            Dialog.close(dlg)
        end
    end
    -- If has choices — caller must call Dialog.choose(dlg, idx)
end

-- -------------------------
-- Choose option by index (1-based)
-- -------------------------
function Dialog.choose(dlg, idx)
    if not dlg.active or not dlg.revealed then return false end
    local choice = dlg.choices[idx]
    if not choice then return false end

    if dlg.onChoice then dlg.onChoice(dlg, idx, choice) end
    if choice.onChoose then choice.onChoose(dlg.state, dlg) end

    enterNode(dlg, choice.goto or choice.next or "END")
    return true
end

-- -------------------------
-- Update — drives typewriter effect
-- Call every frame while dialog is active
-- -------------------------
-- Safe UTF-8 substring — never cuts in the middle of a multibyte character
local function utf8sub(s, nchars)
    local byteIdx = 0
    local charCount = 0
    while charCount < nchars do
        byteIdx = byteIdx + 1
        if byteIdx > #s then return s end
        local b = s:byte(byteIdx)
        -- Start of a UTF-8 character: not a continuation byte (10xxxxxx)
        if b < 0x80 or b >= 0xC0 then
            charCount = charCount + 1
        end
    end
    return s:sub(1, byteIdx)
end

local function utf8len(s)
    local count = 0
    for i = 1, #s do
        local b = s:byte(i)
        if b < 0x80 or b >= 0xC0 then count = count + 1 end
    end
    return count
end

function Dialog.update(dlg, dt)
    if not dlg.active or dlg.revealed then return end
    if dlg.typeSpeed <= 0 then return end

    dlg.charTimer = dlg.charTimer + dt
    local charsToAdd = math.floor(dlg.charTimer * dlg.typeSpeed)

    if charsToAdd > 0 then
        dlg.charTimer = dlg.charTimer - charsToAdd / dlg.typeSpeed
        dlg.charIndex = dlg.charIndex + charsToAdd

        local totalChars = utf8len(dlg.fullText)
        if dlg.charIndex >= totalChars then
            dlg.charIndex   = totalChars
            dlg.displayText = dlg.fullText
            dlg.revealed    = true
            if dlg.onReveal then dlg.onReveal(dlg) end
        else
            dlg.displayText = utf8sub(dlg.fullText, dlg.charIndex)
        end
    end
end

-- -------------------------
-- Helpers
-- -------------------------

-- Go back one node in history
function Dialog.back(dlg)
    if #dlg.history == 0 then return false end
    local prev = table.remove(dlg.history)
    -- re-enter without adding to history again
    local node = dlg.script[prev]
    if not node then return false end
    dlg.currentKey  = prev
    dlg.currentNode = node
    dlg.fullText    = type(node.text)=="function" and node.text(dlg.state,dlg) or (node.text or "")
    dlg.displayText = dlg.fullText
    dlg.charIndex   = #dlg.fullText
    dlg.revealed    = true
    dlg.speaker     = node.speaker or ""
    dlg.choices     = {}
    if node.choices then
        for _, c in ipairs(node.choices) do
            if not c.condition or c.condition(dlg.state, dlg) then
                table.insert(dlg.choices, c)
            end
        end
    end
    return true
end

-- Skip typewriter entirely for current node
function Dialog.skipTyping(dlg)
    if not dlg.revealed then
        dlg.displayText = dlg.fullText
        dlg.charIndex   = #dlg.fullText
        dlg.revealed    = true
        if dlg.onReveal then dlg.onReveal(dlg) end
    end
end

-- Set a state variable (shorthand)
function Dialog.set(dlg, key, value)
    dlg.state[key] = value
end

function Dialog.get(dlg, key)
    return dlg.state[key]
end

-- Check if a node has been visited
function Dialog.visited(dlg, key)
    for _, k in ipairs(dlg.history) do
        if k == key then return true end
    end
    return false
end

-- -------------------------
-- Script builder helpers
-- Fluent API for building scripts in code
-- -------------------------
Dialog.Script = {}

function Dialog.Script.new()
    return { _nodes={} }
end

function Dialog.Script.node(s, key, speaker, text, choices, opts)
    s._nodes[key] = {
        speaker = speaker,
        text    = text,
        choices = choices or {},
        next    = opts and opts.next,
        onEnter = opts and opts.onEnter,
        onExit  = opts and opts.onExit,
    }
    return s
end

function Dialog.Script.build(s)
    return s._nodes
end

return Dialog
