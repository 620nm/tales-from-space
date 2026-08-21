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

t.world([==[(
    name: "examine bench",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "########",
        "#....#.#",
        "########",
    ],
    spawns: [(1, 1)],
    items: [(2, 1, "burner"), (3, 1, "beaker_libital"), (4, 1, "beaker"), (6, 1, "bottle")],
    machines: [(3, 0, "chem_dispenser")],
)]==], 0)

local p = t.join()
t.tick()

local burner = t.target_at(2, 1, "burner")
local mixed = t.target_at(3, 1, "beaker_libital")
local taps = t.target_at(3, 0)
local beaker = t.target_at(4, 1, "beaker")
local locked_away = t.target_at(6, 1, "bottle")

-- The tinted run of one line: which words are written in a colour, and
-- which colour. A line is spans now, and `spans[i]` is always the same
-- text as `lines[i]` -- the cuts fall at colour changes, never at word
-- breaks -- so a spec can assert either and mean the same sentence.
local function tinted(look, line)
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
local lamp = t.examine(p, 2, 1, burner)
assert(lamp ~= nil, "the burner answers")
assert(
    has(lamp, "0.38 mol of liquid ethanol."),
    "what is in it, by name and state: " .. dump(lamp)
)
assert(not has(lamp, "It is lit."), "and it is not burning yet: " .. dump(lamp))

-- ---------------------------------------------------------------
-- TWO: A LIT FLAME IS A THING ANYONE CAN SEE.
-- ---------------------------------------------------------------
t.click(p, 2, 1, burner)
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
assert(t.examine(p, 6, 1, locked_away) == nil, "nothing about a thing behind a wall")
assert(t.examine(p, 6, 1) == nil, "nor about a tile nobody can see")
assert(t.examine(p, 4, 1, beaker) ~= nil, "but three tiles of clear floor is a look")

-- A claim naming the wrong tile is the same silence a wall gets.
assert(t.examine(p, 3, 1, beaker) == nil, "a lie buys no look")

-- ---------------------------------------------------------------
-- FOUR: THE GROUND, AND THE MACHINE.
-- ---------------------------------------------------------------
local deck = t.examine(p, 1, 1)
assert(deck ~= nil and deck.title == "floor", "the deck names its turf")
assert(#deck.lines == 0, "and states nothing else: " .. dump(deck))

local dispenser = t.examine(p, 3, 0, taps)
assert(dispenser ~= nil, "the machine answers")
assert(dispenser.title == "chem dispenser", "by its own name: " .. dispenser.title)
assert(dispenser.lines[1]:find("shelf of taps") ~= nil, "with its file's prose: " .. dump(dispenser))

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
assert(has(mix, "0.20 mol of liquid water."), "water, and it is liquid: " .. dump(mix))
assert(has(mix, "0.15 mol of liquid libital."), "so is the libital: " .. dump(mix))

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
assert(first == "0.20 mol of liquid water.", "the larger share leads: " .. dump(mix))
assert(second == "0.15 mol of liquid libital.", "and the smaller follows: " .. dump(mix))

local word, color = tinted(mix, "0.20 mol of liquid water.")
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
t.move(p, "east")
t.run_ticks(4)

t.click(p, 4, 1, beaker) -- into the hand
t.tick()
t.click(p, 3, 0, taps) -- and into the machine
t.tick()
t.click(p, 3, 0, taps) -- ...which opens its panel
t.tick()
-- Two presses, because one press is not yet a puddle: the pane names a
-- spill at exactly the amount the floor starts DRAWING one, so a look
-- can never report something the eye cannot find.
t.ui_act(p, "toggle", '{"field":"dispense","option":"water"}')
t.run_ticks(2)
t.ui_act(p, "toggle", '{"field":"dispense","option":"water"}')
t.run_ticks(2)
t.ui_act(p, "toggle", '{"field":"eject"}')
t.run_ticks(2)
assert(t.hands(p).held == "beaker", "the beaker comes back out full")

-- Tip it onto the deck beside us.
t.click(p, 4, 1)
t.tick()

local spill = t.examine(p, 4, 1)
assert(spill ~= nil, "the deck answers")
assert(spill.title == "floor", "still by its turf word: " .. spill.title)
assert(#spill.lines > 0, "and now it has something to say")
local puddle = spill.lines[1]
assert(puddle:find("^A puddle: ") ~= nil, "which is that there is a puddle: " .. dump(spill))
assert(puddle:find(" of liquid water%.$") ~= nil, "of liquid water: " .. dump(spill))
local pw, pc = tinted(spill, puddle)
assert(pw == "water" and pc == "#AAAAAA", "in water's colour, as through glass")

-- A dry tile a stride away says nothing at all, which is the negative
-- that makes the positive mean something.
local dry = t.examine(p, 2, 1)
assert(dry ~= nil and #dry.lines == 0, "a dry deck states nothing: " .. dump(dry))
