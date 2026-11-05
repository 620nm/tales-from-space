local ui_controls = require("@helpers/ui_controls")

-- Running a gas turbine from its console (turbine_computer.dm:85-119): the
-- switch starts a linked line and the three sections turn; hot gas behind
-- the compressor wears the rotor (turbine.dm:634-640) and, once the outlet
-- can exhaust (:363-379), spins it and feeds the grid (:672-685); the
-- switch will not stop it above 1000 rpm (turbine_computer.dm:94), and a
-- running section's panel stays shut (turbine.dm:169-171).

local RUN = "lunatic/tfs:turbine_run"
local CHANNEL = "turbine"

-- The generator feeds the APC, whose socket at (6, 4) cords the console.
-- The intake pocket at (1, 1) is walled off and hotter than tier-one parts
-- are rated for (50000 K, turbine_parts.dm:43-47); the sections stop air
-- (turbine.dm:10), so it stays hot. The tile ahead of the outlet, (5, 1),
-- starts as wall, sealing off an empty exhaust chamber at (6..7, 1). The
-- player stands in the air beside the rotor and the console.
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
            items: [(2, 2, "multitool"), (2, 2, "screwdriver")],
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

local SECTIONS = { { 2, 1 }, { 3, 1 }, { 4, 1 } }

local function record(): { [string]: any }
    local stored = assert(t.structure_at(3, 1)).vars[RUN]
    return if type(stored) == "table" then stored :: { [string]: any } else {}
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

local function control(suffix: string): string
    local address = assert(t.ui_document(p, CHANNEL), "the window has an address")
    return "doc/" .. address.document .. "/" .. address.generation .. suffix
end

local function press_power(): { string }
    local _ = t.messages(p)
    t.ui_press(p, control("/toggle_power"))
    t.run_ticks(2)
    return t.messages(p)
end

-- Log the rotor and link the console to it (turbine_computer.dm:24-37).
click(2, 2, "multitool", 0.2)
assert(t.hands(p).held == "multitool", "the multitool is in hand")
click(3, 1, "core_rotor", 0.2)
click(4, 3, "turbine_computer", 0.5)

-- The console's window, opened with the free hand.
t.swap_hands(p)
t.run_ticks(1)
click(4, 3, "turbine_computer", 0.2)
local scope = assert(t.ui_document(p, CHANNEL), "the window has an address")
assert(ui_controls.find(p, "/toggle_power", scope), "the switch is drawn")
press_power()
assert(record().active == true, "the switch starts a linked turbine")
assert(all_in("running"), "every section turns")

-- A pass with the exhaust walled: the gas fills the stages but nothing
-- leaves, so nothing turns the shaft (turbine.dm:673-676). 60000 K takes
-- round(log90(10000), 0.5) * 0.5 = 1 point of damage a pass (:636-637).
t.run_seconds(3)
assert((record().damage or 0) > 0, "heat past the rating wears the rotor")
assert(record().rpm == 0 and record().power_w == 0, "no exhaust is no rpm and no power")

-- Open the tile ahead of the outlet onto the empty chamber: the next pass
-- ejects and spins.
assert(t.set_composition(5, 1, "plating"), "the exhaust opens")
t.run_seconds(2)
local spinning = record()
assert((spinning.rpm or 0) > 1000, "hot gas through the stages spins the shaft past 1000 rpm")
assert(spinning.power_w == spinning.rpm * 4.5, "and feeds the grid rpm * 4.5 W (turbine.dm:684)")
assert(t.ledger_has("MachineSetpoint", "watts"), "the rotor's output is set on the grid")

-- The switch will not stop a shaft this fast.
local refused = press_power()
assert(
    table.find(refused, "The rotor is spinning too fast to stop safely. Let it slow down first.")
        ~= nil,
    "the stop is refused above 1000 rpm"
)
assert(record().active == true, "and the turbine runs on")

-- A running section's panel stays shut.
click(2, 2, "screwdriver", 0.2)
assert(t.hands(p).held == "screwdriver", "the screwdriver is in hand")
local heard = click(4, 1, "turbine_outlet", 0.2)
local refusal = "Stop the turbine before you open its panel."
assert(table.find(heard, refusal) ~= nil, "the panel is refused")
assert(assert(t.structure_at(4, 1)).state == "running", "and the outlet keeps turning")

-- Throttle the intake to its floor: the stages drain and the shaft slows.
local valve = control("/regulate")
t.ui_edit(p, valve, "0.01")
t.ui_press(p, valve, "change")
t.run_ticks(2)
assert(math.abs((record().intake or 0) - 0.01) < 1e-9, "the valve throttles the intake")
local passes = 0
while (record().rpm or 0) > 1000 and passes < 20 do
    t.run_seconds(2)
    passes += 1
end
assert((record().rpm or 0) <= 1000, "a throttled shaft slows under 1000 rpm")

-- Now the switch stops it, and the panel opens.
press_power()
assert(record().active == false, "the switch stops it")
assert(all_in("closed"), "every section stands still")
click(4, 1, "turbine_outlet", 0.2)
assert(assert(t.structure_at(4, 1)).state == "open", "a stopped section's panel opens")
