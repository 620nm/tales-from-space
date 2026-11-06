-- The core rotor's examine hint (tg `core_rotor/examine`, turbine.dm:438-439):
-- while its line is not linked, a look says it wants a multitool; once the
-- multitool links it, the hint is gone.

local HINT = "Its parts need to be linked with a multitool."

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
            items: [(2, 1, "multitool"), (3, 1, "screwdriver")],
        ),
    ],
)]==])

local p = t.join()
t.tick()

local function pick(x: number, y: number, id: string)
    t.click(p, x, y, t.target_at(p, x, y, id))
    t.run_ticks(2)
    assert(t.hands(p).held == id, "expected " .. id .. " in hand")
end

local function take(id: string)
    if t.hands(p).held ~= id then
        t.swap_hands(p)
        t.run_ticks(1)
    end
    assert(t.hands(p).held == id, "expected " .. id .. " in hand")
end

local function click(x: number, y: number, id: string)
    t.click(p, x, y, t.target_at(p, x, y, id))
    t.run_seconds(0.2)
end

local function hinted(): boolean
    local rotor = t.target_at(p, 3, 3, "core_rotor")
    local look = assert(t.examine(p, 3, 3, rotor), "the rotor answers a look")
    return table.find(look.lines, HINT) ~= nil
end

pick(2, 1, "multitool")
t.swap_hands(p)
pick(3, 1, "screwdriver")

assert(hinted(), "an unlinked rotor asks for a multitool")

-- Shut the outlet and link the line with the multitool.
take("screwdriver")
click(4, 3, "turbine_outlet")
take("multitool")
click(3, 3, "core_rotor")
assert(assert(t.structure_at(3, 3)).vars["lunatic/tfs:turbine_linked"] == true, "the line links")
assert(not hinted(), "a linked rotor gives no hint")
