-- A wall sensor joins an access point and reads its own tile.
-- The hub takes the sensor class; the standing answer is calm here.
-- (Vacuum reads deadly cold through the same instrument: the lock's
-- own leaves prove it every round, hazard none against deadly.)
local MAP = [==[
(
    name: "Sensor Shelf",
    environment: (gravity_m_s2: Exact(9.80665)),
    legend: {
        '.': (composition: (components: [(component: "station_base")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'G': (composition: (components: [(component: "station_base")]), fixture: Some(Generator)),
        'A': (composition: (components: [(component: "station_base")])),
        'o': (composition: (components: [(component: "station_base")]), fixture: Some(Outlet)),
    },
    rows: ["#####","#..o#","#GA.#","#...#","#####"],
    blends: {},
    painted: [],
    structures: [
        (1, 1, "player_spawn", { "jobs": "assistant" }),
        (1, 3, "player_spawn", { "jobs": "engineer" }),
        (2, 1, "access_point", { "network_1": "network_card", "file.airlock_controller": true, "program.controller": "airlock_controller", "mount": "north" }),
        (2, 3, "air_alarm", { "access": "engineering", "network_1": "network_card", "mount": "south" }),
        (1, 1, "air_sensor", { "mount": "north" }),
        (2, 2, "apc"),
    ],
    links: [(2, 1, 1, 1)],
    networks: [
        (x: 1, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 2, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 2, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 3, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 3, network: "power", channel: "l1", kind: "cable", facing: 15),
    ],
    items: [(1, 1, "laptop")],
)
]==]
local laptop = require("@helpers/laptop")
local ui_controls = require("@helpers/ui_controls")
t.set_breathing(false)
t.world(MAP, 0)
local operator = t.join("assistant")
local engineer = t.join("engineer")
t.run_ticks(20)

-- The hub takes the instrument: at least one acceptance, no refusal.
-- (The lock's own program faults here on purpose: one sensor is not
-- two leaves, a fan and two buttons, so the count refuses it.)
local accepted = #t.ledger_rows("link_accepted")
assert(accepted >= 1, "the access point takes the sensor class")
assert(#t.ledger_rows("link_denied") == 0, "no refusal")

-- Self-sensing: the tile it hangs on, read live.
assert(t.hazard_level(1, 1) == "none", "the room reads calm")
assert((t.room_pressure(1, 1) or 0) >= 85, "the room holds pressure")

-- The alarm refuses it: a refused class is never offered, so the
-- sensor's address is what the rest of this file needs. Read it off
-- the hub's own roster through the laptop.
laptop.ready(operator, 1, 1)
laptop.connect(operator, 2, 1, "access_point")
laptop.unlock(operator)
t.run_ticks(2)
local held = {}
for _, row in ipairs(ui_controls.rows(laptop.ui(operator).toggles or {})) do
    if row.field == "link_drop" then
        table.insert(held, ui_controls.text(row.option))
    end
end
assert(#held == 1, "the hub holds only the sensor: " .. #held)
laptop.close(operator)
t.drop(operator)
t.run_ticks(2)

-- The engineer opens the alarm and finds no such candidate.
t.click(engineer, 2, 3, assert(t.target_at(engineer, 2, 3, "air_alarm")))
t.run_ticks(2)
ui_controls.toggle(engineer, "link_lock")
t.run_ticks(2)
local panel = ui_controls.state(engineer)
local locks: { ui_controls.Record } = {}
for _, row in ipairs(ui_controls.rows(panel.toggles or {})) do
    if row.field == "link_lock" then
        table.insert(locks, row)
    end
end
assert(#locks >= 1 and locks[1].on, "engineering's claim opens it")
for _, row in ipairs(ui_controls.rows(panel.toggles or {})) do
    if row.field == "link_join" then
        assert(
            ui_controls.text(row.option) ~= held[1],
            "the sensor class is not on offer"
        )
    end
    assert(row.field ~= "link_drop", "the alarm holds nobody")
end
