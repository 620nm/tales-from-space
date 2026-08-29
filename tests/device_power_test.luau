-- Off is off, and dead is dead -- on the three machines you cannot
-- tell either one about by looking at the gas.
--
-- flow_windows_test.luau proves an unpowered gas pump is a length of
-- pipe, room_devices_test.luau proves it of the scrubber and the
-- injector, thermal_devices_test.luau of the temperature pump. Those
-- four are the easy cases: a pump either moves gas or it does not, and
-- a pressure gauge says which.
--
-- These are the ones where "it has stopped" is a harder sentence. A gas
-- filter that has stopped still has gas on all three of its mouths. A
-- gas mixer that has stopped still has a charged outlet. A temperature
-- gate that has stopped is indistinguishable from a temperature gate
-- that has decided, correctly, to pass nothing. So every assertion
-- below is on the MOLE BOOKS of every port at once -- nothing moved,
-- nothing separated, nothing blended, nothing passed -- rather than on
-- a pressure that could be right by accident.
--
-- And every stop is caught MID-JOB. A machine sitting at its setpoint
-- is idle for a reason of its own (flow_devices_test.luau: "it is not
-- broken and it is not off -- it has arrived"), and switching such a
-- machine off would assert nothing at all, so each scenario below
-- records the work the machine still had in front of it at the moment
-- it was stopped.

local ROOM = 1 -- the red line the bench's panel outputs onto
local DISTRO = 4 -- piping layer 3, where a distribution main lives

local function near(a, b, slack, what)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

local function readout(ui, label)
    for _, r in ipairs(ui.readouts) do
        if r.label == label then
            return r.value
        end
    end
    return nil
end

-- The panel's own word on its mains, where the panel has one. The
-- shared flow window carries a `supply` row; the two trinaries do not,
-- because tg's `AtmosFilter.tsx` and `AtmosMixer.tsx` do not either --
-- on those two the sprite is the whole tell, which is why the state
-- assertion beside every one of these is the load-bearing one.
local function panel_says(p, want, what)
    local row = readout(t.ui(p), "supply")
    if row ~= nil then
        assert(row == want, what .. ": " .. row)
    end
end

local function gas(x, y, which)
    local held = t.pipe_gas(x, y)
    return (held and held[which]) or 0.0
end

local function total(x, y)
    local n = 0.0
    for _, amount in pairs(t.pipe_gas(x, y) or {}) do
        n = n + amount
    end
    return n
end

-- Every gas on every one of a machine's mouths, in moles: the reading
-- an engineer would take with an analyser at each port in turn, and the
-- only thing that can tell a stopped trinary from a running one.
local function books(ports)
    local snap = {}
    for i, port in ipairs(ports) do
        snap[i] = {}
        for key, amount in pairs(t.pipe_gas(port[1], port[2]) or {}) do
            snap[i][key] = amount
        end
    end
    return snap
end

local function frozen(ports, snap, what)
    for i, port in ipairs(ports) do
        local at = " at " .. port[1] .. "," .. port[2]
        local now = t.pipe_gas(port[1], port[2]) or {}
        for key, amount in pairs(snap[i]) do
            near(now[key] or 0.0, amount, 1e-9, what .. at .. " (" .. key .. ")")
        end
        for key, amount in pairs(now) do
            assert(
                snap[i][key] ~= nil or amount < 1e-9,
                what .. at .. ": " .. key .. " appeared out of nowhere"
            )
        end
    end
end

local function walk(p, dir)
    t.move(p, dir)
    t.run_ticks(5)
end

-- One bench, three machines. A wired department in miniature: a
-- generator and an APC in the west corner, a backbone pair under them,
-- and a room circuit circuit running east and then up under the machine's own
-- tile -- which is where every powered atmospherics device takes its
-- supply from (tg's AREA_USAGE_EQUIP; sim/powerops.rs hands it off the
-- room circuit under the tile, exactly as it does to a vent).
--
-- (4, 2) is the whole point of the shape: bare plating, no pipe, no
-- structure, and the ONLY length of room circuit between the APC and the
-- machine. An engineer standing on the machine's own service tile is in
-- reach of both it and that length, which is what lets one scenario
-- throw a switch and cut a circuit without walking anywhere.
local BENCH = [==[(
    name: "%s bench",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'g': (turf: Plating, fixture: Some(Generator)),
        'a': (turf: Plating, fixture: Some(Apc)),
    },
    rows: [
        "############",
        "#..........#",
        "#ga........#",
        "############",
    ],
    spawns: [(5, 2)],
    items: [(5, 2, "wirecutters"), (5, 2, "pipe"), (6, 2, "cable_coil")],
    pipes: [%s],
    structures: [(5, 1, "%s")],
    cables: [
        (1, 2, 2, 0, 4), (2, 2, 1, 0, 4), (2, 2, 2, 0, 8),
        (3, 2, 1, 4, 8), (4, 2, 1, 1, 8), (4, 1, 1, 2, 4), (5, 1, 1, 0, 8),
    ],
)]==]

