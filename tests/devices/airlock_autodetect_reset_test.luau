-- Clearing a seal latches nothing: the latch release answers, then hush.
-- No fault may follow the release reports, nor any timer after them.
local AIRLOCK = [==[
(
    name: "Nowhere Airlock",
    environment: (gravity_m_s2: Exact(9.80665)),
    legend: {
        ' ': (composition: (substrate: Some("space"))), '.': (composition: (components: [(component: "station_base")])), '#': (composition: (components: [(component: "station_base"), (component: "wall")])),

        'G': (composition: (components: [(component: "station_base")]), fixture: Some(Generator)),
        'A': (composition: (components: [(component: "station_base")]), fixture: Some(Apc)),
        'o': (composition: (components: [(component: "station_base")]), fixture: Some(Outlet)),
    },
    rows: [
        "#############", "######.#.####", "#############",
        "#........... ", "#GA.o#..#... ", "############ ",
        "             ",
    ],
    blends: {
        "vacuum": (temperature_k: 293.15, amount: per_tile),
        "supply": (rows: [("o2", 392.86967015394526), ("n2", 1477.93828296008)],
            temperature_k: 293.15, amount: per_tile),
    },
    painted: [(6, 1, "supply"), (6, 3, "vacuum"), (7, 3, "vacuum"),
        (6, 4, "vacuum"), (7, 4, "vacuum"), (8, 3, "vacuum"),
        (1, 3, "vacuum"), (2, 3, "vacuum"), (3, 3, "vacuum"), (4, 3, "vacuum"),
        (9, 3, "vacuum"), (10, 3, "vacuum"), (11, 3, "vacuum"),
        (9, 4, "vacuum"), (10, 4, "vacuum"), (11, 4, "vacuum"),
        (8, 1, "vacuum")],
    structures: [
        (3, 3, "player_spawn", { "jobs": "engineer" }),
        (9, 3, "player_spawn", { "jobs": "assistant" }),
        (4, 3, "access_point", { "network_1": "network_card", "file.airlock_controller": true, "program.controller": "airlock_controller", "mount": "north" }),
        (2, 3, "airlock_button", { "mount": "north" }), (7, 4, "airlock_button", { "mount": "south" }),
        (5, 3, "airlock", { "bolted": true }),
        (8, 3, "airlock", { "open": true, "bolted": false }),
        (6, 3, "airlock_pump", { "dir": "north" }),
        (6, 1, "passive_vent", { "channel": "l4", "pipe": "south" }),
        (8, 1, "passive_vent", { "channel": "l2", "pipe": "south" }),
    ],
    links: [
        (4, 3, 2, 3), (4, 3, 5, 3), (4, 3, 6, 3),
        (4, 3, 8, 3), (4, 3, 7, 4),
    ],
    networks: [
        (x: 6, y: 2, network: "pipe", channel: "l4", kind: "standard", facing: 15),
        (x: 6, y: 2, network: "pipe", channel: "l2", kind: "standard", facing: 15),
        (x: 7, y: 2, network: "pipe", channel: "l2", kind: "standard", facing: 15),
        (x: 8, y: 2, network: "pipe", channel: "l2", kind: "standard", facing: 15),
        (x: 1, y: 4, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 4, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 4, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 3, y: 4, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 4, y: 4, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 3, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 3, y: 3, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 4, y: 3, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 5, y: 3, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 6, y: 3, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 7, y: 3, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 8, y: 3, network: "power", channel: "l1", kind: "cable", facing: 15),
    ],
    items: [(3, 3, "laptop")],
)
]==]
t.set_breathing(false)
t.world(AIRLOCK, 0)
local operator0 = t.join("assistant")
local visitor0 = t.join("engineer")
t.run_ticks(20)

-- Any press seals: the chamber button from inside does it.
local operator = operator0
local visitor = visitor0
t.move(operator, "west")
t.run_ticks(4)
t.move(operator, "west")
t.run_ticks(4)
t.click(operator, 7, 4, assert(t.target_at(operator, 7, 4, "airlock_button")))
t.run_ticks(60)
assert(not assert(t.door_at(5, 3)).open, "the west leaf seals shut")
assert(not assert(t.door_at(8, 3)).open, "the east leaf seals shut")
local _ = t.messages(operator)
local _ = t.messages(visitor)
-- The west engineer clears the latch from its own button.
t.click(visitor, 2, 3, assert(t.target_at(visitor, 2, 3, "airlock_button")))
-- The release reports land within ticks; a fault would sound at once.
t.run_ticks(60)
local heard = table.concat(t.messages(operator), " | ")
    .. " | "
    .. table.concat(t.messages(visitor), " | ")
assert(
    heard:find("stopped the airlock cycle", 1, true) == nil,
    "the release answers hush, not fault: " .. heard
)
assert(not assert(t.door_at(5, 3)).open, "the west leaf rests shut")
assert(not assert(t.door_at(8, 3)).open, "the east leaf rests shut")
-- No timer rides behind the release: past twice its old reach, still hush.
t.run_ticks(700)
local heard2 = table.concat(t.messages(operator), " | ")
    .. " | "
    .. table.concat(t.messages(visitor), " | ")
assert(
    heard2:find("stopped the airlock cycle", 1, true) == nil,
    "no timer faults behind a release: " .. heard2
)
-- Nowhere seals again on the next press.
t.click(operator, 7, 4, assert(t.target_at(operator, 7, 4, "airlock_button")))
t.run_ticks(60)
assert(not assert(t.door_at(5, 3)).open, "the west leaf seals again")
assert(not assert(t.door_at(8, 3)).open, "the east leaf seals again")
local heard3 = table.concat(t.messages(operator), " | ")
assert(heard3:find("sealed", 1, true) ~= nil, "the alarm returns with the seal")
