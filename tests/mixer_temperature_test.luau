-- What temperature comes out of a gas mixer.
--
-- gas_mixer_test.luau weighs the machine in MOLES: who paid, how much,
-- and what happens when a supply line runs dry. It never asks how HOT
-- the mix is, and that is the question a real atmospherics loop is
-- built around -- the nitrogen a station breathes comes off a cold
-- storage line and the oxygen off a warm one, and the number that
-- decides whether distro carries breathable air or a heat problem is
-- the blend.
--
-- tg answers it in three lines that are easy to get subtly wrong:
--
--   * `remove()` hands back a parcel at the SOURCE's own temperature
--     and leaves that source exactly where it was
--     (gas_mixture.dm:203-223, and 215 is the whole sentence:
--     `removed.temperature = temperature`). Drawing gas off a line is
--     not conduction. A machine that cooled its own hot intake by
--     drawing from it would be a refrigerator nobody built.
--   * `merge()` settles the destination at the heat-capacity-weighted
--     blend of what it held and what arrived (gas_mixture.dm:148-158).
--   * and the mixer prices its DEMAND at that blend before it draws a
--     mole -- `equalized_temperature` (mixer.dm:88-92) -- which is why
--     the two intakes cannot be costed independently.
--
-- Every net in this file starts as the same standard air, and a
-- proportional draw keeps it that way, so one mole is one mole's worth
-- of heat capacity wherever it stands. That makes the enthalpy blend
-- readable as a MOLE-weighted average of temperatures, which is what
-- the predictions below are, and `t.pipe_energy` audits the same
-- arithmetic in joules underneath.
--
-- One junction serves the file, the same one gas_mixer_test.luau uses:
-- a long back main, a one-length stub dropping south as the side
-- intake, and a short outlet main east.

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

local JUNCTION = [==[(
    name: "mixer temperature",
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
)]==]

-- Enough joules to put the side stub several hundred kelvin over the
-- back main. `t.heat_pipe` is scaffolding and says so: nothing a player
-- can reach heats one line and not another yet, so a spec about blends
-- has no other way to set one up. Never an assertion -- only ever the
-- gradient the machine is then asked to blend.
local FIRE = 90000.0

-- ---------------------------------------------------------------
-- HALF AND HALF: THE OUTLET LANDS BETWEEN ITS TWO INTAKES.
--
-- Warm the side stub and leave the back main at room temperature. A
-- mixer taking equal moles off each must deliver a stream at the
-- midpoint of the two, and the outlet -- which already held air of its
-- own -- must land at the weighted average of all three contributions
-- and nowhere else.
-- ---------------------------------------------------------------
t.world(JUNCTION, 7)

local p = t.join()
t.tick()
assert(t.structure_at(9, 1).id == "gas_mixer", "the mixer is where the map put it")

near(t.pipe_temperature(BACK_X, BACK_Y), 293.15, 0.5, "every mapped run opens at room temperature")
near(t.pipe_temperature(SIDE_X, SIDE_Y), 293.15, 0.5, "the side stub too")
near(t.pipe_temperature(OUT_X, OUT_Y), 293.15, 0.5, "and the outlet main")

assert(t.heat_pipe(SIDE_X, SIDE_Y, FIRE), "the side stub takes the heat")
t.tick()

local back_k = t.pipe_temperature(BACK_X, BACK_Y)
local side_k = t.pipe_temperature(SIDE_X, SIDE_Y)
local out_k = t.pipe_temperature(OUT_X, OUT_Y)
assert(side_k > back_k + 300.0, "the side intake is the hot one: " .. side_k .. " vs " .. back_k)
-- Three nets, and heat crosses between them no more than moles do: an
-- idle mixer is a length of pipe in both books.
near(out_k, 293.15, 0.5, "and the heat went nowhere else: " .. out_k)

local back0, side0, out0 = moles(BACK_X, BACK_Y), moles(SIDE_X, SIDE_Y), moles(OUT_X, OUT_Y)
local energy0 = t.pipe_energy(BACK_X, BACK_Y)
    + t.pipe_energy(SIDE_X, SIDE_Y)
    + t.pipe_energy(OUT_X, OUT_Y)

t.click(p, 9, 1, t.target_at(9, 1, "gas_mixer"))
t.tick()
assert(t.ui(p).document == "modules" and t.ui(p).presentation == "modules",
    "the mixer's declared document")
near(t.ui(p).setpoints[2].value, 50.0, 0.001, "half and half out of the box")
t.ui_act(p, "set", '{"field":"pressure","value":200}')
t.ui_act(p, "toggle", '{"field":"power"}')
t.run_seconds(30)
-- Thirty seconds later the outlet is at the 200 kPa it was dialled to,
-- so the machine has ARRIVED -- and a trinary is drawn by what the last
-- pass saw it do rather than by its switch, so an arrived mixer is drawn
-- idle (docs/ATMOS.md SS6; device_looks_test.luau owns the picture
-- rule). That it RAN is the three assertions below, which count moles.
assert(t.structure_at(9, 1).state == "off", "it arrived and stopped")

local gave_back = back0 - moles(BACK_X, BACK_Y)
local gave_side = side0 - moles(SIDE_X, SIDE_Y)
assert(gave_back > 1.0, "the back intake paid: " .. gave_back)
assert(gave_side > 1.0, "and so did the hot side: " .. gave_side)

