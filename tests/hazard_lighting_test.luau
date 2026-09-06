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
        "###########",
        "#.o.......#",
        "#l.......g#",
        "###########",
    ],
    spawns: [(7, 2)],
    items: [(7, 2, "wirecutters"), (7, 2, "cable_coil")],
    structures: [
        (4, 1, "vent"),
        (5, 1, "air_alarm", { "access": "engineering", "network_1": "network_card" }),
        (8, 1, "apc"),
    ],
    blends: {
        "thin_nitrogen": (rows: [("n2", 41.6)], temperature_k: 293.15, amount: per_tile),
    },
    painted: [
        (1, 1, "thin_nitrogen"), (2, 1, "thin_nitrogen"), (3, 1, "thin_nitrogen"),
        (4, 1, "thin_nitrogen"), (5, 1, "thin_nitrogen"), (6, 1, "thin_nitrogen"),
        (7, 1, "thin_nitrogen"), (8, 1, "thin_nitrogen"), (9, 1, "thin_nitrogen"),
        (1, 2, "thin_nitrogen"), (2, 2, "thin_nitrogen"), (3, 2, "thin_nitrogen"),
        (4, 2, "thin_nitrogen"), (5, 2, "thin_nitrogen"), (6, 2, "thin_nitrogen"),
        (7, 2, "thin_nitrogen"), (8, 2, "thin_nitrogen"), (9, 2, "thin_nitrogen"),
    ],
    cables: [
        (9, 2, 2), (8, 2, 2), (8, 1, 2),
        (8, 1, 1), (7, 1, 1), (6, 1, 1), (5, 1, 1), (4, 1, 1), (3, 1, 1), (2, 1, 1),
    ],
    labels: [(8, 1, "Engineering")],
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
-- 2. A SECOND FLAG UNDERNEATH IT. Part the backbone and the panel
--    runs the room off its own cell, which puts `low_power` on the
--    network beside the alarm's word (content/fixtures/apc.luau).
--    Two conditions now stand on one fitting and the worse of them
--    is what burns: blue outranks a dimming, so nothing visible
--    changes, which is exactly the point of an importance order.
-- ---------------------------------------------------------------
-- A coil in one hand and the cutters in the other, both picked up
-- before anything is cut: a length recovered from the deck merges
-- into whatever coil is lying there, so a coil left on the floor
-- through a snip is not the same object afterwards.
t.click(p, 7, 2, t.target_at(7, 2, "cable_coil"))
t.run_ticks(2)
assert(t.hands(p).held == "cable_coil", "a coil in one hand")
t.swap_hands(p)
t.run_ticks(2)
t.click(p, 7, 2, t.target_at(7, 2, "wirecutters"))
t.run_ticks(2)
assert(t.hands(p).held == "wirecutters", "cutters in the other")
t.click_subfloor(p, 8, 2, "cable", 2)
t.run_seconds(1.5)
assert(t.cable_at(8, 2) == 0, "the backbone is parted")
t.run_seconds(3)
t.run_ticks(60)

assert(t.apc_at(8, 1).charging == "not_charging", "the panel is on its own cell")
lamp = t.light_at(1, 2)
assert(lamp.color == UNBREATHABLE, "the air still outranks the batteries: " .. lamp.color)
assert(math.abs(lamp.power - 1.2) < 1e-6, "at the air's own power: " .. lamp.power)

-- ---------------------------------------------------------------
-- 3. CLEAR THE WORSE ONE AND FALL BACK, not to the tube. Oxygen into
--    the room: the fan crosses a band, the alarm drops its address
--    and takes its flag off -- and the fitting lands on the flag
--    still under it rather than on white. Dim, and its own colour.
--
--    This is the pair the fall-back is shown with because it is the
--    reversible one: a room that has had plasma in it never rates
--    clean again, so the deadly flag below can be raised but not
--    lowered.
-- ---------------------------------------------------------------
assert(t.foul_room(3, 2, "o2", 320.0), "oxygen into the room")
t.run_seconds(6)
t.run_ticks(60)

lamp = t.light_at(1, 2)
local TUBE = lamp.color
assert(TUBE ~= UNBREATHABLE and TUBE ~= DEADLY, "the fitting is its own colour again: " .. TUBE)
assert(math.abs(lamp.power - 0.5) < 1e-6, "and dim, on the flag underneath: " .. lamp.power)

-- ---------------------------------------------------------------
-- 4. AND ALL THE WAY BACK. Lay the parted length again: the panel
--    comes off its reserve, takes its own flag off, and the last row
--    on the stack goes with it. The fitting is what the tube in it
--    burns, which is the one thing it kept through all of this.
-- ---------------------------------------------------------------
t.swap_hands(p)
t.run_ticks(2)
assert(t.hands(p).held == "cable_coil", "the coil comes back to the working hand")
t.click(p, 8, 2)
t.run_seconds(1.5)
assert(t.cable_at(8, 2) == 2, "the backbone is whole again")
t.run_seconds(3)
t.run_ticks(60)

