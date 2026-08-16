-- Free Build: connect and you are already standing in the station with
-- the tools to build one. Nobody picks a job in the sandbox, so the
-- mode issues the Station Engineer's outfit instead
-- (`rules.outfit = "engineer"` in content/gamemodes/free_build.luau) —
-- the GEAR, not the role: no slot is taken and no crew manifest
-- changes. A body that spawns bare has to walk to a vendor before it
-- can do the one thing the mode exists for.
t.world([==[(
    name: "build site",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "#####",
        "#...#",
        "#####",
    ],
    spawns: [(1, 1), (2, 1)],
)]==], 7, "free_build")

-- No job argument: this mode seats the body on connection, and there is
-- no board to pick from.
local builder = t.join()
t.tick()

local worn = t.worn(builder)
assert(worn.uniform == "uniform_eng", "in an engineer's jumpsuit, got " .. tostring(worn.uniform))
assert(worn.id == "id_engineering", "with the engineering ID clipped on")
assert(worn.belt == "toolbelt", "and a toolbelt at the waist")
assert(worn.back == "backpack", "over the standard-issue pack")

-- The belt arrives stocked from its own roster, exactly as it would at
-- the job board: the sandbox spawn is not a second, thinner outfit.
local belt = t.stored(builder, "belt")
assert(table.concat(belt, ",")
    == "screwdriver,wrench,welder,crowbar,wirecutters,multitool,cable_coil",
    "the whole tool suite: " .. table.concat(belt, ","))
assert(table.concat(t.stored(builder, "back"), ",") == "metal,floor_tile,headset",
    "and the building stock rides the pack")

-- Player-observable, because that is the point: the tools work from the
-- moment you arrive. Pull the wrench and it is in hand this tick.
t.take_from(builder, "belt", 2)
t.tick()
assert(t.hands(builder).held == "wrench", "the wrench came straight off the belt")
assert(#t.stored(builder, "belt") == 6, "and the belt is one lighter")

-- Everyone who connects is dressed, from the mode rather than from the
-- board: a second arrival gets its own outfit, with its own stocked
-- belt, and neither of them is holding the role (that half — no slot
-- consumed, no job on the mind — is asserted where the board is
-- visible, in sim/tests/gamemodes.rs).
local mate = t.join()
t.tick()
assert(t.worn(mate).id == "id_engineering", "the next arrival is issued the same kit")
assert(#t.stored(mate, "belt") == 7, "with a belt of its own, stocked")
