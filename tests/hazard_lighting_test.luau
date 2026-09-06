-- A room that tells its own lights what the air in it is doing.
--
-- Three parties, and none of them knows more than its own job
-- (content/lib/netmsg.luau):
--
--   * A VENT reads the air on the tile it is bolted to. The engine
--     sorts that tile into `none`, `unbreathable` or `deadly` on the
--     atmos cadence, against the bands `content/tuning.luau` sets, and
--     hands the fan the crossing (docs/atmos/hazard-sensing.md). The
--     fan repeats the word onto its own network and stops. It has no
--     idea whether the ROOM is in trouble.
--
--   * The AIR ALARM keeps the roster. It hears every fan it holds and
--     every fan its own panel feeds, remembers the worst word each one
--     said, and turns the tally into named flags. It is the only party
--     that knows what a room amounts to.
--
--   * A LIGHT burns the worst flag standing and goes back to its own
--     tube's colour when the last one clears. It has never heard of
--     air.
--
-- NOBODY WIRED ANY OF THIS. The fan, the alarm and the fitting are all
-- fed by the same panel, so the electrical pass made them a family:
-- the fan is the alarm's sibling and the fitting is too, which is
-- exactly the set of things in one room (docs/devices/joining.md).
-- Bolt an alarm to a wall and the room reports itself.
--
-- The bench ships the room full of NITROGEN rather than air. It is at
-- a perfectly ordinary pressure and a perfectly ordinary temperature
-- and there is nothing in it to breathe, which is the cheapest way to
-- stand a room in one band and walk it out again without freezing it
-- to get there.
t.world([==[(
    name: "hazard lighting",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'o': (turf: Plating, fixture: Some(Outlet)),
        'l': (turf: Plating, fixture: Some(Light)),
        'g': (turf: Plating, fixture: Some(Generator)),
    },
    rows: [
        "########",
        "#.o....#",
        "#l....g#",
        "########",
    ],
    spawns: [(3, 2)],
    structures: [
        (4, 1, "vent"),
        (5, 1, "air_alarm", { "access": "engineering", "network_1": "network_card" }),
        (6, 1, "apc"),
    ],
    blends: {
        "thin_nitrogen": (rows: [("n2", 41.6)], temperature_k: 293.15, amount: per_tile),
    },
    painted: [
        (1, 1, "thin_nitrogen"), (2, 1, "thin_nitrogen"), (3, 1, "thin_nitrogen"),
        (4, 1, "thin_nitrogen"), (5, 1, "thin_nitrogen"), (6, 1, "thin_nitrogen"),
        (1, 2, "thin_nitrogen"), (2, 2, "thin_nitrogen"), (3, 2, "thin_nitrogen"),
        (4, 2, "thin_nitrogen"), (5, 2, "thin_nitrogen"), (6, 2, "thin_nitrogen"),
    ],
    cables: [
        (6, 2, 2), (6, 1, 2),
        (6, 1, 1), (5, 1, 1), (4, 1, 1), (3, 1, 1), (2, 1, 1),
    ],
    labels: [(6, 1, "Engineering")],
)]==], 0)

t.set_environment({ sink_k = 293.15, insolation = 0 })
local p = t.join()
t.tick()
t.run_seconds(3)
t.run_ticks(60)

local DEADLY = "#FF2020"
local UNBREATHABLE = "#3060FF"

-- ---------------------------------------------------------------
-- 1. A ROOM WITH NOTHING TO BREATHE. Ordinary pressure, ordinary
--    temperature, no oxygen -- so the fan says `unbreathable`, the
--    alarm raises that flag, and the fitting goes blue and up a
--    little. Blue rather than red on purpose: a crewman coming
--    through the door should be able to tell an airless room from a
--    lethal one before they take their helmet off.
-- ---------------------------------------------------------------
assert(t.room_pressure(3, 2) > 90.0, "the room is at pressure: " .. t.room_pressure(3, 2))
local lamp = t.light_at(1, 2)
assert(lamp ~= nil and lamp.lit, "the fitting is burning")
assert(lamp.color == UNBREATHABLE, "and it has gone blue: " .. lamp.color)
assert(math.abs(lamp.power - 1.2) < 1e-6, "a touch harder: " .. lamp.power)
assert(math.abs(lamp.range - 6.0) < 1e-6,
    "and reaching exactly as far: a warned room is not a smaller one")

-- ---------------------------------------------------------------
-- 2. PUT THE OXYGEN BACK. The band the fan is in changes, so it says
--    so once; the alarm drops the address from its roster, finds the
--    flag no longer stands anywhere, and clears it. The fitting goes
--    back to the colour of its own tube -- which is the one thing it
--    remembered through all of this.
-- ---------------------------------------------------------------
assert(t.foul_room(3, 2, "o2", 140.0), "oxygen into the room")
t.run_seconds(6)
t.run_ticks(60)

lamp = t.light_at(1, 2)
local TUBE = lamp.color
assert(TUBE ~= UNBREATHABLE and TUBE ~= DEADLY, "the fitting is its own colour again: " .. TUBE)
assert(math.abs(lamp.power - 1.0) < 1e-6, "at its own power: " .. lamp.power)

-- ---------------------------------------------------------------
-- 3. SOMETHING THAT KILLS. Plasma into the room: the oxygen is still
--    there and the pressure is fine, so nothing about BREATHING has
--    changed -- what changed is that the mix now rates lethal on the
--    same scale a hazard placard is drawn from. Deadly outranks
--    everything, and the room goes red.
-- ---------------------------------------------------------------
assert(t.foul_room(3, 2, "plasma", 30.0), "plasma into the room")
t.run_seconds(6)
t.run_ticks(60)

lamp = t.light_at(1, 2)
assert(lamp.color == DEADLY, "the room is red: " .. lamp.color)
assert(math.abs(lamp.power - 1.5) < 1e-6, "and harder still: " .. lamp.power)
assert(math.abs(lamp.range - 6.0) < 1e-6, "reach untouched by any of it")
