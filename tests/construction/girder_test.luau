local composition = require("@helpers/composition")
local ui_controls = require("@helpers/ui_controls")

-- The girder's bolts, driven the way a player would drive them.
--
-- What tg actually does (checked against girders.dm and the
-- uses_girder_wall_recipes element, because the folklore is wrong): the
-- stack recipe is "wall girders (anchored)", so a girder you build is
-- already bolted down. The wrench does not finish the build -- it takes
-- the bolts back OUT, four seconds each way. A displaced girder can be
-- shoved around the deck and will not take a wall until it is bolted
-- down again, because every wall recipe demands GIRDER_NORMAL.

-- How many sheets are in the hand, read the way a player reads it:
-- a stack carries its count in its own name, so a look answers it
-- (the idiom is tests/chemistry/products_test.luau:126).
local function sheets_held(player: number): number
    local look = assert(t.examine_held(player), "the sheets answer a look")
    local written: string? = string.match(look.title, "%((%d+)%)$")
    -- Bound before returning: `assert` hands its message back beside
    -- the value, so a bare `return assert(...)` would pass that message
    -- on to whatever this call is the last argument of.
    local count = assert(tonumber(written or ""), "a stack names its count, got " .. look.title)
    return count
end

t.world(
    [==[(
    name: "site",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    rows: [
        "######",
        "#....#",
        "#....#",
        "#....#",
        "######",
    ],
    structures: [(1, 1, "player_spawn")],
    items: [(2, 1, "metal"), (2, 2, "wrench")],
)]==],
    7
)

local p = t.join()
t.tick()
t.click(p, 2, 1, t.target_at(p, 2, 1, "metal")) -- sheets in one hand
t.run_ticks(2)
t.swap_hands(p)
t.click(p, 2, 2, t.target_at(p, 2, 2, "wrench")) -- wrench in the other
t.run_ticks(2)

-- A girder rises bolted down: no wrench step, exactly as tg builds one.
-- Two sheets and four seconds, both off tg's stack recipe on one line
-- ("wall girders (anchored)", 2 sheets, `time = 4 SECONDS` --
-- sheet_types.dm:89). The clock is pinned from both sides, so a recipe
-- that got quicker fails here as loudly as one that got slower.
t.swap_hands(p)
local stock = sheets_held(p)
ui_controls.build(p, "metal", "girder", 1, 2)
t.run_seconds(3.8)
assert(not t.ledger_has("StructureStep", "girder", "built"), "nothing stands a breath short of four seconds")
t.run_seconds(0.7)
assert(t.ledger_has("StructureStep", "girder", "built"), "the girder rose")
local left = sheets_held(p)
assert(stock - left == 2, "two sheets went into it, not " .. stock - left)

-- The wrench loosens it.
t.swap_hands(p)
t.click(p, 1, 2, t.target_at(p, 1, 2))
t.run_seconds(4.5)
assert(
    t.ledger_has("StructureStep", "girder", "displaced"),
    "four seconds of wrenching took the bolts out"
)

-- And now no wall goes on it. The refusal is immediate and says which
-- state the job wants; a silent no-op would read as a dropped click.
t.swap_hands(p)
t.messages(p)
t.click(p, 1, 2, t.target_at(p, 1, 2))
t.run_ticks(2)
local said = t.messages(p)
local refused = false
for _, m in ipairs(said) do
    if m == "The girder must be anchored first." then
        refused = true
    end
    assert(m ~= "You start plating the girder into a wall.", "the work never started")
end
assert(refused, "the refusal named the state it wants")

-- Loose means loose: walk into it and it gives way, and you follow into
-- the tile it left. (tg would have you PULL it; we shove. Same outcome,
-- fewer moving parts -- see movement.rs::shove.)
t.move(p, "south")
t.run_ticks(3)
local x, y = t.pos(p)
assert(x == 1 and y == 2, "the walker followed it in, got " .. x .. "," .. y)
assert(t.ledger_has("StructureStep", "girder", "pushed"), "and the shove is on the record")

-- Bolt it back down where it ended up, and the wall finally closes.
t.swap_hands(p)
t.click(p, 1, 3, t.target_at(p, 1, 3))
t.run_seconds(4.5)
assert(t.ledger_has("StructureStep", "girder", "anchored"), "the wrench turns both ways")

t.swap_hands(p)
t.click(p, 1, 3, t.target_at(p, 1, 3))
t.run_seconds(4.5)
assert(composition.matches(1, 3, { "station_base", "floor_tiles", "wall" }), "the wall stands, got " .. composition.describe(1, 3))

