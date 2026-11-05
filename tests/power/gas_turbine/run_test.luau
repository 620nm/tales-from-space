local ui_controls = require("@helpers/ui_controls")

-- Running a gas turbine from its console (turbine_computer.dm:85-119): the
-- switch starts a linked line and the three sections turn; hot gas behind
-- the compressor wears the rotor (turbine.dm:634-640) and, once the outlet
-- can exhaust (:363-379), spins it and feeds the grid (:672-685); the
-- switch will not stop it above 1000 rpm (turbine_computer.dm:94), and a
-- running section's panel stays shut (turbine.dm:169-171).

local CHANNEL = "turbine"

-- The generator feeds the APC, whose socket at (6, 4) cords the console;
-- the main runs on under the rotor at (3, 1), the bus its watts feed.
-- The intake pocket at (1, 1) is far hotter than tier-one parts are rated
-- for (50000 K, turbine_parts.dm:43-47) and dense enough to stay so: the
-- tile's own floor and walls soak heat (a light 60000 K pocket read 30000 K
-- by the first pass), so it sits on reinforced floor inside reinforced
-- walls, the pack's least-radiant (`content/compositions.luau`), and the
-- sections stop air (turbine.dm:10). The tile ahead of the outlet, (5, 1),
-- starts as wall, sealing off an empty exhaust chamber at (6..7, 1). The
-- player stands in the air beside the rotor and the console.
t.world(
    [==[(
    name: "turbine hall",
    environment: (gravity_m_s2: Exact(9.80665)),
    legend: {
        '.': (composition: (components: [(component: "station_base")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'R': (composition: (components: [(component: "station_base"), (component: "reinforced_wall")])),
        'r': (composition: (components: [(component: "station_base"), (component: "reinforcement")])),
        'G': (composition: (components: [(component: "station_base")]), fixture: Some(Generator)),
        'a': (composition: (components: [(component: "station_base")])),
        'o': (composition: (components: [(component: "station_base")]), fixture: Some(Outlet)),
    },
    levels: [
        (
            rows: [
                "#R#######",
                "Rr...#..#",
                "#R...####",
                "#G......#",
                "#a....o.#",
                "#########",
            ],
            networks: [
                (x: 1, y: 3, network: "power", channel: "l2", kind: "cable", facing: 15),
                (x: 2, y: 3, network: "power", channel: "l2", kind: "cable", facing: 15),
                (x: 3, y: 3, network: "power", channel: "l2", kind: "cable", facing: 15),
                (x: 3, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
                (x: 3, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
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
        "hot_nitrogen": (rows: [("n2", 1000.0)], temperature_k: 300000.0, amount: per_m3),
        "room_air": (rows: [("n2", 32.9), ("o2", 8.7)], temperature_k: 293.15, amount: per_m3),
    },
)]==],
    0
)

local p = t.join()
t.tick()

local SECTIONS = { { 2, 1 }, { 3, 1 }, { 4, 1 } }

-- The console window's readout, as the player sees it.
local function reading(): ui_controls.Record
    local panel = ui_controls.record(assert(t.ui(p, CHANNEL), "the console's window is open"))
    local script = panel.script
    return ui_controls.record(if script then ui_controls.record(script).data else panel.data)
end

local function number(field: string): number
    return ui_controls.number(reading()[field])
end

-- Runs until `holds` answers true, at most `seconds`: the window redraws
-- every 2 s, so a pass shows up to a refresh late.
local function eventually(holds: () -> boolean, seconds: number): boolean
    local waited = 0
    while not holds() do
        if waited >= seconds then
            return false
        end
        t.run_seconds(0.2)
        waited += 0.2
    end
    return true
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
-- The free hand takes the screwdriver now. Loose things on a floor drift with
-- its air, so look for it rather than trust where the map laid it.
local function find_item(id: string): (number, number)
    for x = 1, 7 do
        for y = 1, 4 do
            for _, item in ipairs(t.items_at(x, y)) do
                if item == id then
                    return x, y
                end
            end
        end
    end
    error("no " .. id .. " on the floor")
end
local sx, sy = find_item("screwdriver")
click(sx, sy, "screwdriver", 0.2)
assert(t.hands(p).held == "screwdriver", "the screwdriver is in hand")
press_power()
assert(reading().active == true, "the switch starts a linked turbine")
assert(all_in("running"), "every section turns")

-- The window reads the intake against the parts' rating; the setup holds
-- only while the one is past the other.
local function past_rating(): string
    return string.format(
        "the intake reads %.0f K against a %.0f K rating",
        number("intake_k"),
        number("max_temperature_k")
    )
end
assert(number("intake_k") > number("max_temperature_k"), past_rating())

-- A pass with the exhaust walled: the gas fills the stages but nothing
-- leaves, so nothing turns the shaft (turbine.dm:673-676). Any intake a few
-- kelvin past the rating takes damage (round(log90(dT), 0.5) * 0.5,
-- turbine.dm:636-637), so integrity falls under 100.
local worn = eventually(function()
    return number("integrity") < 100
end, 5)
assert(worn, "heat past the rating wears the rotor: " .. past_rating())
assert(number("rpm") == 0 and number("power_w") == 0, "no exhaust is no rpm and no power")

-- Open the tile ahead of the outlet onto the empty chamber: the next pass
-- ejects and spins. This pocket drives the shaft to the parts' cap, their
-- mean rated 50000 rpm (turbine.dm:682), far past the switch's 1000.
assert(t.set_composition(5, 1, "plating"), "the exhaust opens")
assert(eventually(function()
    return number("rpm") > 1000
end, 6), "hot gas through the stages spins the shaft past 1000 rpm")
assert(number("power_w") == number("rpm") * 4.5, "at rpm * 4.5 W (turbine.dm:684)")
assert(t.ledger_has("MachineSetpoint", "watts"), "set on the rotor feeding the main under it")

-- The switch will not stop a shaft this fast.
local refused = press_power()
assert(
    table.find(refused, "The rotor is spinning too fast to stop safely. Let it slow down first.")
        ~= nil,
    "the stop is refused above 1000 rpm"
)
assert(reading().active == true, "and the turbine runs on")

-- A running section's panel stays shut.
local refusal = "Stop the turbine before you open its panel."
assert(table.find(click(4, 1, "turbine_outlet", 0.2), refusal) ~= nil, "the panel is refused")
assert(assert(t.structure_at(4, 1)).state == "running", "and the outlet keeps turning")

-- The valve throttles the intake to its floor.
local valve = control("/regulate")
t.ui_edit(p, valve, "0.01")
t.ui_press(p, valve, "change")
t.run_ticks(2)
assert(math.abs(number("intake") - 0.01) < 1e-9, "the valve throttles the intake")

-- Wall the exhaust again: nothing leaves, so the next pass turns nothing
-- (turbine.dm:673-676) and the shaft reads under 1000 rpm.
assert(t.set_composition(5, 1, "wall"), "the exhaust shuts")
assert(eventually(function()
    return number("rpm") <= 1000
end, 6), "a shaft with no exhaust stops turning")

-- Now the switch stops it, and the panel opens.
press_power()
assert(reading().active == false, "the switch stops it")
assert(all_in("closed"), "every section stands still")
click(4, 1, "turbine_outlet", 0.2)
assert(assert(t.structure_at(4, 1)).state == "open", "a stopped section's panel opens")