-- DRAWING IS NOT CONDUCTION. Both intakes gave up moles and neither
-- gave up a degree: tg's `remove()` copies the source's temperature
-- onto the parcel and never writes it back (gas_mixture.dm:215). This
-- is the assertion a mixer that "equalised" its intakes would fail
-- while still reading plausibly on every pressure gauge on the line.
near(t.pipe_temperature(BACK_X, BACK_Y), back_k, 0.001, "the back main is exactly as cold as it was")
near(t.pipe_temperature(SIDE_X, SIDE_Y), side_k, 0.001, "and the side stub exactly as hot")

-- THE BLEND. What reached the outlet is the two parcels at their own
-- temperatures, on top of the air the outlet already held; one mole is
-- one mole's worth of heat capacity here, so the enthalpy blend is the
-- mole-weighted average of the three.
local blend = (out0 * out_k + gave_back * back_k + gave_side * side_k)
    / (out0 + gave_back + gave_side)
near(t.pipe_temperature(OUT_X, OUT_Y), blend, 0.5, "the outlet reads the blend of what it was given")
assert(
    t.pipe_temperature(OUT_X, OUT_Y) > out_k + 20.0,
    "which is warmer than the main started: " .. out_k .. " -> " .. t.pipe_temperature(OUT_X, OUT_Y)
)

-- The stream the machine actually delivered, by itself: equal shares
-- off a cold line and a hot one land halfway between them.
local stream_50 = (gave_back * back_k + gave_side * side_k) / (gave_back + gave_side)
near(stream_50, (back_k + side_k) / 2.0, 1.0, "a 50/50 stream is the midpoint of its intakes")

-- AND NOT A JOULE WAS MINTED. Pressure and temperature between them
-- cannot catch a machine that moved heat and made some on the trip;
-- the conserved quantity can.
near(
    t.pipe_energy(BACK_X, BACK_Y) + t.pipe_energy(SIDE_X, SIDE_Y) + t.pipe_energy(OUT_X, OUT_Y),
    energy0,
    1.0,
    "every joule the outlet gained came off an intake"
)

-- ---------------------------------------------------------------
-- FOUR TO ONE: THE BLEND FOLLOWS THE RATIO.
--
-- The same gradient, the same setpoint, and the machine set to take
-- 80% of its mix off the COLD back main. tg divides `general_transfer`
-- by the shares before either draw (mixer.dm:91-92), so the stream is
-- the share-weighted average of the two intake temperatures -- and a
-- station that wants its distro cooler turns this dial, not a
-- thermostat it does not have.
-- ---------------------------------------------------------------
t.world(JUNCTION, 7)

local q = t.join()
t.tick()
assert(t.heat_pipe(SIDE_X, SIDE_Y, FIRE), "the same stub, the same heat")
t.tick()

local cold_k = t.pipe_temperature(BACK_X, BACK_Y)
local hot_k = t.pipe_temperature(SIDE_X, SIDE_Y)
local main_k = t.pipe_temperature(OUT_X, OUT_Y)
near(hot_k, side_k, 0.5, "the gradient is the one the last section blended")

back0, side0, out0 = moles(BACK_X, BACK_Y), moles(SIDE_X, SIDE_Y), moles(OUT_X, OUT_Y)
energy0 = t.pipe_energy(BACK_X, BACK_Y)
    + t.pipe_energy(SIDE_X, SIDE_Y)
    + t.pipe_energy(OUT_X, OUT_Y)

t.click(q, 9, 1, t.target_at(9, 1, "gas_mixer"))
t.tick()
t.ui_act(q, "set", '{"field":"ratio","value":80}')
t.ui_act(q, "set", '{"field":"pressure","value":200}')
t.ui_act(q, "toggle", '{"field":"power"}')
t.run_seconds(30)

gave_back = back0 - moles(BACK_X, BACK_Y)
gave_side = side0 - moles(SIDE_X, SIDE_Y)
assert(gave_side > 0.2, "the hot side still contributed: " .. gave_side)

local stream_80 = (gave_back * cold_k + gave_side * hot_k) / (gave_back + gave_side)
near(
    stream_80,
    0.8 * cold_k + 0.2 * hot_k,
    1.0,
    "the delivered stream is the SHARE-weighted average of the intakes"
)
assert(
    stream_80 < stream_50 - 50.0,
    "so leaning on the cold intake delivers a cooler mix: "
        .. stream_50 .. " K at 50/50, " .. stream_80 .. " K at 80/20"
)

near(
    t.pipe_temperature(OUT_X, OUT_Y),
    (out0 * main_k + gave_back * cold_k + gave_side * hot_k) / (out0 + gave_back + gave_side),
    0.5,
    "and the outlet again reads the blend of exactly what it was given"
)
near(t.pipe_temperature(SIDE_X, SIDE_Y), hot_k, 0.001, "the hot stub is still as hot as it was")
near(
    t.pipe_energy(BACK_X, BACK_Y) + t.pipe_energy(SIDE_X, SIDE_Y) + t.pipe_energy(OUT_X, OUT_Y),
    energy0,
    1.0,
    "and the books balance at a lopsided ratio too"
)
