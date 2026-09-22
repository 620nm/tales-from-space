-- The panel's ladder: how a cell running down takes a room apart, one
-- load class at a time, and the alarm that goes up with the first shed.
--
-- The engine hands the panel its charge every electrical pass and knows
-- nothing else; which classes a cell at that charge keeps is
-- content/fixtures/apc.luau, tg's autoset (apc_main.dm:636-664):
-- equipment goes below 30%, lighting below 15%, and the room's air only
-- when the cell is EMPTY. The alarm goes up with the first shed and
-- comes down only above 75% (apc_main.dm:15, :672-673), so a panel
-- recharging through the middle of its cell keeps calling it.
--
-- The second half is what "the air goes last" means on the floor. A
-- panel at a tenth of its cell with the mains gone still delivers its
-- `environment` class, so the doors and the room's socket stay live
-- while the corded machine on that socket and the fitting over it
-- lose theirs -- and only the empty cell kills the circuit.

local function near(got: number, want: number, tol: number, why: string)
    assert(math.abs(got - want) <= tol, why .. ": " .. got .. " vs " .. want)
end

-- The electrical pass runs on every multiple of this many ticks (0.5 Hz,
-- the engine's docs/power/pass.md). `pass()` runs through the next one
-- and one tick past it, by when its handlers have thrown their gates.
local POWER_EVERY = 40
local function pass()
    t.run_ticks(POWER_EVERY - t.now() % POWER_EVERY + 1)
end

local CLASSES = { "equipment", "lighting", "environment" }
local ALARM = "lunatic/tfs:power_alarm"
local EMERGENCY_RED = "#FF3232"
local DARK = "The transceiver is dark. Check what is feeding it."

-- One room behind a panel: the panel takes the backbone off the
-- generator (L2) and feeds the room circuit (L1), flagged for its
-- reserve as commissioned room circuits flag it. On the circuit: a socket,
-- a corded transceiver and a fitting in cord reach of it, and an
-- airlock fed straight off the cable under its own tile. `%s` is the
-- generator's glyph -- `.` is a room whose mains are already gone.
local BENCH = [==[(
    name: "shed ladder",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'G': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Generator)),
        'o': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Outlet)),
        'l': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Light)),
        'E': (composition: (components: [(component: "station_base")]), fixture: Some(Door)),
    },
    rows: [
        "###########",
        "#%s......#.#",
        "#...o.l.E.#",
        "#.......#.#",
        "###########",
    ],
    structures: [(5, 2, "player_spawn"), (2, 1, "apc", { "l1_reserve": true })],
    machines: [(5, 1, "transceiver")],
    networks: [
        (x: 1, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 2, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 2, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 3, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 4, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 5, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 6, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 7, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 8, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
    ],
    labels: [(2, 1, "Engineering")],
)]==]

local function gates(): { [string]: boolean }
    return assert(assert(t.store_at(2, 1)).gates)
end

local function delivering(): { [string]: boolean }
    return assert(assert(t.store_at(2, 1)).delivering)
end

local function alarmed(): boolean
    return assert(t.structure_at(2, 1)).vars[ALARM] == true
end

-- What the panel's gates say, class by class, against what the ladder
-- should have left them at.
local function expect(want: { [string]: boolean }, why: string)
    local got, live = gates(), delivering()
    for _, class in ipairs(CLASSES) do
        assert(got[class] == want[class], why .. ": the " .. class .. " gate is " .. tostring(got[class]))
        assert(live[class] == want[class], why .. ": " .. class .. " delivered is " .. tostring(live[class]))
    end
end

-- ---------------------------------------------------------------
-- 1. THE LADDER, mains up. A harness write sets the cell; the panel's
--    next report is all the ladder needs, and its gates follow on the
--    same pass.
-- ---------------------------------------------------------------
t.world(BENCH:format("G"), 7)
local p = t.join()
t.tick()
pass()
expect({ equipment = true, lighting = true, environment = true }, "a full panel sheds nothing")
assert(not alarmed(), "and calls no alarm")

t.set_store_charge(2, 1, 0.25)
pass()
expect({ equipment = false, lighting = true, environment = true }, "below 30% equipment goes")
assert(alarmed(), "and the alarm goes up with it")

