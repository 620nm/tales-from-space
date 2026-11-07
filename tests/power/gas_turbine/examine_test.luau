-- The core rotor's examine hint (tg `core_rotor/examine`, turbine.dm:438-439):
-- while its line is not linked, a look says so; once a bare-hand check at
-- the rotor links it, the hint is gone.

local HINT = "Its parts are not linked into one line yet."

t.world([==[(
    name: "turbine examine",
    environment: (gravity_m_s2: Exact(9.80665)),
    legend: {
        '.': (composition: (components: [(component: "station_base")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [
        (
            rows: [
                "######",
                "#....#",
                "#....#",
                "#....#",
                "######",
            ],
            structures: [
                (3, 2, "player_spawn"),
                (2, 3, "inlet_compressor", "closed", { "dir": "east" }),
                (3, 3, "core_rotor", "closed", { "dir": "east" }),
                (4, 3, "turbine_outlet", "open", { "dir": "east" }),
            ],
            items: [(3, 1, "screwdriver")],
        ),
    ],
)]==])

local p = t.join()
t.tick()

local function click(x: number, y: number, id: string)
    t.click(p, x, y, assert(t.target_at(p, x, y, id)))
    t.run_seconds(0.2)
end

local function hinted(): boolean
    local rotor = t.target_at(p, 3, 3, "core_rotor")
    local look = assert(t.examine(p, 3, 3, rotor), "the rotor answers a look")
    return table.find(look.lines, HINT) ~= nil
end

assert(hinted(), "an unlinked rotor says its line is not linked")

-- Shut the outlet with the screwdriver, then check the line bare-handed.
t.click(p, 3, 1, assert(t.target_at(p, 3, 1, "screwdriver")))
t.run_ticks(2)
assert(t.hands(p).held == "screwdriver", "the screwdriver in hand")
click(4, 3, "turbine_outlet")
t.swap_hands(p)
t.run_ticks(1)
assert(t.hands(p).held == nil, "a bare hand for the check")
click(3, 3, "core_rotor")
assert(assert(t.structure_at(3, 3)).vars["lunatic/tfs:turbine_linked"] == true, "the line links")
assert(not hinted(), "a linked rotor gives no hint")