-- A trinary wants a junction: a main running west to east with the
-- machine standing in a gap in it, and a one-length stub dropping south
-- for the third mouth. A binary wants the main and nothing else.
local TEE = "(3, 1, 4), (4, 1, 4), (6, 1, 4), (7, 1, 4), (5, 2, 4)"
local LINE = "(3, 1, 4), (4, 1, 4), (6, 1, 4), (7, 1, 4)"

local IN = { 3, 1 }
local OUT = { 6, 1 }
local SIDE = { 5, 2 }

local function bench(id, pipes, off)
    t.world(BENCH:format(id, pipes, id), 7)
    local p = t.join()
    t.tick()
    t.run_seconds(3) -- the electrical pass is 0.5 Hz; let one land

    assert(t.structure_at(5, 1).id == id, "the map stood a " .. id .. " there")
    assert(t.structure_at(5, 1).state == off, id .. " ships switched off")
    assert(t.apc_at(2, 2).equipment == true, "and the bench's APC is feeding its circuit")
    assert(t.segment_at(5, 1).feed == ROOM, "which reaches the machine's own tile")
    return p
end

-- The panel is opened bare-handed every time: a tool in the working
-- hand is not an interface, it is the tool.
local function open_panel(p, id)
    t.click(p, 5, 1, t.target_at(5, 1, id))
    t.tick()
    assert(t.ui(p), id .. " answers an empty hand with its panel")
end

