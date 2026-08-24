-- The gas mixer: the filter run backwards.
--
-- Two intakes -- the back port and the side one -- drawn from at a set
-- ratio and merged into one outlet, until that outlet reads the target
-- and not a kPa past it. Every tg map has one of these feeding the
-- distribution loop with nitrogen on one intake and oxygen on the
-- other, which is where a station's air comes from.
--
-- The ratio is by MOLES, so this spec counts moles rather than reading
-- pressures: at 50/50 the two intakes must give up exactly the same
-- amount, at 80/20 exactly four times as much, and at 100/0 the idle
-- side must not lose a single mole. The last section is the one that
-- matters most in a real atmos loop -- a supply line that has run dry
-- must STOP the machine rather than let it pour the other gas neat into
-- the distribution main.
--
-- One junction serves the whole file: a long back main, a one-length
-- stub dropping south as the side intake, and a short outlet main east.
-- The engine aims the machine east, the only facing whose three mouths
-- all have run to reach.

local PIPE_M3 = 0.070
local PORT_M3 = 0.200
-- tg widens a mixer's OUTLET to 300 L in Initialize (mixer.dm:22-24) --
-- the one port in the whole kit that is not 200.
local OUTLET_M3 = 0.300

local function near(a, b, slack, what)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

-- Everything standing in the run under a tile, in moles.
local function moles(x, y)
    local held = t.pipe_gas(x, y)
    if not held then
        return 0.0
    end
    local n = 0.0
    for _, amount in pairs(held) do
        n = n + amount
    end
    return n
end

local BACK_X, BACK_Y = 4, 1
local SIDE_X, SIDE_Y = 9, 2
local OUT_X, OUT_Y = 11, 1

t.world([==[(
    name: "gas mixer",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'a': (turf: Plating, fixture: Some(Apc)),
        'g': (turf: Plating, fixture: Some(Generator)),
    },
    rows: [
        "##############",
        "#............#",
        "#........a..g#",
        "##############",
    ],
    spawns: [(9, 2)],
    pipes: [
        (1, 1, 4), (2, 1, 4), (3, 1, 4), (4, 1, 4),
        (5, 1, 4), (6, 1, 4), (7, 1, 4), (8, 1, 4),
        (10, 1, 4), (11, 1, 4), (12, 1, 4),
        (9, 2, 4),
    ],
    structures: [(9, 1, "gas_mixer")],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3), (4, 1, 3), (5, 1, 3), (6, 1, 3), (7, 1, 3), (8, 1, 3), (9, 1, 3), (10, 1, 3), (11, 1, 3), (12, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3), (4, 2, 3), (5, 2, 3), (6, 2, 3), (7, 2, 3), (8, 2, 3), (9, 2, 3), (10, 2, 3), (11, 2, 3), (12, 2, 3),
    ],
)]==], 7)

local p = t.join()
t.tick()

local m = t.structure_at(9, 1)
assert(m ~= nil and m.id == "gas_mixer", "the mixer is where the map put it")
assert(m.state == "off", "and it ships off")
assert(t.pipe_pressure(9, 1) == nil, "the run does not pass through it")

-- ---------------------------------------------------------------
-- THE 300 L OUTLET, PROVED BY WHAT IT HOLDS.
--
-- Three nets commissioned at one pressure hold gas in proportion to
-- their VOLUME, so the outlet's mouth can be weighed against the side
-- intake's. Three lengths plus 300 L against one length plus 200 L is
-- 1.89; had the engine given the outlet an ordinary 200 L mouth it
-- would read 1.52, which is not a rounding error away.
-- ---------------------------------------------------------------
local BACK_M3 = 8 * PIPE_M3 + PORT_M3
local SIDE_M3 = 1 * PIPE_M3 + PORT_M3
local OUT_M3 = 3 * PIPE_M3 + OUTLET_M3
near(
    moles(OUT_X, OUT_Y) / moles(SIDE_X, SIDE_Y),
    OUT_M3 / SIDE_M3,
    0.02,
    "the mixer's outlet is 300 L, not 200"
)
near(
    moles(BACK_X, BACK_Y) / moles(SIDE_X, SIDE_Y),
    BACK_M3 / SIDE_M3,
    0.02,
    "and the two intakes are ordinary 200 L mouths"
)

local books = moles(BACK_X, BACK_Y) + moles(SIDE_X, SIDE_Y) + moles(OUT_X, OUT_Y)

-- An idle mixer is a length of pipe.
t.run_seconds(10)
near(moles(OUT_X, OUT_Y) / moles(SIDE_X, SIDE_Y), OUT_M3 / SIDE_M3, 0.02, "an off mixer moves nothing")

