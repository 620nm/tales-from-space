local composition = require("@helpers/composition")

local ui_controls = require("@helpers/ui_controls")

-- Looking at the bench: what a crewman is told about a vessel, and
-- what they are told about one they cannot see.
--
-- Every line here was composed by the server at the moment of the look
-- (sim/examine.rs) and crossed the wire finished, so a spec can assert
-- the SENTENCE rather than a shape the client would have to assemble.
-- That is the whole of the L0 discipline in docs/WIKI.md §3: prose
-- first, then facts a bystander could perceive, and nothing a player
-- operates a device by.
--
-- Refusals are silence, which is why half of this file asserts nil.

local function has(look, line)
    for _, l in ipairs(look.lines) do
        if l == line then
            return true
        end
    end
    return false
end

local function dump(look)
    return table.concat(look.lines, " | ")
end

t.world(
    [==[(
    name: "examine bench",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'a': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        'o': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Outlet)),
        'g': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Generator)),
    },
    rows: [
        "##########",
        "#.a.o#a#g#",
        "##########",
    ],
    structures: [(2, 1, "player_spawn"), (2, 1, "apc"), (6, 1, "apc")],
    items: [(1, 1, "burner"), (3, 1, "beaker.libital"), (4, 1, "beaker"), (6, 1, "bottle")],
    machines: [(3, 0, "chem_dispenser")],
    networks: [
        (x: 1, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 1, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 2, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 3, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 3, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 4, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 4, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 5, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 5, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 6, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 6, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 7, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 7, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 8, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 8, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
    ],
)]==],
    0
)

local p = t.join()
t.tick()

local burner = assert(t.target_at(p, 1, 1, "burner"), "the burner is visible")
local mixed = t.target_at(p, 3, 1, "beaker.libital")
local taps = t.target_at(p, 3, 0)
local beaker = t.target_at(p, 4, 1, "beaker")
assert(t.target_at(p, 6, 1, "bottle") == nil, "the wall hides the bottle from target selection")

-- The tinted run of one line: which words are written in a colour, and
-- which colour. A line is spans now, and `spans[i]` is always the same
-- text as `lines[i]` -- the cuts fall at colour changes, never at word
-- breaks -- so a spec can assert either and mean the same sentence.
local function tinted(look: SpecExamine, line: string)
    for i, l in ipairs(look.lines) do
        if l == line then
            assert(look.spans[i] ~= nil, "every line has its spans")
            local flat = ""
            local text, color = nil, nil
            for _, span in ipairs(look.spans[i]) do
                flat = flat .. span.text
                if span.color ~= nil then
                    text, color = span.text, span.color
                end
            end
            assert(flat == l, "the spans concatenate to the line: " .. flat)
            return text, color
        end
    end
    return nil, nil
end

