-- The drawer that is already occupied: what a crewman finds when they
-- pull on `cadaver_chamber.cadaver`, and what a plain
-- `cadaver_chamber` never has in it.
--
-- The whole point of this variant is that the engine decides nothing
-- about it. The row says a plan, a number and a kit; `content/bodies/
-- human.luau` decides that the number is death and says the word.
--
-- Wired, because a chamber's lamp reads its own power: the plant, the
-- controller and the socket sit behind the rank, within cord reach of
-- both drawers (docs/POWER.md, "Outlets and cords").
t.world([==[(
    name: "cadaver bench",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        'G': (turf: Floor, fixture: Some(Generator)),
        'a': (turf: Floor, fixture: Some(Apc)),
        'o': (turf: Floor, fixture: Some(Outlet)),
    },
    rows: [
        "#######",
        "#.....#",
        "#.....#",
        "#Gao..#",
        "#######",
    ],
    spawns: [(1, 1)],
    items: [],
    structures: [
        (2, 1, "cadaver_chamber.cadaver", { "dir": "east" }),
        (2, 2, "cadaver_chamber", { "dir": "east" }),
    ],
    cables: [(1, 3, 2), (2, 3, 3), (3, 3, 1)],
)]==], 0)

local attendant = t.join()
t.tick()

-- Shut, it is a cabinet like any other: nothing on the aisle tile, and
-- nobody in the room can see what is in it.
assert(t.structure_at(3, 1) == nil, "a shut drawer's tray is nowhere")
assert(#t.bodies_at(3, 1) == 0, "and neither is what it is holding")
assert(t.structure_at(2, 1).overlays[1] == "morgue2_e",
    "the occupied lamp is lit from the moment the map stands it up")

local occupied = t.target_at(2, 1, "cadaver_chamber.cadaver")
assert(occupied ~= nil, "the variant is a real prototype a click can name")
t.click(attendant, 2, 1, occupied)
t.tick()

local found = t.bodies_at(3, 1)
assert(#found == 1, "one body rolled out with the slab")
local corpse = found[1]
assert(corpse.plan == "human", "minted from the plan the row named")
assert(corpse.player == false, "nobody is at the wheel of it")
assert(corpse.animate == false, "the plan's own hook stopped it")
assert(corpse.label == "Dead", "in the pack's own word for that")
assert(corpse.posture == "lying", "and it is lying on the slab")
assert(corpse.health <= -100, "200 brute is past the plan's dead line")

assert(corpse.name ~= "", "and it has a name, which is all it kept")
assert(corpse.worn.uniform == "uniform_grey",
    "wearing the jumpsuit the outfit row named")
assert(corpse.worn.id == nil, "and no ID: an unidentified body is the point")

-- It goes back in when the drawer shuts, like anything else on a slab.
t.click(attendant, 2, 1, occupied)
t.tick()
assert(t.structure_at(3, 1) == nil, "the slab goes back in")
assert(#t.bodies_at(3, 1) == 0, "with the body on it")
assert(t.structure_at(2, 1).overlays[1] == "morgue2_e",
    "and the lamp says so again")

-- The plain entry beside it declares no stock at all.
local plain = t.target_at(2, 2, "cadaver_chamber")
assert(t.structure_at(2, 2).overlays[1] == nil, "an empty drawer wears no lamp")
t.click(attendant, 2, 2, plain)
t.tick()
assert(t.structure_at(3, 2) ~= nil, "it opens")
assert(#t.bodies_at(3, 2) == 0, "onto an empty slab")

assert(t.ledger_has("BodySpawned", "human"), "the spawn is on the record")
assert(#t.ledger_rows("body_spawned") == 1, "exactly one body was stood up")

-- Determinism: the same seed rolls the same crewman, twice.
--
-- Wired like the bench above — this one is about the ROLL and not about
-- power, and four unfed chambers here would be four true
-- `corded fixture has no outlet within cord range` warnings drowning
-- out the one bench that means to trip it.
local function rolled_name(seed)
    t.world([==[(
        name: "cadaver bench",
        legend: {
            ' ': (turf: Space),
            '.': (turf: Floor),
            '#': (turf: Wall),
            'G': (turf: Floor, fixture: Some(Generator)),
            'a': (turf: Floor, fixture: Some(Apc)),
            'o': (turf: Floor, fixture: Some(Outlet)),
        },
        rows: [
            "#####",
            "#...#",
            "#Gao#",
            "#####",
        ],
        spawns: [(1, 1)],
        items: [],
        structures: [(2, 1, "cadaver_chamber.cadaver", { "dir": "east" })],
        cables: [(1, 2, 2), (2, 2, 3), (3, 2, 1)],
    )]==], seed)
    local crew = t.join()
    t.tick()
    local drawer = t.target_at(2, 1, "cadaver_chamber.cadaver")
    t.click(crew, 2, 1, drawer)
    t.tick()
    local rows = t.ledger_rows("body_spawned")
    assert(#rows == 1, "one row per stocked drawer")
    return t.bodies_at(3, 1)[1].name
end

assert(rolled_name(0) == rolled_name(0), "a seed replays its drawer exactly")
-- ...and the roll reads the shift RNG at all. Both seeds are fixed, so
-- this is a fact about the build and not a coin flip. They are 0 and 9
-- rather than 0 and 1 because the shift RNG is seeded straight into a
-- `Pcg64Mcg` state and ADJACENT seeds still agree several draws in
-- (0 and 1 roll the same crewman; so do 2 and 3).
assert(rolled_name(0) ~= rolled_name(9), "another seed rolls another crewman")