lamp = t.light_at(1, 2)
assert(lamp.color == TUBE, "still its own colour: " .. lamp.color)
assert(math.abs(lamp.power - 1.0) < 1e-6, "and back at its own power: " .. lamp.power)

-- ---------------------------------------------------------------
-- 5. SOMETHING THAT KILLS. Plasma into the room: the oxygen is still
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

-- ---------------------------------------------------------------
-- A SECOND BENCH: TWO ALARMS, TWO ROOMS, ONE FITTING.
--
-- Everything above had one voice. This has two, and the whole point
-- of keying a flag by WHO raised it is what happens when they
-- disagree: a room can carry two alarms, and one of them finding its
-- own patch of air breathable must not take the other's word off the
-- ceiling (content/fixtures/light.luau).
--
-- The bench: a panel feeding one long circuit, a room either side of
-- a wall with a fan in each, two alarms bolted up in the west room --
-- so both hear both fans as siblings -- and one fitting. The far
-- alarm cords to a port on a spur of its own, nine tiles from the
-- other one and so out of reach of it, which is the only way to take
-- one voice off the air without taking the other with it.
-- ---------------------------------------------------------------
t.world([==[(
    name: "two alarms",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'o': (turf: Plating, fixture: Some(Outlet)),
        'l': (turf: Plating, fixture: Some(Light)),
        'g': (turf: Plating, fixture: Some(Generator)),
    },
    rows: [
        "####################",
        "#.o.........#.o...g#",
        "#l........o.#......#",
        "####################",
    ],
    spawns: [(9, 2)],
    items: [(9, 2, "wirecutters"), (2, 2, "toolbox"), (2, 2, "light_tube")],
    structures: [
        (3, 1, "air_alarm", { "access": "engineering", "network_1": "network_card" }),
        (4, 1, "vent"),
        (11, 1, "air_alarm", { "access": "engineering", "network_1": "network_card" }),
        (15, 1, "vent"),
        (17, 1, "apc"),
    ],
    blends: {
        "thin_nitrogen": (rows: [("n2", 41.6)], temperature_k: 293.15, amount: per_tile),
    },
    painted: [
        (1, 1, "thin_nitrogen"), (2, 1, "thin_nitrogen"), (3, 1, "thin_nitrogen"),
        (4, 1, "thin_nitrogen"), (5, 1, "thin_nitrogen"), (6, 1, "thin_nitrogen"),
        (7, 1, "thin_nitrogen"), (8, 1, "thin_nitrogen"), (9, 1, "thin_nitrogen"),
        (10, 1, "thin_nitrogen"), (11, 1, "thin_nitrogen"),
        (1, 2, "thin_nitrogen"), (2, 2, "thin_nitrogen"), (3, 2, "thin_nitrogen"),
        (4, 2, "thin_nitrogen"), (5, 2, "thin_nitrogen"), (6, 2, "thin_nitrogen"),
        (7, 2, "thin_nitrogen"), (8, 2, "thin_nitrogen"), (9, 2, "thin_nitrogen"),
        (10, 2, "thin_nitrogen"), (11, 2, "thin_nitrogen"),
        (13, 1, "thin_nitrogen"), (14, 1, "thin_nitrogen"), (15, 1, "thin_nitrogen"),
        (16, 1, "thin_nitrogen"), (17, 1, "thin_nitrogen"), (18, 1, "thin_nitrogen"),
        (13, 2, "thin_nitrogen"), (14, 2, "thin_nitrogen"), (15, 2, "thin_nitrogen"),
        (16, 2, "thin_nitrogen"), (17, 2, "thin_nitrogen"), (18, 2, "thin_nitrogen"),
    ],
    cables: [
        (18, 1, 2), (17, 1, 2),
        (17, 1, 1), (16, 1, 1), (15, 1, 1), (14, 1, 1), (13, 1, 1), (12, 1, 1),
        (11, 1, 1), (10, 1, 1), (9, 1, 1), (8, 1, 1), (7, 1, 1), (6, 1, 1),
        (5, 1, 1), (4, 1, 1), (3, 1, 1), (2, 1, 1),
        (10, 2, 1),
    ],
    labels: [(17, 1, "Engineering")],
)]==], 0)

t.set_environment({ sink_k = 293.15, insolation = 0 })
local q = t.join()
t.tick()
t.run_seconds(3)
t.run_ticks(60)

