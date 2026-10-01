local ui_controls = require("@helpers/ui_controls")

-- The C-20r downrange: one pull spends one round for 30 brute at the
-- aimed zone on tg's full-auto cadence, a reload off the carrier's
-- magazine tops the weapon back up, and the dry gun clicks
-- (`content/lib/firearm.luau`).
t.world(
    [==[(
    name: "smg",
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    rows: ["########", "#......#", "########"],
    structures: [(1, 1, "player_spawn")],
    items: [(1, 1, "smg"), (1, 1, "smg_mag"), (2, 1, "round_9mm"), (3, 1, "round_c45")],
)]==],
    0
)

local shooter = t.join()
local victim = t.join()
t.tick()

local function take(id: string, x: number?, y: number?)
    x = x or 1
    y = y or 1
    t.click(shooter, x, y, (assert(t.target_at(shooter, x, y, id), id .. " is visible")))
    t.run_ticks(2)
end

local function heard(): { [string]: boolean }
    local ids: { [string]: boolean } = {}
    for _, sound in ipairs(t.sounds(shooter)) do
        ids[sound] = true
    end
    return ids
end

local function said(): string
    local lines = t.messages(shooter)
    return lines[#lines] or ""
end

-- Shots only: a reload's spent rounds land in `item_consumed` too.
local function consumed(): { any }
    local shots = {}
    for _, row in ipairs(t.ledger_rows("item_consumed")) do
        if row.proto == "smg" then
            shots[#shots + 1] = row
        end
    end
    return shots
end

local function refilled(): { any }
    return t.ledger_rows("item_refilled")
end

local function charges(row: any): number
    return ui_controls.number(ui_controls.record(row.after).charges)
end

local function brute(): number
    return ui_controls.number(t.health(victim).brute)
end

local function fire()
    t.click(shooter, 4, 1, t.body_target(shooter, victim))
    t.run_ticks(6)
end

local function idle(): string?
    local hands = t.hands(shooter)
    return hands[3 - hands.active]
end

-- The magazine first, empty-handed: clicking a floor container with
-- a full hand offers the held item to it instead of picking it up.
take("smg_mag")
assert(t.hands(shooter).held == "smg_mag", "the magazine is in hand")
take("smg")
if t.hands(shooter).held ~= "smg" then
    t.swap_hands(shooter)
    t.run_ticks(2)
end
assert(t.hands(shooter).held == "smg", "the SMG is active")
heard()

-- Three tiles downrange, past the reach gate, inside the sight.
t.move(victim, "east")
t.run_ticks(6)
t.move(victim, "east")
t.run_ticks(6)
t.move(victim, "east")
t.run_ticks(6)
local vx, vy = t.pos(victim)
assert(vx == 4 and vy == 1, "the victim stands downrange")

-- ONE: 30 brute on the aimed zone, the shot heard, 24 down to 23.
-- A second pull back-to-back, no tick between: the 0.3 s cadence eats
-- it whole.
t.click(shooter, 4, 1, t.body_target(shooter, victim))
t.click(shooter, 4, 1, t.body_target(shooter, victim))
t.run_ticks(6)
assert(brute() == 30, ("one round lands 30 brute, got %d"):format(brute()))
local first = heard()
assert(first["smg_shot"], "the shot itself")
assert(first["punch"], "and the flesh under it")
assert(#consumed() == 1, "one charge spent")
assert(charges(consumed()[1]) == 23, "24 down to 23")
-- The wound answers downrange with the round: 30 brute spills 3 units
-- on the victim's tile, and the mark sits over it in the wound paint.
local spilled = t.matter_totals().substances["blood"] or 0
assert(math.abs(spilled - 0.075) < 1e-6, ("3 units downrange, got %.6f"):format(spilled))
local mark = nil
for _, decal in ipairs(t.decals_at(4, 1)) do
    if decal.decal == "blood" then
        mark = decal
    end
end
assert(mark ~= nil, "a blood mark on the victim's tile")
assert(mark.paint == "blood", "in the wound paint, not a crew colour")

-- TWO: past the cadence, the next round lands (60, 22 left).
t.run_seconds(0.4)
fire()
assert(brute() == 60, ("two rounds land 60, got %d"):format(brute()))
assert(#consumed() == 2, "two charges spent")
assert(charges(consumed()[2]) == 22, "22 left")

-- RELOAD: two rounds back in, the rack heard, the stick two lighter.
t.use_self(shooter)
t.run_ticks(6)
assert(#t.script_errors() == 0, "the reload runs clean")
assert(said() == "You reload the SMG.", "reloading is reported: " .. said())
assert(heard()["smg_rack"], "and racked")
assert(#refilled() == 2, "two rounds move")
assert(ui_controls.number(refilled()[2].after) == 24, "back to full")
t.swap_hands(shooter)
t.run_ticks(2)
assert(t.hands(shooter).held == "smg_mag", "the magazine is active")
t.drop(shooter)
t.run_ticks(2)
-- The stick's count is proven at BACK UP: 22 refills move, no more.

-- ALREADY LOADED: a second stroke is refused out loud, moving nothing.
t.swap_hands(shooter)
t.run_ticks(2)
assert(t.hands(shooter).held == "smg", "the SMG is active again")
t.use_self(shooter)
t.run_ticks(6)
assert(said() == "The SMG is already loaded.", "a full gun says so: " .. said())
assert(#refilled() == 2, "and moves nothing")

-- EMPTY: 24 pulls on the 0.4 s metronome, then the dry click. The
-- victim is long past dead; ranged claims still reach a corpse.
for _ = 1, 24 do
    t.click(shooter, 4, 1, t.body_target(shooter, victim))
    t.run_seconds(0.4)
end
assert(#consumed() == 26, ("26 rounds spent, got %d"):format(#consumed()))
assert(charges(consumed()[26]) == 0, "the last leaves none")
heard()
t.click(shooter, 4, 1, t.body_target(shooter, victim))
t.run_ticks(6)
assert(said() == "The SMG clicks empty.", "the dry gun clicks: " .. said())
assert(#consumed() == 26, "the dry pull spends nothing")
assert(not heard()["smg_shot"], "and fires nothing")

-- NO MAGAZINE: the stick on the deck feeds nothing.
t.use_self(shooter)
t.run_ticks(6)
assert(
    said() == "You have no loaded magazine for the SMG.",
    "an unheld stick feeds nothing: " .. said()
)
assert(#refilled() == 2, "and moves nothing")

-- BACK UP: the stick back in hand feeds its 22, and the gun speaks.
-- The SMG goes down first: a held gun clicked at a gappy stick would
-- stow INTO it, natively and silently.
t.drop(shooter)
t.run_ticks(2)
take("smg_mag")
take("smg")
if t.hands(shooter).held ~= "smg" then
    t.swap_hands(shooter)
    t.run_ticks(2)
end
assert(t.hands(shooter).held == "smg", "the SMG is active for the last reload")
t.use_self(shooter)
t.run_ticks(6)
assert(said() == "You reload the SMG.", "the last reload is reported")
assert(#refilled() == 24, ("22 more rounds move, got %d"):format(#refilled()))
fire()
assert(#consumed() == 27, "and the gun speaks again")
assert(heard()["smg_shot"], "loudly")

-- SPENT: the stick gave all 22; the gun, still wanting two more,
-- hears it has none. An unspent round would have fed instead.
t.use_self(shooter)
t.run_ticks(6)
assert(
    said() == "You have no loaded magazine for the SMG.",
    "the spent stick feeds nothing: " .. said()
)
assert(#refilled() == 24, "and moves nothing")

-- COMPAT: the stick takes .45 and refuses 9mm, and starves what
-- slips in past the gate. The SMG goes down to free a hand.
t.drop(shooter)
t.run_ticks(2)
t.swap_hands(shooter)
t.run_ticks(2)
assert(t.hands(shooter).held == "smg_mag", "the stick is active")
-- Loose rounds ride their own tiles: a casing under a boot has no
-- hittable pixel, so the hand takes each from the next tile over.
take("round_9mm", 2, 1)
if t.hands(shooter).held ~= "round_9mm" then
    t.swap_hands(shooter)
    t.run_ticks(2)
end
assert(idle() == "smg_mag", "the stick waits in the off hand")
assert(t.hands(shooter).held == "round_9mm", "the 9mm is offered")
t.use_on_other(shooter)
t.run_ticks(2)
assert(
    said() == "That round does not fit the magazine.",
    "the wrong caliber is refused: " .. said()
)
assert(t.hands(shooter).held == "round_9mm", "the 9mm stays in hand")
assert(idle() == "smg_mag", "and the stick stays put")

-- The right caliber seats: out of the hand, off the deck, into the stick.
-- The refused 9mm is parked on its own tile for STARVE below.
t.swap_hands(shooter)
t.run_ticks(2)
t.move(shooter, "east")
t.run_ticks(6)
t.swap_hands(shooter)
t.run_ticks(2)
t.drop(shooter)
t.run_ticks(2)
take("round_c45", 3, 1)
if idle() ~= "round_c45" then
    t.swap_hands(shooter)
    t.run_ticks(2)
end
assert(t.hands(shooter).held == "smg_mag", "the stick is active again")
assert(idle() == "round_c45", "the .45 is offered")
t.use_on_other(shooter)
t.run_ticks(2)
assert(idle() == nil, "the .45 left the off hand")
assert(t.item_at(3, 1, "round_c45") == nil, "off its tile")
assert(t.item_at(2, 1, "round_c45") == nil, "and off this one: it is in the stick")

-- STARVE: a 9mm slipped onto the floor stick natively still never feeds.
t.move(shooter, "west")
t.run_ticks(6)
take("round_9mm", 2, 1)
if t.hands(shooter).held ~= "smg_mag" then
    t.swap_hands(shooter)
    t.run_ticks(2)
end
t.drop(shooter)
t.run_ticks(2)
t.swap_hands(shooter)
t.run_ticks(2)
assert(t.hands(shooter).held == "round_9mm", "the 9mm is in hand over the floor stick")
take("smg_mag")
assert(t.hands(shooter).held == nil, "the 9mm left the hand")
assert(t.item_at(1, 1, "round_9mm") == nil, "and it is nowhere on the deck")
take("smg_mag")
take("smg")
if t.hands(shooter).held ~= "smg" then
    t.swap_hands(shooter)
    t.run_ticks(2)
end
t.use_self(shooter)
t.run_ticks(6)
assert(said() == "You reload the SMG.", "the seated .45 feeds")
assert(#refilled() == 25, "one round moves, not two")
t.use_self(shooter)
t.run_ticks(6)
assert(
    said() == "You have no loaded magazine for the SMG.",
    "the slipped 9mm never feeds: " .. said()
)
assert(#refilled() == 25, "and moves nothing")
