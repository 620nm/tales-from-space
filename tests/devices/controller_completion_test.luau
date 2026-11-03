-- Every order a guest issues is answered to the guest once, even when two
-- orders share one request id (docs/construction/scripted-doors.md). The
-- reference airlock's `seal()` (reference/scripts/airlock.luau) does exactly
-- this: a bolt and an emergency latch, one id, one door.
--
-- The guest here is the shortest one that can tell: a press sends both
-- latch orders under the id `seal`, and only the EMERGENCY completion makes
-- it bolt the door. A controller that settled the second completion away
-- would leave the door unbolted.
local DOOR_X = 6
local DOOR_Y = 1
local PROGRAM = [==[
local c = {}
if event.kind == 'button' then
  for _, d in ipairs(devices) do
    if d.kind == 'door' then
      table.insert(c, { mac = d.mac, op = 'bolt', bolted = false, id = 'seal' })
      table.insert(c, { mac = d.mac, op = 'emergency', emergency = true, id = 'seal' })
    end
  end
  return { commands = c, accepted = true, status = 'working' }
end
if event.kind == 'door' and event.operation == 'set_emergency' and event.id == 'seal' then
  table.insert(c, { mac = event.mac, op = 'bolt', bolted = true, id = 'after' })
  return { commands = c, status = 'idle' }
end
return { commands = c }
]==]

t.world(
    [==[(
    name: "shared id seal",
    files: {
        "sealer": (name: "sealer", ext: "disl", body: r#"]==] .. PROGRAM .. [==[
"#),
    },
    legend: {
        ' ': (composition: (substrate: Named("space"))),
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'G': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Generator)),
        'A': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        'o': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Outlet)),
    },
    levels: [
        (
            rows: [
                "#########",
                "#.......#",
                "#GAo....#",
                "#########",
            ],
            structures: [
                (5, 1, "player_spawn"),
                (4, 2, "access_point", { "network_1": "network_card", "file.sealer": true, "program.controller": "sealer", "mount": "south" }),
                (6, 2, "airlock_button", { "mount": "south" }),
                (6, 1, "airlock"),
                (2, 2, "apc"),
            ],
            links: [(4, 2, 6, 2), (4, 2, 6, 1)],
            networks: [
                (x: 1, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
                (x: 2, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
                (x: 2, y: 2, network: "power", channel: "l2", kind: "cable", facing: 15),
                (x: 3, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
                (x: 4, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
                (x: 5, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
                (x: 6, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
                (x: 6, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
            ],
        ),
    ],
)]==],
    0
)

local crew = t.join()
t.run_seconds(1.0)
local door = assert(t.door_at(DOOR_X, DOOR_Y))
assert(not door.latches.bolted and not door.latches.emergency, "the leaf starts with neither latch")

-- An unsolicited completion: a hand works the leaf the program never
-- ordered. Its completion reaches the door's scope, and `settle` keeps
-- it from the guest.
local runs_before = #t.ledger_rows("disl_run")
t.click(crew, DOOR_X, DOOR_Y, assert(t.target_at(crew, DOOR_X, DOOR_Y, "airlock")))
t.run_seconds(2.0)
assert(assert(t.door_at(DOOR_X, DOOR_Y)).open, "a hand opened the leaf")
t.click(crew, DOOR_X, DOOR_Y, assert(t.target_at(crew, DOOR_X, DOOR_Y, "airlock")))
t.run_seconds(2.0)
assert(not assert(t.door_at(DOOR_X, DOOR_Y)).open, "and closed it again")
assert(#t.ledger_rows("disl_run") == runs_before, "the guest heard nothing of a hand's door")

t.click(crew, 6, 2, assert(t.target_at(crew, 6, 2, "airlock_button")))
-- Two paced guest packets: the press, then the completions that follow it.
t.run_seconds(3.0)

door = assert(t.door_at(DOOR_X, DOOR_Y))
assert(door.latches.emergency, "the guest's second order, the emergency latch, landed")
assert(
    door.latches.bolted,
    "the emergency completion reached the guest despite sharing the bolt's id"
)
assert(#t.script_errors() == 0, "no handler faulted on the way")
assert(#t.ledger_rows("disl_fault") == 0, "and the guest never faulted")