-- ---------------------------------------------------------------
-- 6. TWO VOICES SAYING THE SAME THING. Neither room has anything to
--    breathe, both alarms hold both fans, so the flag arrives twice
--    and the fitting keeps a row per sender rather than one bool.
-- ---------------------------------------------------------------
lamp = t.light_at(1, 2)
assert(lamp ~= nil and lamp.lit, "the fitting is burning")
assert(lamp.color == UNBREATHABLE, "and both alarms have it blue: " .. lamp.color)

-- ---------------------------------------------------------------
-- 7. TAKE ONE VOICE OFF THE AIR and give the other nothing to
--    complain about. The far alarm cords to the port on the spur, so
--    one snip leaves it unpowered and off the network with its word
--    still standing; the near alarm sees breathable air and lets go
--    of its own row. The flag stands on the row nobody withdrew,
--    which is the whole reason the rows exist -- one alarm cannot
--    take another's word off a ceiling.
-- ---------------------------------------------------------------
t.click(q, 9, 2, t.target_at(9, 2, "wirecutters"))
t.run_ticks(2)
assert(t.hands(q).held == "wirecutters", "cutters in hand")
t.click_subfloor(q, 10, 2, "cable", 1)
t.run_seconds(1.5)
assert(t.cable_at(10, 2) == 0, "the spur is parted")
t.drop(q)
t.run_seconds(3)
t.run_ticks(40)

-- Gently, and spread out: a single dump of four hundred moles onto
-- one tile is a pressure spike, and a spike is a wind that slides
-- loose tools down the room (content/tuning.luau, `wind_slide_pa`).
for _, at in ipairs({ { 3, 1 }, { 5, 1 }, { 7, 1 }, { 9, 1 }, { 11, 1 } }) do
    assert(t.foul_room(at[1], at[2], "o2", 80.0), "oxygen into the west room")
    t.run_seconds(2)
end
for _, at in ipairs({ { 14, 1 }, { 16, 1 }, { 18, 1 } }) do
    assert(t.foul_room(at[1], at[2], "o2", 75.0), "and into the east one")
    t.run_seconds(2)
end
t.run_seconds(6)
t.run_ticks(60)

lamp = t.light_at(1, 2)
assert(lamp.color == UNBREATHABLE,
    "one alarm let go, the other never did, and the flag stands: " .. lamp.color)
assert(math.abs(lamp.power - 1.2) < 1e-6, "at the flag's own power: " .. lamp.power)

-- ---------------------------------------------------------------
-- 8. A WORSE WORD OUTRANKS A STANDING ONE. Plasma in the east room:
--    the live alarm raises death over a blue nobody can withdraw,
--    and the fitting burns the worse of the two.
-- ---------------------------------------------------------------
assert(t.foul_room(15, 1, "plasma", 30.0), "plasma into the east room")
t.run_seconds(6)
t.run_ticks(60)

lamp = t.light_at(1, 2)
assert(lamp.color == DEADLY, "deadly outranks the standing blue: " .. lamp.color)
assert(math.abs(lamp.power - 1.5) < 1e-6, "and burns harder: " .. lamp.power)

-- ---------------------------------------------------------------
-- 9. A NEW TUBE UNDER A STANDING FLAG comes back burning the flag.
--    The stack is the FITTING's and outlives what is screwed into
--    it: smash the glass, fit a fresh tube, and the room is still
--    warning you about the air rather than going quietly white.
-- ---------------------------------------------------------------
for _ = 1, 24 do
    if t.pos(q) == 2 then
        break
    end
    t.move(q, "west")
    t.run_ticks(5)
end
assert(t.pos(q) == 2, "at the fitting's own tile")
local fitting = t.target_at(1, 2)
t.click(q, 2, 2, t.target_at(2, 2, "toolbox"))
t.run_ticks(2)
assert(t.hands(q).held == "toolbox", "something heavy in hand")
t.click(q, 1, 2, fitting)
t.run_ticks(2)
assert(t.light_at(1, 2).status == "broken", "the tube shattered")
assert(not t.light_at(1, 2).emits, "and throws nothing")

t.drop(q)
t.run_ticks(2)
t.click(q, 2, 2, t.target_at(2, 2, "light_tube"))
t.run_ticks(2)
assert(t.hands(q).held == "light_tube", "a fresh tube in hand")
t.click(q, 1, 2, fitting)
t.run_ticks(5)

lamp = t.light_at(1, 2)
assert(lamp.status == "ok", "the tube goes in")
assert(lamp.emits, "and the room is lit again")
assert(lamp.color == DEADLY,
    "burning the flag that never went away, not the tube's own white: " .. lamp.color)
assert(math.abs(lamp.power - 1.5) < 1e-6, "at the flag's power: " .. lamp.power)