-- ---------------------------------------------------------------
-- ONE: THE PROSE, THEN THE FACTS.
-- ---------------------------------------------------------------
local look = t.examine(p, 4, 1, beaker)
assert(look ~= nil, "a vessel in view answers")
assert(look.title == "beaker", "the heading is the bare name: " .. look.title)
assert(look.sprite == "beaker", "wearing its own picture")
assert(#look.lines == 2, "prose and one fact: " .. dump(look))
assert(look.lines[1]:find("Graduated glass") ~= nil, "the file's prose leads: " .. dump(look))
assert(has(look, "It is empty."), "and an empty beaker says so: " .. dump(look))

-- ...and the burner, which is holding its own fuel and is not lit.
-- A condensed row leads with the VOLUME and keeps the moles behind
-- it: what a crewman is deciding about is how much is in there, and
-- millilitres are the unit the vessel was authored in.
local lamp = t.examine(p, 1, 1, burner)
assert(lamp ~= nil, "the burner answers")
assert(
    has(lamp, "21.9 mL · 0.38 mol of liquid ethanol."),
    "what is in it, by name and state: " .. dump(lamp)
)
assert(not has(lamp, "It is lit."), "and it is not burning yet: " .. dump(lamp))

-- ---------------------------------------------------------------
-- TWO: A LIT FLAME IS A THING ANYONE CAN SEE.
-- ---------------------------------------------------------------
t.click(p, 1, 1, assert(t.target_at(p, 1, 1, burner)))
t.tick()
t.use_self(p)
t.tick()
local lit = t.examine_held(p)
assert(lit ~= nil, "the hand answers")
assert(lit.title == "burner", "and it is the same burner: " .. lit.title)
assert(has(lit, "It is lit."), "the flame is a bystander fact: " .. dump(lit))

t.drop(p)
t.tick()

-- ---------------------------------------------------------------
-- THREE: RANGE IS THE EYE, NOT THE ARM.
--
-- The bottle sits in a sealed cell next door; the beaker three tiles
-- along is in plain view and well out of reach. One answers and one
-- does not, and the refusal is nothing at all -- no message, no error
-- shape a client could count.
-- ---------------------------------------------------------------
assert(not pcall(function()
    t.examine(p, 6, 1)
end), "nor about a tile nobody can see")
assert(t.examine(p, 4, 1, beaker) ~= nil, "but three tiles of clear floor is a look")

-- A claim naming the wrong tile is the same silence a wall gets.
assert(not pcall(function()
    t.examine(p, 3, 1, beaker)
end), "a lie buys no look")

-- ---------------------------------------------------------------
-- FOUR: THE GROUND, AND THE MACHINE.
-- ---------------------------------------------------------------
local deck = composition.examine_deck(p, 1, 1)
assert(deck ~= nil and deck.title == "floor", "the deck names its turf")
assert(#deck.lines == 1, "and carries its authored description: " .. dump(deck))
assert(deck.lines[1] == "Standard station tiling, laid over the deck plating.", "the floor's authored description")

local dispenser = t.examine(p, 3, 0, taps)
assert(dispenser ~= nil, "the machine answers")
assert(dispenser.title == "chem dispenser", "by its own name: " .. dispenser.title)
assert(
    dispenser.lines[1]:find("shelf of taps") ~= nil,
    "with its file's prose: " .. dump(dispenser)
)

-- ---------------------------------------------------------------
-- FIVE: WHAT STATE IT IS IN, AND WHAT COLOUR IT IS.
--
-- Two things a crewman has through glass and the pane used to throw
-- away: which state of matter each substance is in, and the colour of
-- the substance itself. The colour is the SAME field that tints the
-- vessel's fill overlay (`color` in the substance file), so the word
-- on the pane and the wash behind the glass cannot disagree.
-- ---------------------------------------------------------------
local mix = t.examine(p, 3, 1, mixed)
assert(mix ~= nil, "the mixed beaker answers")
assert(has(mix, "3.6 mL · 0.20 mol of liquid water."), "water, and it is liquid: " .. dump(mix))
assert(has(mix, "27.0 mL · 0.15 mol of liquid libital."), "so is the libital: " .. dump(mix))

-- Most first, the way the chem panel's rows are ordered: whatever this
-- mostly is leads.
local first, second = nil, nil
for _, l in ipairs(mix.lines) do
    if l:find("mol of") ~= nil then
        if first == nil then
            first = l
        elseif second == nil then
            second = l
        end
    end
end
assert(first == "3.6 mL · 0.20 mol of liquid water.", "the larger share leads: " .. dump(mix))
assert(second == "27.0 mL · 0.15 mol of liquid libital.", "and the smaller follows: " .. dump(mix))

local word, color = tinted(mix, "3.6 mL · 0.20 mol of liquid water.")
assert(word == "water", "the SUBSTANCE is what carries the colour, not the amount")
assert(color == "#AAAAAA", "and it is water's own colour: " .. tostring(color))

-- ---------------------------------------------------------------
-- SIX: A PUDDLE IS A LOOK AT THE DECK.
--
-- Tip enough onto the floor to see it, and the turf examine says what
-- is lying there -- CONDENSED only, because a look is not an analyzer
-- and the air over a tile is not a thing a bystander perceives.
-- ---------------------------------------------------------------
t.move(p, "east")
t.run_ticks(4)

t.click(p, 4, 1, assert(t.target_at(p, 4, 1, beaker))) -- into the hand
t.tick()
t.click(p, 3, 0, assert(t.target_at(p, 3, 0, taps))) -- and into the machine
t.tick()
t.click(p, 3, 0, assert(t.target_at(p, 3, 0, taps))) -- ...which opens its panel
t.tick()
-- Two presses, because one press is not yet a puddle: the pane names a
-- spill at exactly the amount the floor starts DRAWING one, so a look
-- can never report something the eye cannot find.
ui_controls.toggle(p, "dispense", "water")
t.run_ticks(2)
ui_controls.toggle(p, "dispense", "water")
t.run_ticks(2)
ui_controls.toggle(p, "eject")
t.run_ticks(2)
assert(t.hands(p).held == "beaker", "the beaker comes back out full")

-- Tip it onto the deck beside us.
composition.click_deck(p, 4, 1)
t.tick()

local spill = composition.examine_deck(p, 4, 1)
assert(spill ~= nil, "the deck answers")
assert(spill.title == "floor", "still by its turf word: " .. spill.title)
assert(#spill.lines > 0, "and now it has something to say")
local puddle: string? = nil
for _, line in ipairs(spill.lines) do
    if line:find("^A puddle: ") ~= nil then puddle = line end
end
assert(puddle ~= nil, "the spill carries its puddle line: " .. dump(spill))
assert(puddle:find("^A puddle: ") ~= nil, "which is that there is a puddle: " .. dump(spill))
assert(puddle:find(" of liquid water%.$") ~= nil, "of liquid water: " .. dump(spill))
local pw, pc = tinted(spill, puddle)
assert(pw == "water" and pc == "#AAAAAA", "in water's colour, as through glass")

-- A dry tile a stride away says nothing at all, which is the negative
-- that makes the positive mean something.
local dry = composition.examine_deck(p, 2, 1)
assert(dry ~= nil and #dry.lines == 1, "a dry deck has only its authored description: " .. dump(assert(dry)))
assert(dry.lines[1] == "Standard station tiling, laid over the deck plating.", "the dry floor's authored description")

-- ---------------------------------------------------------------
-- SEVEN: A SHUT DOOR IS THE VIEW BOUNDARY.
--
-- The same seam as the sealed cell, drawn by a door instead of a wall:
-- a forged look at the far side of a shut leaf is silence, and the
-- same look through the open leaf is an answer.
-- ---------------------------------------------------------------
t.world(
    [==[(
    name: "examine door",
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'g': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Generator)),
    },
    rows: [
        "#######",
        "#g....#",
        "#######",
    ],
    structures: [(2, 1, "player_spawn"), (2, 1, "apc"), (3, 1, "airlock")],
    items: [(5, 1, "beaker")],
    networks: [
        (x: 1, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 1, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 2, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 3, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 3, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
    ],
)]==],
    0
)

local q = t.join()
t.tick()
assert(not assert(t.door_at(3, 1)).open, "the door opens the shift shut")
assert(t.target_at(q, 5, 1, "beaker") == nil, "nothing past it is disclosed")
assert(not pcall(function()
    t.examine(q, 5, 1)
end), "and a claim through the shut leaf buys no look")

t.click(q, 3, 1, t.target_at(q, 3, 1))
t.run_ticks(15)
assert(assert(t.door_at(3, 1)).open, "the leaf opens to an empty hand")
local through = assert(t.target_at(q, 5, 1, "beaker"), "the far side is in view now")
assert(t.examine(q, 5, 1, through) ~= nil, "and the same look is an answer")
