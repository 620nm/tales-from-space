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
    items: [(2, 1, "burner"), (4, 1, "beaker"), (6, 1, "bottle")],
    machines: [(3, 0, "chem_dispenser")],
)]==], 0)

local p = t.join()
t.tick()

local burner = t.target_at(2, 1, "burner")
local beaker = t.target_at(4, 1, "beaker")
local locked_away = t.target_at(6, 1, "bottle")

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
assert(has(lamp, "0.38 mol of ethanol."), "what is in it, by name: " .. dump(lamp))
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

local dispenser = t.examine(p, 3, 0, t.target_at(3, 0))
assert(dispenser ~= nil, "the machine answers")
assert(dispenser.title == "chem dispenser", "by its own name: " .. dispenser.title)
assert(dispenser.lines[1]:find("shelf of taps") ~= nil, "with its file's prose: " .. dump(dispenser))
