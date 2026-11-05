-- A running gas turbine outlives the body that threw its switch: each
-- section's turns are a task that body's chain started (the engine's
-- docs/luau-api/runtime.md), and a gibbed body is no transfer, so the rotor
-- keeps checking in and the heat behind its compressor keeps wearing it
-- (turbine.dm:634-640). A transfer off the map has no spec verb; it reads
-- as a stalled run (docs/POWER.md, The gas turbine).

local RUN = "lunatic/tfs:turbine_run"
local CHANNEL = "turbine"

-- The generator feeds the APC, whose socket at (6, 4) cords the console.
-- The intake pocket at (1, 1) is walled off and hotter than tier-one parts
-- are rated for (50000 K, turbine_parts.dm:43-47); the sections stop air
-- (turbine.dm:10), so it stays hot. The tile ahead of the outlet, (5, 1),
-- stays wall, so the shaft never turns and only the wear runs. The player
-- stands in the air beside the rotor and the console.
t.world(
    [==[(
    name: "turbine hall",
    environment: (gravity_m_s2: Exact(9.80665)),
    legend: {
        '.': (composition: (components: [(component: "station_base")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'G': (composition: (components: [(component: "station_base")]), fixture: Some(Generator)),
        'a': (composition: (components: [(component: "station_base")])),
        'o': (composition: (components: [(component: "station_base")]), fixture: Some(Outlet)),
    },
    levels: [
        (
            rows: [
                "#########",
                "#....#..#",
                "##...####",
                "#G......#",
                "#a....o.#",
                "#########",
            ],
            networks: [
                (x: 1, y: 3, network: "power", channel: "l2", kind: "cable", facing: 15),
                (x: 1, y: 4, network: "power", channel: "l2", kind: "cable", facing: 15),
                (x: 1, y: 4, network: "power", channel: "l1", kind: "cable", facing: 15),
                (x: 2, y: 4, network: "power", channel: "l1", kind: "cable", facing: 15),
                (x: 3, y: 4, network: "power", channel: "l1", kind: "cable", facing: 15),
                (x: 4, y: 4, network: "power", channel: "l1", kind: "cable", facing: 15),
                (x: 5, y: 4, network: "power", channel: "l1", kind: "cable", facing: 15),
                (x: 6, y: 4, network: "power", channel: "l1", kind: "cable", facing: 15),
            ],
            structures: [
                (3, 2, "player_spawn"),
                (1, 4, "apc"),
                (2, 1, "inlet_compressor", "closed", { "dir": "east" }),
                (3, 1, "core_rotor", "closed", { "dir": "east" }),
                (4, 1, "turbine_outlet", "closed", { "dir": "east" }),
            ],
            machines: [(4, 3, "turbine_computer")],
            items: [(2, 2, "multitool")],
            painted: [
                (1, 1, "hot_nitrogen"),
                (2, 2, "room_air"), (3, 2, "room_air"), (4, 2, "room_air"), (1, 3, "room_air"),
                (2, 3, "room_air"), (3, 3, "room_air"), (4, 3, "room_air"), (5, 3, "room_air"),
                (6, 3, "room_air"), (7, 3, "room_air"), (1, 4, "room_air"), (2, 4, "room_air"),
                (3, 4, "room_air"), (4, 4, "room_air"), (5, 4, "room_air"), (6, 4, "room_air"),
                (7, 4, "room_air"),
            ],
        ),
    ],
    blends: {
        "hot_nitrogen": (rows: [("n2", 40.0)], temperature_k: 60000.0, amount: per_m3),
        "room_air": (rows: [("n2", 32.9), ("o2", 8.7)], temperature_k: 293.15, amount: per_m3),
    },
)]==],
    0
)

local p = t.join()
t.tick()

local function record(): { [string]: any }
    local stored = assert(t.structure_at(3, 1)).vars[RUN]
    return if type(stored) == "table" then stored :: { [string]: any } else {}
end

local function click(x: number, y: number, id: string, seconds: number): ()
    t.click(p, x, y, t.target_at(p, x, y, id))
    t.run_seconds(seconds)
end

-- Link the console to the rotor, open its window and throw the switch.
click(2, 2, "multitool", 0.2)
assert(t.hands(p).held == "multitool", "the multitool is in hand")
click(3, 1, "core_rotor", 0.2)
click(4, 3, "turbine_computer", 0.5)
t.swap_hands(p)
t.run_ticks(1)
click(4, 3, "turbine_computer", 0.2)
local address = assert(t.ui_document(p, CHANNEL), "the window has an address")
t.ui_press(p, "doc/" .. address.document .. "/" .. address.generation .. "/toggle_power")
t.run_ticks(2)
assert(record().active == true, "the switch starts a linked turbine")

-- One pass of wear, then the body goes; two more passes still wear it.
t.run_seconds(2.4)
local before = record().damage or 0
assert(before > 0, "heat past the rating wears the rotor")
assert(t.staff_gib(p), "the body that threw the switch is gone")
t.run_seconds(4)
assert(record().active == true, "the run outlives its starter")
assert((record().damage or 0) >= before + 2, "and its rotor still takes its turns")