t.set_store_charge(2, 1, 0.10)
pass()
expect({ equipment = false, lighting = false, environment = true }, "below 15% lighting goes too")
assert(alarmed(), "the alarm stays up")

-- Back up through the middle of the cell: every class is delivered
-- again, but the alarm is still calling -- it clears only above 75%.
t.set_store_charge(2, 1, 0.50)
pass()
expect({ equipment = true, lighting = true, environment = true }, "at half a cell the room is whole")
assert(alarmed(), "and the alarm is STILL up at 50%: it clears above 75")

t.set_store_charge(2, 1, 0.80)
pass()
expect({ equipment = true, lighting = true, environment = true }, "a charged panel sheds nothing")
assert(not alarmed(), "and above 75% the alarm clears")

-- Every throw is the ladder's, on the record under the script that
-- threw it: equipment off, lighting off, then both back on.
local thrown = t.ledger_rows("DeliveryGateSet")
assert(#thrown == 4, "four gate throws, one per class that moved: " .. #thrown)
local want_rows = {
    { class = "equipment", on = false },
    { class = "lighting", on = false },
    { class = "equipment", on = true },
    { class = "lighting", on = true },
}
for index, row in ipairs(thrown) do
    local want = want_rows[index]
    assert(row.class == want.class and row.on == want.on, "throw " .. index .. " is " .. tostring(row.class))
    assert(row.actor.kind == "script", "the ladder threw it, not a crewman: " .. row.actor.kind)
end

-- ---------------------------------------------------------------
-- 2. THE AIR GOES LAST. The same room with no generator: the panel is
--    on its cell from the first pass, feeding its flagged room circuit.
-- ---------------------------------------------------------------
t.world(BENCH:format("."), 7)
p = t.join()
t.tick()
pass()
pass()

local function transceiver_said(): { string }
    local _ = t.messages(p)
    t.click(p, 5, 1, t.target_at(p, 5, 1))
    t.tick()
    local said = t.messages(p)
    t.ui_close(p)
    t.tick()
    return said
end

local function says(lines: { string }, line: string): boolean
    for _, said in ipairs(lines) do
        if said == line then
            return true
        end
    end
    return false
end

local store = assert(t.store_at(2, 1))
assert(store.on_reserve and not store.fed, "the panel runs the room off its own cell")
local socket = assert(t.outlet_at(4, 2))
assert(socket.powered and socket.channels["l1"] == "emergency", "the flagged circuit carries off the reserve")
local woke = transceiver_said()
assert(#woke > 0 and not says(woke, DARK), "the transceiver on the socket is powered: " .. table.concat(woke, " | "))
local TUBE = assert(t.light_at(6, 2)).color
assert(TUBE ~= EMERGENCY_RED, "the fitting burns its own tube off the grid")
assert(assert(t.door_at(8, 2)).powered, "and the airlock has its motors")

-- A tenth of a cell: equipment and lighting shed, the room's air kept.
t.set_store_charge(2, 1, 0.10)
pass()
expect({ equipment = false, lighting = false, environment = true }, "a tenth of a cell keeps the air")
pass()

socket = assert(t.outlet_at(4, 2))
assert(socket.powered, "the socket is still live: its circuit still carries the air")
assert(socket.channels["l1"] == "emergency", "and still off the reserve: " .. socket.channels["l1"])
assert(says(transceiver_said(), DARK), "the corded machine on it is dark: equipment is shed")
local fitting = assert(t.light_at(6, 2))
assert(fitting.lit and fitting.color == EMERGENCY_RED, "the fitting is on its own cell: " .. fitting.color)
assert(assert(t.door_at(8, 2)).powered, "the airlock is still powered: the air goes last")
assert(#t.ledger_rows("SegmentDeenergized") == 0, "and nothing on the circuit has gone dark")

-- The empty cell: every gate goes, and the circuit with it -- one pass.
t.set_store_charge(2, 1, 0)
pass()
expect({ equipment = false, lighting = false, environment = false }, "an empty cell delivers nothing")
near(assert(t.store_at(2, 1)).charge_j, 0.0, 1e-9, "the cell is flat")
assert(not assert(t.door_at(8, 2)).powered, "the airlock has lost its motors")
assert(not assert(t.outlet_at(4, 2)).powered, "the socket is dead")
assert(#t.ledger_rows("SegmentDeenergized") > 0, "and the circuit going dark is on the record")
