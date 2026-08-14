-- The girder's bolts, driven the way a player would drive them.
--
-- What tg actually does (checked against girders.dm and the
-- uses_girder_wall_recipes element, because the folklore is wrong): the
-- stack recipe is "wall girders (anchored)", so a girder you build is
-- already bolted down. The wrench does not finish the build -- it takes
-- the bolts back OUT, four seconds each way. A displaced girder can be
-- shoved around the deck and will not take a wall until it is bolted
-- down again, because every wall recipe demands GIRDER_NORMAL.
t.world([==[(
    name: "site",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "######",
        "#....#",
        "#....#",
        "#....#",
        "######",
    ],
    spawns: [(1, 1)],
    items: [(2, 1, "metal"), (2, 2, "wrench")],
)]==], 7)

local p = t.join()
t.tick()
t.click(p, 2, 1) -- sheets in one hand
t.run_ticks(2)
t.swap_hands(p)
t.click(p, 2, 2) -- wrench in the other
t.run_ticks(2)

-- A girder rises bolted down: no wrench step, exactly as tg builds one.
t.swap_hands(p)
t.click(p, 1, 2)
t.run_seconds(4.5)
assert(t.ledger_has("StructureStep", "girder", "built"), "the girder rose")

-- The wrench loosens it.
t.swap_hands(p)
t.click(p, 1, 2)
t.run_seconds(4.5)
assert(t.ledger_has("StructureStep", "girder", "displaced"),
    "four seconds of wrenching took the bolts out")

-- And now no wall goes on it. The refusal is immediate and says which
-- state the job wants; a silent no-op would read as a dropped click.
t.swap_hands(p)
local _ = t.messages(p)
t.click(p, 1, 2)
t.run_ticks(2)
local said = t.messages(p)
local refused = false
for _, m in ipairs(said) do
    if m == "The girder must be anchored first." then
        refused = true
    end
    assert(m ~= "You start plating the girder into a wall.",
        "the work never started")
end
assert(refused, "the refusal named the state it wants")

-- Loose means loose: walk into it and it gives way, and you follow into
-- the tile it left. (tg would have you PULL it; we shove. Same outcome,
-- fewer moving parts -- see movement.rs::shove.)
t.move(p, "south")
t.run_ticks(3)
local x, y = t.pos(p)
assert(x == 1 and y == 2, "the walker followed it in, got " .. x .. "," .. y)
assert(t.ledger_has("StructureStep", "girder", "pushed"),
    "and the shove is on the record")

-- Bolt it back down where it ended up, and the wall finally closes.
t.swap_hands(p)
t.click(p, 1, 3)
t.run_seconds(4.5)
assert(t.ledger_has("StructureStep", "girder", "anchored"),
    "the wrench turns both ways")

t.swap_hands(p)
t.click(p, 1, 3)
t.run_seconds(4.5)
assert(t.turf(1, 3) == "wall", "the wall stands, got " .. tostring(t.turf(1, 3)))

-- Four seconds of work is four seconds of STANDING THERE: the do_after
-- guard revalidates reach every tick, so walking away mid-wrench takes
-- the bolts nowhere and puts the abandonment on the record. (This is
-- the reach half of the Rust m4 walk-away test; the drop half lives in
-- welder_test. A dry room, deliberately -- decompression wind dragging
-- the welder toward a hull breach was never what that test was about.)
t.world([==[(
    name: "walkaway",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "######",
        "#....#",
        "#....#",
        "#....#",
        "######",
    ],
    spawns: [(1, 1)],
    items: [(2, 1, "metal"), (2, 2, "wrench")],
)]==], 7)

p = t.join()
t.tick()
t.click(p, 2, 1) -- sheets
t.run_ticks(2)
t.swap_hands(p)
t.click(p, 2, 2) -- wrench
t.run_ticks(2)
t.swap_hands(p)
t.click(p, 1, 2) -- raise a girder to work on
t.run_seconds(4.5)
assert(t.ledger_has("StructureStep", "girder", "built"), "the girder rose")

t.swap_hands(p)
t.click(p, 1, 2) -- start unbolting it
t.run_ticks(5)
for _ = 1, 3 do  -- and walk out of reach before the four seconds land
    t.move(p, "east")
    t.run_ticks(5)
end
local walked = t.pos(p)
assert(walked >= 4, "walked clear of the work, only got to " .. walked)
t.run_seconds(4.5)
assert(not t.ledger_has("StructureStep", "girder", "displaced"),
    "walked away, no bolts out")
local cut = t.ledger_rows("DoAfterInterrupted")
assert(#cut == 1 and cut[1].file == "girder"
    and cut[1].at[1] == 1 and cut[1].at[2] == 2,
    "the guard names the work it cut short")