-- ---------------------------------------------------------------
-- The panel.
-- ---------------------------------------------------------------
t.click(p, 9, 1, t.target_at(9, 1, "gas_mixer"))
t.tick()
local ui = t.ui(p)
assert(ui, "clicking a gas mixer opens its window")
assert(ui.document == "modules" and ui.presentation == "modules")
assert(ui.toggles[1].field == "power" and ui.toggles[1].on == false)
assert(#ui.toggles == 1, "a mixer has one switch and no roster")

assert(ui.setpoints[1].field == "pressure", "the output setpoint")
near(ui.setpoints[1].value, 101.325, 0.001, "at tg's ONE_ATMOSPHERE")
near(ui.setpoints[1].max, 4500.0, 0.001, "up to MAX_OUTPUT_PRESSURE")
assert(ui.setpoints[2].field == "ratio", "and the split")
near(ui.setpoints[2].value, 50.0, 0.001, "half and half out of the box")

-- One number, two views: tg keeps two boxes that must sum to 100, and
-- the second one is a readout here because nobody should have to
-- subtract to read their own machine.
local mix = nil
for _, r in ipairs(ui.readouts) do
    if r.label == "mix" then
        mix = r.value
    end
end
assert(mix == "50% back / 50% side", "the panel says both shares: " .. tostring(mix))

-- ---------------------------------------------------------------
-- FIFTY-FIFTY: THE TWO INTAKES PAY EQUALLY, AND IT STOPS AT TARGET.
-- ---------------------------------------------------------------
local back0, side0 = moles(BACK_X, BACK_Y), moles(SIDE_X, SIDE_Y)
t.ui_act(p, "set", '{"field":"pressure","value":150}')
t.ui_act(p, "toggle", '{"field":"power"}')
t.tick()
assert(t.structure_at(9, 1).state == "running", "switched on")

t.run_seconds(20)
local gave_back = back0 - moles(BACK_X, BACK_Y)
local gave_side = side0 - moles(SIDE_X, SIDE_Y)
assert(gave_back > 1.0, "the back intake paid: " .. gave_back)
near(gave_back, gave_side, 0.02, "and the side paid exactly as much")
near(t.pipe_pressure(OUT_X, OUT_Y), 150.0, 1.0, "the outlet came up to the setpoint")

-- ...and stopped there. tg's `output_starting_pressure >= target_pressure`
-- ends the pass before a mole is drawn (mixer.dm:80-82).
local held_back = moles(BACK_X, BACK_Y)
t.run_seconds(20)
near(moles(BACK_X, BACK_Y), held_back, 1e-6, "a mixer at its setpoint draws nothing more")
assert(t.pipe_pressure(OUT_X, OUT_Y) < 151.0, "and never one kPa past it")

near(
    moles(BACK_X, BACK_Y) + moles(SIDE_X, SIDE_Y) + moles(OUT_X, OUT_Y),
    books,
    1e-6,
    "and every mole is accounted for"
)

-- ---------------------------------------------------------------
-- FOUR TO ONE. The ratio is the BACK intake's share; the side supplies
-- the rest, and the two move together.
-- ---------------------------------------------------------------
back0, side0 = moles(BACK_X, BACK_Y), moles(SIDE_X, SIDE_Y)
t.ui_act(p, "set", '{"field":"ratio","value":80}')
t.ui_act(p, "set", '{"field":"pressure","value":200}')
t.tick()
local said_mix = nil
for _, r in ipairs(t.ui(p).readouts) do
    if r.label == "mix" then
        said_mix = r.value
    end
end
assert(said_mix == "80% back / 20% side", "the other share follows: " .. tostring(said_mix))

t.run_seconds(20)
gave_back = back0 - moles(BACK_X, BACK_Y)
gave_side = side0 - moles(SIDE_X, SIDE_Y)
assert(gave_side > 0.5, "both intakes still paid: " .. gave_side)
near(gave_back / gave_side, 4.0, 0.05, "in the ratio the machine was set to")

-- ---------------------------------------------------------------
-- A SIDE AT ZERO IS IGNORED, NOT MULTIPLIED BY ZERO.
--
-- tg's `!node2_concentration` branch (mixer.dm:97-101) never reads the
-- idle intake at all, which is what lets a 100/0 mixer be plumbed with
-- one mouth on bare deck. Here the mouth has pipe on it and simply must
-- not lose a mole.
-- ---------------------------------------------------------------
back0, side0 = moles(BACK_X, BACK_Y), moles(SIDE_X, SIDE_Y)
t.ui_act(p, "set", '{"field":"ratio","value":100}')
t.ui_act(p, "set", '{"field":"pressure","value":220}')
t.run_seconds(20)
assert(back0 - moles(BACK_X, BACK_Y) > 1.0, "the back intake carried it alone")
near(moles(SIDE_X, SIDE_Y), side0, 1e-9, "and the idle side never lost a mole")

-- ---------------------------------------------------------------
-- A SHORT SIDE DRAGS THE OTHER DOWN WITH IT.
--
-- The rule the whole machine exists for (mixer.dm:112-116): if either
-- intake cannot supply its share, BOTH draws are scaled by the same
-- limiting factor. Set the target past anything the intakes can reach
-- and the little side stub runs dry -- at which point the back main,
-- which still has plenty, must stop dead rather than keep pouring one
-- gas neat into the outlet.
-- ---------------------------------------------------------------
t.ui_act(p, "set", '{"field":"ratio","value":50}')
t.ui_act(p, "set", '{"field":"pressure","value":"max"}')
t.tick()
near(t.ui(p).setpoints[1].value, 4500.0, 0.001, "wound to MAX_OUTPUT_PRESSURE")

back0 = moles(BACK_X, BACK_Y)
t.run_seconds(60)
assert(moles(SIDE_X, SIDE_Y) < 0.2, "the side stub ran dry: " .. moles(SIDE_X, SIDE_Y))
assert(
    moles(BACK_X, BACK_Y) > 2.0,
    "and the back main stopped with gas still in it: " .. moles(BACK_X, BACK_Y)
)
near(
    back0 - moles(BACK_X, BACK_Y),
    side0 - moles(SIDE_X, SIDE_Y),
    0.05,
    "it gave up exactly what the short side could match"
)
assert(
    t.pipe_pressure(OUT_X, OUT_Y) < 4000.0,
    "so the outlet never reached its target: " .. t.pipe_pressure(OUT_X, OUT_Y)
)
near(
    moles(BACK_X, BACK_Y) + moles(SIDE_X, SIDE_Y) + moles(OUT_X, OUT_Y),
    books,
    1e-6,
    "and the books still balance"
)

-- ---------------------------------------------------------------
-- NEGATIVE: the window is the whitelist here too.
-- ---------------------------------------------------------------
t.ui_act(p, "set", '{"field":"ratio","value":400}')
t.tick()
near(t.ui(p).setpoints[2].value, 100.0, 0.001, "a share cannot exceed the whole")
t.ui_act(p, "set", '{"field":"ratio","value":-90}')
t.tick()
near(t.ui(p).setpoints[2].value, 0.0, 0.001, "nor go below nothing")
t.ui_act(p, "set", '{"field":"pressure","value":99999}')
t.tick()
near(t.ui(p).setpoints[1].value, 4500.0, 0.001, "nor dial past MAX_OUTPUT_PRESSURE")

-- A knob belonging to the machine next door, and a switch this one does
-- not have.
local before = t.ui(p).setpoints[1].value
t.ui_act(p, "set", '{"field":"rate","value":50}')
t.ui_act(p, "toggle", '{"field":"filter","option":"o2"}')
t.tick()
assert(t.ui(p).setpoints[1].value == before, "a gas filter's knobs are not a mixer's")
assert(t.ui(p).toggles[1].on == true, "and it has no roster to toggle")

assert(t.ledger_has("MachineSetpoint", "ratio", "Player"), "re-splitting the mix is recorded")
assert(t.ledger_has("MachineSetpoint", "pressure", "Player"), "so is the output setpoint")

-- ---------------------------------------------------------------
-- THE MIRROR IMAGE.
--
-- Flipping is not turning: tg swaps node1 and node3 and leaves node2
-- where it is (trinary_devices.dm:43-51), so the flow reverses along
-- the axis while the side intake keeps its wall. On the same junction
-- as above, that makes the EAST main the back intake and the WEST main
-- the outlet -- and the proof is which main fills and which empties.
-- ---------------------------------------------------------------
t.world([==[(
    name: "flipped mixer",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'a': (turf: Plating, fixture: Some(Apc)),
        'g': (turf: Plating, fixture: Some(Generator)),
    },
    rows: [
        "##############",
        "#............#",
        "#........a..g#",
        "##############",
    ],
    spawns: [(9, 2)],
    pipes: [
        (1, 1, 4), (2, 1, 4), (3, 1, 4), (4, 1, 4),
        (5, 1, 4), (6, 1, 4), (7, 1, 4), (8, 1, 4),
        (10, 1, 4), (11, 1, 4), (12, 1, 4),
        (9, 2, 4),
    ],
    structures: [(9, 1, "gas_mixer_flipped")],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3), (4, 1, 3), (5, 1, 3), (6, 1, 3), (7, 1, 3), (8, 1, 3), (9, 1, 3), (10, 1, 3), (11, 1, 3), (12, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3), (4, 2, 3), (5, 2, 3), (6, 2, 3), (7, 2, 3), (8, 2, 3), (9, 2, 3), (10, 2, 3), (11, 2, 3), (12, 2, 3),
    ],
)]==], 7)

local q = t.join()
t.tick()
assert(t.structure_at(9, 1).id == "gas_mixer_flipped", "the mirrored machine")

local west0 = moles(BACK_X, BACK_Y)
local east0 = moles(OUT_X, OUT_Y)
local stub0 = moles(SIDE_X, SIDE_Y)
t.click(q, 9, 1, t.target_at(9, 1, "gas_mixer_flipped"))
t.tick()
t.ui_act(q, "set", '{"field":"pressure","value":300}')
t.ui_act(q, "toggle", '{"field":"power"}')
t.run_seconds(30)

assert(
    moles(BACK_X, BACK_Y) > west0 + 1.0,
    "the WEST main is the outlet now, and it filled: " .. west0 .. " -> " .. moles(BACK_X, BACK_Y)
)
assert(
    moles(OUT_X, OUT_Y) < east0 - 1.0,
    "the EAST main is an intake now, and it paid: " .. east0 .. " -> " .. moles(OUT_X, OUT_Y)
)
assert(moles(SIDE_X, SIDE_Y) < stub0 - 0.5, "and the side stub is still an intake")
