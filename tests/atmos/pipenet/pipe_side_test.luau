-- Aiming a ONE-MOUTHED fitting, which is a different sentence from
-- aiming a pump.
--
-- A machine with two mouths or three is aimed by its FACING, and the
-- facing is the way the gas goes: `"dir": "east"` on a pump is "it
-- pushes east", which is what a mapper already means. A machine with
-- ONE mouth is not like that. Its node sits BEHIND the facing (tg's
-- unary node, `docs/ATMOS.md` §4), so a vent, a scrubber, an injector
-- or a stubbed port pointed at the run it was meant to join reached the
-- other way and joined nothing -- a machine that looked installed on
-- the map, drew power, wore its running picture and moved not one mole.
--
-- So a one-mouthed placement says `"pipe"` and the word is where its
-- MOUTH reaches; the picture is derived from that. This file is that
-- claim, both ways round on one bench: the same scrubber, the same
-- room, the same waste main, aimed at the run and aimed away from it.

-- A room with a waste main leaving under the west wall, an APC and a
-- generator behind it. `{side}` is the only thing that changes.
local function bench(side)
    return ([==[(
    name: "aimed scrubber",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'a': (composition: (components: [(component: "station_base")])),
        'g': (composition: (components: [(component: "station_base")]), fixture: Some(Generator)),
    },
    rows: [
        "########",
        "#......#",
        "#....ag#",
        "########",
    ],
    // Layer 2 under the west wall and under the scrubber's own tile:
    // the waste main, which is where a scrubber lives.
    networks: [
        (x: 0, y: 1, network: "pipe", channel: "l2", kind: "standard", facing: 15),
        (x: 1, y: 1, network: "pipe", channel: "l2", kind: "standard", facing: 15),
        (x: 1, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 1, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 2, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 3, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 3, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 4, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 4, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 5, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 5, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 6, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 6, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 1, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 1, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 2, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 3, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 3, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 4, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 4, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 5, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 5, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 6, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 6, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
    ],
    structures: [
        (5, 2, "player_spawn"),
        (2, 1, "air_scrubber", "siphoning", { "pipe": "SIDE", "whole_air": true, "rate_lps": 200.0, "floor_kpa": 0.0 }),
        (5, 2, "apc"),
    ],

)]==]):gsub("SIDE", side)
end

-- ---- aimed AT the run: the mouth finds it, and the room comes down --
t.world(bench("west"), 7, "free_build")
t.tick()

assert(assert(t.structure_at(2, 1)).id == "air_scrubber", "the map stood one there")
-- The mapped third state means the emptying POSTURE (whole air, no
-- floor); the purge art itself is judged off the air, so a machine
-- over a still-comfortable room opens wearing the ordinary running
-- body (docs/ATMOS.md, the purge picture).
assert(assert(t.structure_at(2, 1)).state == "scrubbing", "and it ships running")

local opening = assert(t.room_pressure(4, 1))
assert(opening > 90.0, "the room opens at about an atmosphere: " .. opening)

t.run_seconds(20)
local drawn = assert(t.room_pressure(4, 1))
assert(
    drawn < opening - 10.0,
    "a scrubber whose mouth reaches the waste main draws the room down: "
        .. opening
        .. " -> "
        .. drawn
)

-- ---- aimed AWAY from it: one word, and the machine does nothing ----
--
-- The same placement with the mouth pointed east instead. There is no
-- run east of it, so the one mouth binds to nothing and the room holds
-- -- which is exactly the station a mapper used to draw by accident
-- when the key was the facing and they aimed it at the pipe.
t.world(bench("east"), 7, "free_build")
t.tick()

local held_0 = assert(t.room_pressure(4, 1))
t.run_seconds(20)
local held = assert(t.room_pressure(4, 1))
assert(
    math.abs(held - held_0) < 5.0,
    "a mouth pointed at nothing moves nothing: " .. held_0 .. " -> " .. held
)
