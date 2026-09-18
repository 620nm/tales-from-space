-- A short roster faults; a whole one works again.
-- Release one button and the press is refused with the count short;
-- rejoin it and the next press cycles. The ledger keeps both moves.
local AIRLOCK = [==[
(
    name: "Fault Bench",
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
        (9, 3, "vacuum"), (10, 3, "vacuum"), (11, 3, "vacuum"),
        (9, 4, "vacuum"), (10, 4, "vacuum"), (11, 4, "vacuum"),
        (8, 1, "vacuum")],
    structures: [
        (3, 3, "player_spawn", { "jobs": "assistant" }),
        (9, 3, "player_spawn", { "jobs": "engineer" }),
        (4, 3, "access_point", { "network_1": "network_card", "file.airlock_controller": true, "program.controller": "airlock_controller", "mount": "north" }),
        (2, 3, "airlock_button", { "mount": "north" }), (7, 4, "airlock_button", { "mount": "south" }),
        (5, 3, "airlock", { "bolted": true }),
        (8, 3, "airlock", { "open": true, "bolted": false }),
        (6, 3, "bidirectional_vent", { "dir": "north" }),
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
        (x: 1, y: 4, network: "power", channel: "l2", kind: "cable", facing: 15),
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
local airlock_cycle = require("@helpers/airlock_cycle")
local laptop = require("@helpers/laptop")
local ui_controls = require("@helpers/ui_controls")
t.set_breathing(false)
t.world(AIRLOCK, 0)
local operator = t.join("assistant")
t.join("engineer")
t.run_ticks(20)

local host = assert(t.target_at(operator, 4, 3, "access_point"))
local function members()
    local rows = {}
    for _, row in ipairs(ui_controls.rows(laptop.ui(operator).toggles or {})) do
        if row.field == "link_drop" then
            table.insert(rows, ui_controls.text(row.option))
        end
    end
    return rows
end
laptop.ready(operator, 3, 3)
laptop.connect(operator, 4, 3, host)
laptop.unlock(operator)
t.run_ticks(2)
assert(#members() == 5, "five join at boot")
laptop.toggle(operator, "link_drop", members()[1])
t.run_ticks(2)
assert(#members() == 4, "one release leaves four")
laptop.close(operator)
t.drop(operator)
t.run_ticks(2)
local _ = t.messages(operator)
t.click(operator, 2, 3, assert(t.target_at(operator, 2, 3, "airlock_button")))
t.run_ticks(10)
local heard = table.concat(t.messages(operator), " | ")
local drops = 0
for _, row in ipairs(t.ledger_rows("link_released")) do
    if row.why == nil then
        drops += 1
    end
end
assert(drops >= 1, "the release left a ledger row")
-- Four cannot cycle: either nobody answers (released leaf pressed) or
-- the count refuses it (the room is short a member).
assert(
    heard:find("nothing answers", 1, true) ~= nil
        or heard:find("stopped the airlock cycle", 1, true) ~= nil,
    "a short roster faults aloud: " .. heard
)
-- Rejoin through the laptop; the next press cycles.
laptop.take(operator, 3, 3)
laptop.connect(operator, 4, 3, host)
local joined = 0
while true do
    local candidate
    for _, row in ipairs(ui_controls.rows(laptop.ui(operator).toggles or {})) do
        if
            row.field == "link_join"
            and ui_controls.word(row.label) == "link.candidate.endpoint"
        then
            candidate = ui_controls.text(row.option)
            break
        end
    end
    if not candidate then
        break
    end
    laptop.toggle(operator, "link_join", candidate)
    t.run_ticks(2)
    joined += 1
    if joined > 8 then
        error("joins stall at " .. candidate)
    end
end
assert(joined == 1, "the released member rejoins")
assert(#members() == 5, "five again")
laptop.close(operator)
t.drop(operator)
t.run_ticks(2)
local since = airlock_cycle.mark()
local _ = t.messages(operator)
t.click(operator, 2, 3, assert(t.target_at(operator, 2, 3, "airlock_button")))
t.run_ticks(2)
airlock_cycle.until_door(5, true, operator, since, function()
    local p = assert(t.door_at(8, 3))
    if assert(t.door_at(5, 3)).open or assert(t.door_at(5, 3)).moving then
        assert(not p.open and not p.moving and p.bolted, "the east leaf stays bolted")
    end
end)
assert(#t.ledger_rows("link_accepted") >= 6, "the rejoin left its own row")