-- Four seconds of work is four seconds of STANDING THERE: the do_after
-- guard revalidates reach every tick, so walking away mid-wrench takes
-- the bolts nowhere and puts the abandonment on the record. (This is
-- the reach half of the Rust m4 walk-away test; the drop half lives in
-- welder_test. A dry room, deliberately -- decompression wind dragging
-- the welder toward a hull breach was never what that test was about.)
t.world(
    [==[(
    name: "walkaway",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    rows: [
        "######",
        "#....#",
        "#....#",
        "#....#",
        "######",
    ],
    structures: [(1, 1, "player_spawn")],
    items: [(2, 1, "metal"), (2, 2, "wrench")],
)]==],
    7
)

p = t.join()
t.tick()
t.click(p, 2, 1, t.target_at(p, 2, 1, "metal")) -- sheets
t.run_ticks(2)
t.swap_hands(p)
t.click(p, 2, 2, t.target_at(p, 2, 2, "wrench")) -- wrench
t.run_ticks(2)
t.swap_hands(p)
ui_controls.build(p, "metal", "girder", 1, 2) -- raise a girder to work on
t.run_seconds(4.5)
assert(t.ledger_has("StructureStep", "girder", "built"), "the girder rose")

t.swap_hands(p)
t.click(p, 1, 2, t.target_at(p, 1, 2)) -- start unbolting it
t.run_ticks(5)
for _ = 1, 3 do -- and walk out of reach before the four seconds land
    t.move(p, "east")
    t.run_ticks(5)
end
local walked = t.pos(p)
assert(walked >= 4, "walked clear of the work, only got to " .. walked)
t.run_seconds(4.5)
assert(not t.ledger_has("StructureStep", "girder", "displaced"), "walked away, no bolts out")
local cut = t.ledger_rows("DoAfterInterrupted")
assert(#cut == 1, "one interruption is recorded")
local at = cut[1].at
assert(type(at) == "table", "the interruption records its location")
local coordinates = at :: { unknown }
assert(
    cut[1].file == "girder" and coordinates[1] == 1 and coordinates[2] == 2,
    "the guard names the work it cut short"
)

-- Scenario 3: what a girder costs, both directions. Two sheets raise
-- one (sheet_types.dm:89 again) and a torch hands exactly those two
-- back -- whatever state it finds it in, because tg's `welder_act`
-- (girders.dm:107) asks for none: its `try_construction_step(user,
-- tool, 4 SECONDS, start_alert = "slicing apart...")` at :113 carries
-- no `req_state` at all. Displaced is the sharp case, being the one
-- state every other girder step refuses.
t.world(
    [==[(
    name: "torch",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    rows: [
        "######",
        "#....#",
        "#....#",
        "#....#",
        "######",
    ],
    structures: [(1, 1, "player_spawn")],
    items: [(2, 1, "metal"), (2, 1, "welder"), (2, 2, "wrench")],
)]==],
    7
)

p = t.join()
t.tick()
t.click(p, 2, 2, t.target_at(p, 2, 2, "wrench")) -- wrench in one hand
t.run_ticks(2)
t.swap_hands(p)
t.click(p, 2, 1, t.target_at(p, 2, 1, "metal")) -- sheets in the other
t.run_ticks(2)
local stacked = sheets_held(p)
ui_controls.build(p, "metal", "girder", 1, 2)
t.run_seconds(4.5)
assert(t.ledger_has("StructureStep", "girder", "built"), "the girder rose")
assert(stacked - sheets_held(p) == 2, "two sheets went into it")

-- Take the bolts out, so the torch meets the state nothing else takes.
t.swap_hands(p)
t.click(p, 1, 2, t.target_at(p, 1, 2))
t.run_seconds(4.5)
assert(assert(t.structure_at(1, 2)).state == "displaced", "the bolts are out")

t.drop(p) -- the wrench is done; the torch wants the hand
t.run_ticks(2)
t.click(p, 2, 1, t.target_at(p, 2, 1, "welder"))
t.run_ticks(2)
t.use_self(p) -- light it
t.tick()
local loose_before = t.count_items("metal")
t.click(p, 1, 2, t.target_at(p, 1, 2))
t.run_seconds(3.8)
assert(t.structure_at(1, 2) ~= nil, "four seconds of cutting is four seconds")
t.run_seconds(0.7)
assert(t.structure_at(1, 2) == nil, "the girder comes apart")
assert(t.count_items("metal") == loose_before + 1, "one fresh pile lands where it stood")
local pile = assert(
    t.examine(p, 1, 2, t.target_at(p, 1, 2, "metal")),
    "the sheets are back on the deck"
)
assert(pile.title == "metal sheets (2)", "exactly what it cost, got " .. pile.title)