-- ---------------------------------------------------------------
-- OFF IS A POSITION, NOT A THROTTLE. AND DEAD IS NOT A POSITION AT ALL.
--
-- The two trinaries in turn: configured, switched on, caught working,
-- and then stopped BOTH ways in the same shift. First at the panel,
-- with the room circuit still live -- every mouth stops in the same tick, no
-- coasting, no last pass, no trickle, and each one still had the job in
-- front of it that it was doing. Then the room circuit itself is cut and the
-- switch thrown back on: a dead trinary is equally inert.
--
-- The second half pins a real regression. filter.rs and mixer.rs once
-- opened their pass on `d.on` alone, where the family doctrine is
-- `working()` = on && fed (atmos_machines/mod.rs: "one question, asked
-- in both places") -- so a switched-on filter kept sieving on a
-- completely dead grid while its sprite, which always asked the right
-- question, drew it stopped.
-- ---------------------------------------------------------------
local TRINARIES = {
    {
        id = "gas_filter",
        -- Set to divert oxygen, at a tenth of the dial. The gas is what
        -- makes "it did nothing" a sentence about the SIDE port rather
        -- than about a pressure; the rate is what keeps the input main
        -- from being drained dry before the switch can be thrown, which
        -- would make the stop below a stop with nothing left to stop.
        configure = function(p)
            t.ui_act(p, "set", '{"field":"rate","value":20}')
            t.ui_act(p, "toggle", '{"field":"filter","option":"o2"}')
            t.ui_act(p, "toggle", '{"field":"power"}')
        end,
        moved = function(was)
            assert(
                gas(SIDE[1], SIDE[2], "o2") > was.side_o2 + 1.0,
                "the side port collected oxygen: "
                    .. was.side_o2 .. " -> " .. gas(SIDE[1], SIDE[2], "o2") .. " mol"
            )
            near(
                gas(SIDE[1], SIDE[2], "n2"),
                was.side_n2,
                1e-9,
                "and only oxygen, which is the roster doing its job"
            )
        end,
        unfinished = function()
            assert(
                total(IN[1], IN[2]) > 2.0,
                "it still had a charged input main in front of it: "
                    .. total(IN[1], IN[2]) .. " mol"
            )
        end,
    },
    {
        id = "gas_mixer",
        -- An outlet setpoint well above the atmosphere the outlet main
        -- already holds, and above what the two intakes can reach in the
        -- time given: a mixer AT its target has finished, and finished
        -- is not off.
        configure = function(p)
            t.ui_act(p, "set", '{"field":"pressure","value":250}')
            t.ui_act(p, "toggle", '{"field":"power"}')
        end,
        moved = function(was)
            assert(
                t.pipe_pressure(OUT[1], OUT[2]) > was.out_kpa + 10.0,
                "the outlet main filled: "
                    .. was.out_kpa .. " -> " .. t.pipe_pressure(OUT[1], OUT[2]) .. " kPa"
            )
            assert(
                t.pipe_pressure(SIDE[1], SIDE[2]) < was.side_kpa - 1.0,
                "and both intakes paid for it"
            )
        end,
        unfinished = function()
            assert(
                t.pipe_pressure(OUT[1], OUT[2]) < 240.0,
                "it was still short of its own setpoint, so it stopped"
                    .. " because it was switched off and not because it had"
                    .. " arrived: " .. t.pipe_pressure(OUT[1], OUT[2]) .. " kPa of 250"
            )
        end,
    },
}

for _, job in ipairs(TRINARIES) do
    local p = bench(job.id, TEE, "off")

    open_panel(p, job.id)
    job.configure(p)
    t.run_ticks(2)
    assert(t.ui(p).toggles[1].on == true, "the switch is on")
    assert(t.structure_at(5, 1).state == "running", job.id .. " is running")
    t.ui_close(p)
    t.tick()

    local was = {
        side_o2 = gas(SIDE[1], SIDE[2], "o2"),
        side_n2 = gas(SIDE[1], SIDE[2], "n2"),
        side_kpa = t.pipe_pressure(SIDE[1], SIDE[2]),
        out_kpa = t.pipe_pressure(OUT[1], OUT[2]),
    }
    t.run_seconds(10)
    job.moved(was)

    -- ...and stop it.
    open_panel(p, job.id)
    t.ui_act(p, "toggle", '{"field":"power"}')
    t.run_ticks(2)
    assert(t.structure_at(5, 1).state == "off", job.id .. " is switched off")
    assert(
        t.apc_at(2, 2).equipment == true,
        "with the APC still feeding it, which is the whole point: this one"
            .. " stopped because of the switch and nothing else"
    )
    t.ui_close(p)
    t.tick()

    job.unfinished()
    local switched = books({ IN, OUT, SIDE })
    t.run_seconds(30)
    frozen({ IN, OUT, SIDE }, switched, "a switched-off " .. job.id .. " moved nothing")

    -- ...and now the other stop. Cut the one length of circuit between
    -- the APC and the machine, throw the switch back on, and ask the
    -- books the same question: a switch thrown over a dead circuit is a
    -- promise, not a machine.
    t.click(p, 5, 2, t.target_at(5, 2, "wirecutters"))
    t.run_ticks(2)
    assert(t.hands(p).held == "wirecutters", "cutters in hand")
    t.click_subfloor(p, 4, 2, "cable", ROOM, 1, 8)
    t.run_seconds(1.5)
    assert(t.cable_at(4, 2) == 0, "the room circuit is parted")
    t.drop(p)
    t.run_seconds(3)
    assert(
        t.segment_at(5, 1).feed == nil,
        "nothing on the machine's side of the cut reaches an APC"
    )

    open_panel(p, job.id)
    t.ui_act(p, "toggle", '{"field":"power"}')
    t.run_ticks(2)
    assert(t.ui(p).toggles[1].on == true, "the switch is thrown all the same")
    assert(
        t.structure_at(5, 1).state == "off",
        job.id .. " is drawn stopped -- the picture asks `working()`,"
            .. " and the gas below must ask the same question"
    )
    t.ui_close(p)
    t.tick()

    job.unfinished()
    local dead = books({ IN, OUT, SIDE })
    t.run_seconds(30)
    frozen({ IN, OUT, SIDE }, dead, "a dead " .. job.id .. " moved nothing either")
end

-- ---------------------------------------------------------------
-- THE GATE, AND THE THREE STATES IT CANNOT TELL APART BY ITSELF.
--
-- A temperature gate is a RELEASE machine rather than a pump
-- (temperature_gate.dm:76 hands off to `release_gas_to`), so what it
-- needs before it can be caught doing anything is not a setpoint but a
-- GRADIENT: both its mains open the shift commissioned at one
-- atmosphere, and a gate between two mains of the same molar density
-- has nothing to let down however it is dialled.
--
-- A length of main laid during the shift is that gradient. A run
-- somebody lays by hand starts EMPTY (fittings_test.luau), so bolting
-- one onto the delivery side dilutes it below the supply -- and now the
-- same machine, unchanged, has a job. That is the work each of the
-- three states below is measured against, which also makes this the
-- only one of the three machines whose panel says the answer out loud:
-- a gate wears the shared flow window, and that window has a `supply`
-- row on it.
-- ---------------------------------------------------------------
local GATE = "temperature_gate"
local p = bench(GATE, LINE, "shut")

-- Prime the delivery side, and check the head is real: tg will not open
-- a release valve across less than ten kPa (release.rs, "friction in
-- the mechanism"), so anything under that would be a gate that is
-- allowed to sit still.
t.click(p, 5, 2, t.target_at(5, 2, "pipe"))
t.run_ticks(2)
assert(t.hands(p).held == "pipe", "a coil of pipe in hand")
t.click(p, 6, 2)
t.run_seconds(1.5)
assert(t.pipe(6, 2) == DISTRO, "a fresh length went onto the delivery main")

local function head()
    return t.pipe_pressure(IN[1], IN[2]) - t.pipe_pressure(OUT[1], OUT[2])
end

local function has_work(what)
    assert(
        head() > 10.0,
        what .. ": " .. t.pipe_pressure(IN[1], IN[2])
            .. " / " .. t.pipe_pressure(OUT[1], OUT[2]) .. " kPa"
    )
end

has_work("the diluted delivery main is a real job, over the friction floor")

-- Park the coil in the idle hand; a panel wants an empty one.
t.swap_hands(p)
t.run_ticks(2)

-- ---- ONE: configured, switched on, and on a dead room circuit ----
--
-- The circuit is cut with wirecutters on the one length of room circuit
-- between the APC and the machine -- a thing a player does rather than
-- a thing the harness does, because `t` exposes the power grid to READ
-- and leaves the mutation to a tool in somebody's hands (spec/api/
-- power.rs).
t.click(p, 5, 2, t.target_at(5, 2, "wirecutters"))
t.run_ticks(2)
assert(t.hands(p).held == "wirecutters", "cutters in hand")
t.click_subfloor(p, 4, 2, "cable", ROOM, 1, 8)
t.run_seconds(1.5)
assert(t.cable_at(4, 2) == 0, "the room circuit is parted")
assert(t.ledger_has("CableCut"), "and cutting a department's feed is attributable")
t.drop(p)
t.run_seconds(3)
assert(
    t.segment_at(5, 1).feed == nil,
    "nothing on this side of the cut reaches an APC any more"
)

-- The machine takes its orders perfectly happily while dead. A dead
-- machine is not a broken one, and its panel is fed by nothing but the
-- click that opened it.
open_panel(p, GATE)
panel_says(p, "dead", "the gate's panel says the mains are not behind it")
t.ui_act(p, "set", '{"field":"temperature","value":500}')
t.ui_act(p, "toggle", '{"field":"power"}')
t.run_ticks(2)
assert(t.ui(p).toggles[1].on == true, "the switch is on all the same")
near(t.ui(p).setpoints[1].value, 500.0, 0.01, "and the dial took the setting")
assert(
    t.structure_at(5, 1).state == "shut",
    "but it is still drawn shut, which is tg's `on && is_operational`"
        .. " picking the picture rather than the switch alone"
)
t.ui_close(p)
t.tick()

local dead = books({ IN, OUT })
t.run_seconds(30)
frozen({ IN, OUT }, dead, "an unpowered temperature gate passed nothing")
has_work("and the job is still sitting there untouched")

-- ---- TWO: the power comes back, and nobody tells it twice ----
--
-- The parted length back down, and that is all: the panel is not
-- reopened, the switch is not thrown again, and the 500 K setting is
-- never re-entered. What the machine was told while it was dead is what
-- it does the moment it wakes.
local was = { out_kpa = t.pipe_pressure(OUT[1], OUT[2]), in_kpa = t.pipe_pressure(IN[1], IN[2]) }

t.click(p, 6, 2, t.target_at(6, 2, "cable_coil"))
t.run_ticks(2)
assert(t.hands(p).held == "cable_coil", "a fresh coil in hand")
-- A fresh coil arrives on yellow (tg's CABLE_LAYER_2 default) and this
-- bench runs on red, so dial it twice: yellow -> blue -> red.
t.use_self(p)
t.run_ticks(2)
t.use_self(p)
t.run_ticks(2)
-- Two knots rebuild what one length used to be: the parted tile needs an
-- end reaching west at the APC's side and an end reaching north at the
-- machine's own stub, and a pair of knots meeting at the tile's centre
-- is exactly that (docs/POWER.md). On your own tile `place_turf` runs
-- the piece the way you FACE; from a neighbouring tile it runs back at
-- you.
walk(p, "west")
t.click(p, 4, 2)
t.run_seconds(1.5)
walk(p, "north")
t.click(p, 4, 2)
t.run_seconds(1.5)
assert(
    t.cable_at(4, 2) == ROOM,
    "and the coil lays the red line, which is the one this APC feeds"
)
t.drop(p)
walk(p, "south")
walk(p, "east")
t.run_seconds(3)
assert(t.segment_at(5, 1).feed == ROOM, "the machine is back on an APC")
assert(
    t.structure_at(5, 1).state == "armed",
    "and it armed ITSELF: " .. t.structure_at(5, 1).state
)

t.run_seconds(10)
assert(
    t.pipe_pressure(OUT[1], OUT[2]) > was.out_kpa + 5.0,
    "the delivery main took gas the moment the power came back: "
        .. was.out_kpa .. " -> " .. t.pipe_pressure(OUT[1], OUT[2]) .. " kPa"
)
assert(t.pipe_pressure(IN[1], IN[2]) < was.in_kpa, "and the supply is what paid for it")
near(
    t.pipe_pressure(IN[1], IN[2]),
    t.pipe_pressure(OUT[1], OUT[2]),
    1.0,
    "the two mains came level, which is where a release machine stops"
)

-- ---- THREE: switched off, with the mains right there ----
--
-- Switch it off first, THEN hand it the same job again: another fresh
-- length onto the delivery main. A gate that was merely slow would take
-- this one too, a few seconds later.
open_panel(p, GATE)
panel_says(p, "fed", "the mains are behind it again")
t.ui_act(p, "toggle", '{"field":"power"}')
t.run_ticks(2)
assert(t.structure_at(5, 1).state == "shut", "the gate is shut")
assert(t.apc_at(2, 2).equipment == true, "with the APC feeding it the whole time")
t.ui_close(p)
t.tick()

walk(p, "east")
t.swap_hands(p)
t.run_ticks(2)
assert(t.hands(p).held == "pipe", "the coil of pipe is where it was parked")
t.click(p, 7, 2)
t.run_seconds(1.5)
assert(t.pipe(7, 2) == DISTRO, "a second fresh length onto the delivery main")
has_work("which is a second real job, over the friction floor again")

local switched = books({ IN, OUT })
t.run_seconds(30)
frozen({ IN, OUT }, switched, "a switched-off temperature gate passed nothing either")
has_work("and it is still sitting there: off is off, not slow")
