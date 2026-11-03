-- A server started without `--playtest` installs no map: the pack answers
-- `round.bootstrap` by instantiating the host's map and begins the round on
-- it (content/lib/map_boot.luau). `t.bootstrap_world` boots that way, so a
-- body that stands in the host map's room proves the whole chain ran:
-- bootstrap, the install settling Ready, and the begin.
t.bootstrap_world({ host_map = "cold_outpost.ron", mode = "free_build", seed = 7 })

local installs = t.ledger_rows("map_instance_installing")
assert(#installs == 1, "the host map installs once, got " .. #installs)
assert(#t.ledger_rows("lunatic/tfs:map_boot_failed") == 0, "no boot refusal is ledgered")

-- Free Build seats a body on connection, at the map's marker, in the
-- engineer's kit its mode issues (rounds/free_build_test.luau).
local builder = t.join()
t.tick()
local worn = t.worn(builder)
assert(
    worn.uniform == "uniform_eng",
    "the round began on the host map, got " .. tostring(worn.uniform)
)

-- Two instances on two planes at a nonzero origin: the join instance on
-- plane 1 at (100, 40) binds `lunatic/tfs:cold_outpost` while a twin
-- stands on plane 0.
t.world_file("cold_outpost.ron", 7, "free_build", {
    key = "lunatic/tfs:cold_outpost",
    plane = 1,
    origin = { x = 100, y = 40 },
    twin_plane = true,
})
local twin_installs = t.ledger_rows("map_instance_installing")
assert(#twin_installs == 2, "two instances install on two planes, got " .. #twin_installs)
local p = t.join()
t.tick()
local bx, by = t.pos(p)
assert(bx >= 100 and by >= 40, "the builder stands at the nonzero origin on plane 1: (" .. bx .. ", " .. by .. ")")

-- Cross two instances both ways through a tagged-area seam and land on a
-- named level (level 1 on the east instance, back to level 0 on the west).
local map_west = [==[(
    name: "seam west",
    legend: {
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
    },
    levels: [(
        tagged_areas: [
            (bounds: (min: (x: 2, y: 1), max: (x: 2, y: 1)), tags: ["seam_landing_east"]),
            (bounds: (min: (x: 3, y: 1), max: (x: 3, y: 1)), tags: ["seam_east"]),
        ],
        rows: [
            "#####",
            "#...#",
            "#####",
        ],
        structures: [(1, 1, "player_spawn")],
    )],
)]==]
local map_east = [==[(
    name: "seam east",
    legend: {
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
    },
    levels: [
        (
            rows: [
                "#####",
                "#...#",
                "#####",
            ],
        ),
        (
            tagged_areas: [
                (bounds: (min: (x: 1, y: 1), max: (x: 1, y: 1)), tags: ["seam_landing_west"]),
                (bounds: (min: (x: 2, y: 1), max: (x: 2, y: 1)), tags: ["seam_west"]),
            ],
            rows: [
                "#####",
                "#...#",
                "#####",
            ],
        ),
    ],
)]==]
t.world(map_west, 7, "free_build", {
    key = "lunatic/tfs:seam_west",
    second_map = {
        source = map_east,
        key = "lunatic/tfs:seam_east",
        plane = 1,
    },
})
local traveler = t.join()
t.tick()
local tx, ty = t.pos(traveler)
assert(tx == 1 and ty == 1, "traveler starts at (1, 1) on seam_west")
t.move(traveler, "east")
t.run_seconds(0.5)
t.move(traveler, "east")
t.run_seconds(0.5)
local transfers = t.ledger_rows("entity_transferred")
assert(#transfers == 1, "stepping into seam_east transfers the traveler once, got " .. #transfers)
local first_to = (transfers[1] :: any).to :: { number }
assert(
    first_to[1] == 1 and first_to[2] == 1 and first_to[3] == 1 and first_to[4] == 1,
    "traveler lands on (1, 1) level 1 of plane 1"
)
t.move(traveler, "east")
t.run_seconds(0.5)
transfers = t.ledger_rows("entity_transferred")
assert(#transfers == 2, "stepping into seam_west on level 1 transfers back, got " .. #transfers)
local second_to = (transfers[2] :: any).to :: { number }
assert(
    second_to[1] == 2 and second_to[2] == 1 and second_to[3] == 0 and second_to[4] == 0,
    "traveler lands back on (2, 1) level 0 of plane 0"
)

-- A fall onto a seam crosses too. A fall runs no `move.cross`, so the seam
-- answers the body's landing (`motion.land.done`): the traveler walks onto a
-- hole on level 1 whose cell below carries `seam_east`, and the pack's `{}`
-- answer keeps the engine's guess, which drops it there.
local map_drop = [==[(
    name: "seam drop",
    tags: ["terrestrial"],
    environment: (kind: Exact(terrestrial), gravity_m_s2: Exact(9.80665)),
    legend: {
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        'o': (composition: (substrate: Open)),
    },
    levels: [
        (
            tagged_areas: [
                (bounds: (min: (x: 2, y: 1), max: (x: 2, y: 1)), tags: ["seam_east"]),
            ],
            rows: [
                "#####",
                "#...#",
                "#####",
            ],
        ),
        (
            rows: [
                "#####",
                "#.o.#",
                "#####",
            ],
            structures: [(1, 1, "player_spawn")],
        ),
    ],
)]==]
t.world(map_drop, 7, "free_build", {
    key = "lunatic/tfs:seam_west",
    second_map = {
        source = map_east,
        key = "lunatic/tfs:seam_east",
        plane = 1,
    },
})
local before = #t.ledger_rows("entity_transferred")
local diver = t.join()
t.tick()
t.move(diver, "east")
t.run_seconds(3)
local falls = t.ledger_rows("level_changed")
assert(#falls >= 1 and falls[#falls].via == "fall", "the diver fell through the hole")
transfers = t.ledger_rows("entity_transferred")
assert(#transfers == before + 1, "landing on seam_east transfers the diver once, got " .. #transfers - before)
local drop_to = (transfers[#transfers] :: any).to :: { number }
assert(
    drop_to[1] == 1 and drop_to[2] == 1 and drop_to[3] == 1 and drop_to[4] == 1,
    "the diver lands on (1, 1) level 1 of plane 1"
)
