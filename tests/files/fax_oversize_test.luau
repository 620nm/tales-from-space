local clock = require("@helpers/clock")
local ui_controls = require("@helpers/ui_controls")

local laptop = require("@helpers/laptop")
local ui_files = require("@helpers/ui_files")

-- A guest sends the fax two bounded prints: 8193 bytes, one over the payload
-- bound, then exactly 8192. The fax refuses the first with fax.failed and
-- prints nothing, spends nothing and stays idle; it prints the second. The
-- guest opens the joined door only on the refusal.
local PROGRAM = "local n = mem('presses') or 0 "
    .. "if event.kind == 'button' then "
    .. "local d for _, row in ipairs(directory) do if row.service == 'fax.print' then d = row end end "
    .. "if d == nil then return { commands = {}, status = 'fault' } end "
    .. "mem('presses', n + 1) "
    .. "local chunks = { string.rep('a', 4096), string.rep('a', 4096) } "
    .. "if n == 0 then table.insert(chunks, 'a') end "
    .. "return { commands = {{ op = 'service', id = 'print', to = d.mac, "
    .. "service = 'fax.print', request = true, payload = { chunks = chunks }}}, "
    .. "status = 'working', accepted = true } "
    .. "elseif event.kind == 'service' then "
    .. "if event.payload.kind ~= 'fax.failed' then return { commands = {}, status = 'idle' } end "
    .. "local c = {} for _, d in ipairs(devices) do if d.kind == 'door' then table.insert(c, { mac = d.mac, op = 'open', id = 'reply' }) end end "
    .. "return { commands = c, status = 'idle' } "
    .. "end return { commands = {} }"

t.world(
    [==[ (
    name: "fax oversize",
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])), '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'G': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Generator)),
        'a': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        'o': (composition: (components: [(component: "station_base"), (component: "floor_tiles")]), fixture: Some(Outlet)),
    },
    rows: [
        "#############",
        "#Gao........#",
        "#...........#",
        "#############",
    ],
    structures: [
        (3, 1, "player_spawn", { "jobs": "assistant" }),
        (3, 2, "access_point", { "network_1": "network_card", "mount": "south" }),
        (3, 1, "airlock_button", { "mount": "north" }),
        (6, 1, "airlock"),
        (2, 1, "apc"),
    ],
    machines: [
        (4, 1, "network_router", { "network_1": "network_card" }),
        (1, 2, "fax", { "network_1": "network_card" }),
    ],
    links: [(4, 1, 3, 2), (3, 2, 1, 2), (3, 2, 3, 1), (3, 2, 6, 1)],
    items: [(3, 1, "laptop")],
    networks: [
        (x: 1, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 2, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 2, y: 1, network: "power", channel: "l2", kind: "cable", facing: 15),
        (x: 3, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 4, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 5, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 6, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 7, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 8, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 9, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 10, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 11, y: 1, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 3, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 4, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 5, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
        (x: 8, y: 2, network: "power", channel: "l1", kind: "cable", facing: 15),
    ],
) ]==],
    0
)

local crew = t.join()
t.run_seconds(0.5)

local function node(player: number, suffix: string): ui_controls.Node
    return ui_controls.node(player, suffix)
end

-- Install the source through the laptop's actual contact and file panes.
laptop.ready(crew, 3, 1)
local connected = laptop.connect(crew, 3, 2, "access_point")
assert(connected ~= nil, "the laptop reaches the access point")
laptop.unlock(crew)
t.run_ticks(2)

-- The first row A PRESS CAN TAKE, each time round. This selector reads
-- no label, so it is the one place a candidate listed greyed -- drawn,
-- inert, carrying the reason the forest's shape refuses it
-- (../lunatic/docs/devices/joining.md) -- would be picked over and over
-- and never joined.
local joined = 0
while true do
    local offer = ui_controls.pressable(laptop.ui(crew), "link_join")[1]
    if offer == nil then
        break
    end
    local candidate = ui_controls.text(offer.option)
    laptop.toggle(crew, "link_join", candidate)
    t.run_ticks(2)
    joined += 1
    assert(joined < 8, "the AP candidate list terminates")
end
assert(joined > 0, "the laptop joins the controller button")

ui_files.create(crew, "host", "disl", "fax_controller")
t.run_ticks(2)
local uid = string.format("%d", ui_controls.number(ui_controls.record(laptop.ui(crew).open).uid))
t.run_seconds(0.5) -- the pacing window on text acts (docs/TGUI.md)
ui_files.save(crew, PROGRAM)
t.run_ticks(2)
assert(ui_controls.record(laptop.ui(crew).open).body == PROGRAM, "the source is saved on the AP")
ui_files.program(crew, "controller", uid)
t.run_ticks(2)
assert(
    ui_controls.record(ui_controls.rows(laptop.ui(crew).program_slots)[1].state).id
        == "program_slots.state.loaded",
    "the controller slot accepts the player-authored guest"
)
laptop.close(crew)
t.drop(crew)
t.run_ticks(2)

-- Advertise the reachable fax through its player UI before pressing.
t.move(crew, "west")
t.run_ticks(2)
t.move(crew, "west")
t.run_ticks(2)
t.move(crew, "south")
t.run_ticks(2)
local remote_fax = assert(t.target_at(crew, 1, 2, "fax"))
t.click(crew, 1, 2, remote_fax)
t.run_ticks(2)
t.ui_edit(crew, node(crew, "/controls/name").id, "Controller Fax")
t.ui_press(crew, node(crew, "/controls/name/set").id)
t.run_ticks(2)
t.ui_press(crew, node(crew, "/controls/advertise").id)
t.run_ticks(4)
t.ui_close(crew, "fax")
t.move(crew, "north")
t.run_ticks(2)
t.move(crew, "east")
t.run_ticks(2)
t.move(crew, "east")
t.run_ticks(2)

-- First press: 8193 bytes.
t.click(crew, 3, 1, assert(t.target_at(crew, 3, 1, "airlock_button")))
t.run_ticks(clock.deadline_ticks(0.5))
assert(#t.items_at(1, 2) == 0, "the oversize print makes no sheet")
t.run_ticks(clock.deadline_ticks(0.6) + 2)
assert(assert(t.door_at(6, 1)).open, "the guest heard fax.failed and opened the door")
t.run_ticks(clock.deadline_ticks(2.0))
assert(#t.items_at(1, 2) == 0, "nothing prints after the refusal either")

-- Second press: exactly 8192 bytes prints.
t.click(crew, 3, 1, assert(t.target_at(crew, 3, 1, "airlock_button")))
t.run_ticks(clock.deadline_ticks(2.0) + 4)
assert(t.items_at(1, 2)[1] == "paper", "the bound itself is accepted")

t.move(crew, "west")
t.run_ticks(2)
t.move(crew, "west")
t.run_ticks(2)
t.click(crew, 1, 2, assert(t.target_at(crew, 1, 2, "fax")))
t.run_ticks(2)
local panel = ui_controls.record(t.ui(crew, "fax"))
local data =
    ui_controls.record(panel.script and ui_controls.record(panel.script).data or panel.data)
assert(data.paper == 29 and data.toner == 29, "only the accepted print was charged")
assert(data.busy ~= true, "the fax is idle")
