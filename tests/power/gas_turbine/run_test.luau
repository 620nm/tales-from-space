-- Running a gas turbine from its console (turbine_computer.dm:85-119): the
-- switch starts a linked line and the three sections turn; heat past the
-- parts' rating behind the compressor wears the rotor (turbine.dm:634-640);
-- a running section's panel stays shut (:169-171) until the switch stops
-- it. No section holds gas yet, so the shaft stays at 0 rpm and 0 W.

local RUN = "lunatic/tfs:turbine_run"

-- The intake pocket behind the compressor is walled off and hotter than
-- tier-one parts are rated for (50000 K, turbine_parts.dm:43-47); the
-- sections stop air (turbine.dm:10), so it stays hot.
t.world([==[(
    name: "turbine hall",
    environment: (gravity_m_s2: Exact(9.80665)),
    legend: {
        '.': (composition: (components: [(component: "station_base")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [
        (
            rows: [
                "########",
                "#......#",
                "##.....#",
                "#......#",
                "##.....#",
                "#......#",
                "########",
            ],
            structures: [
                (4, 2, "player_spawn"),
                (2, 3, "inlet_compressor", "closed", { "dir": "east" }),
                (3, 3, "core_rotor", "closed", { "dir": "east" }),
                (4, 3, "turbine_outlet", "closed", { "dir": "east" }),
            ],
            machines: [(5, 1, "turbine_computer")],
            items: [(4, 1, "multitool"), (3, 1, "screwdriver")],
            painted: [(1, 3, "hot_nitrogen")],
        ),
    ],
    blends: {
        "hot_nitrogen": (rows: [("n2", 40.0)], temperature_k: 60000.0, amount: per_m3),
    },
)]==])

local p = t.join()
t.tick()

local SECTIONS = { { 2, 3 }, { 3, 3 }, { 4, 3 } }

local function record(): { [string]: any }
    local stored = assert(t.structure_at(3, 3)).vars[RUN]
    return if type(stored) == "table" then stored else {}
end

local function all_in(state: string): boolean
    for _, at in ipairs(SECTIONS) do
        if assert(t.structure_at(at[1], at[2])).state ~= state then
            return false
        end
    end
    return true
end

local function click(x: number, y: number, id: string, seconds: number): { string }
    local _ = t.messages(p)
    t.click(p, x, y, t.target_at(p, x, y, id))
    t.run_seconds(seconds)
    return t.messages(p)
end

-- Log the rotor and link the console to it (turbine_computer.dm:24-37).
t.click(p, 4, 1, t.target_at(p, 4, 1, "multitool"))
t.run_ticks(2)
assert(t.hands(p).held == "multitool", "the multitool is in hand")
click(3, 3, "core_rotor", 0.2)
click(5, 1, "turbine_computer", 0.5)

-- The console's window, opened with the free hand; its power switch
-- (`toggle_power`, turbine_computer.dm:89-99).
t.swap_hands(p)
t.run_ticks(1)
click(5, 1, "turbine_computer", 0.2)
t.ui_press(p, "toggle_power")
t.run_ticks(2)
assert(record().active == true, "the switch starts a linked turbine")
assert(all_in("running"), "every section turns")

-- Three passes against 60000 K: each takes round(log90(10000), 0.5) * 0.5
-- = 1 point of damage (turbine.dm:636-637).
t.run_seconds(6.5)
assert((record().damage or 0) > 0, "heat past the rating wears the rotor")
assert(record().rpm == 0 and record().power_w == 0, "no stage holds gas, so nothing turns the shaft")

-- A running section's panel stays shut.
t.click(p, 3, 1, t.target_at(p, 3, 1, "screwdriver"))
t.run_ticks(2)
assert(t.hands(p).held == "screwdriver", "the screwdriver is in hand")
local heard = click(4, 3, "turbine_outlet", 0.2)
assert(table.find(heard, "Stop the turbine before you open its panel.") ~= nil, "the panel is refused")
assert(assert(t.structure_at(4, 3)).state == "running", "and the outlet keeps turning")

-- The switch stops it below 1000 rpm, and the panel opens.
t.ui_press(p, "toggle_power")
t.run_ticks(2)
assert(record().active == false, "the switch stops it")
assert(all_in("closed"), "every section stands still")
click(4, 3, "turbine_outlet", 0.2)
assert(assert(t.structure_at(4, 3)).state == "open", "a stopped section's panel opens")
