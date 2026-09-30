local clock = require("@helpers/clock")
local ui_controls = require("@helpers/ui_controls")

local laptop = require("@helpers/laptop")
local ui_files = require("@helpers/ui_files")

-- A player installs an AP guest that asks one named fax to send its loaded
-- sheet to another. The addressed fax.send request, the scan, the recipient's
-- own print and the fax.sent verdict all cross the player-facing seams; the
-- guest holds no handle and hears fax.sent only after the page has landed.
local PROGRAM = "if event.kind == 'button' then "
    .. "local src local dst "
    .. "for _, row in ipairs(directory) do if row.service == 'fax.send' then "
    .. "if row.name == 'Alpha Fax' then src = row end "
    .. "if row.name == 'Beta Fax' then dst = row end end end "
    .. "if src == nil or dst == nil then return { commands = {}, status = 'fault' } end "
    .. "return { commands = {{ op = 'service', id = 'send', to = src.mac, "
    .. "service = 'fax.send', request = true, payload = { to = dst.mac } }}, "
    .. "status = 'working', accepted = true } "
    .. "elseif event.kind == 'service' then "
    .. "if event.payload.kind ~= 'fax.sent' then return { commands = {}, status = 'fault' } end "
    .. "local c = {} for _, d in ipairs(devices) do if d.kind == 'door' then table.insert(c, { mac = d.mac, op = 'open', id = 'reply' }) end end "
    .. "return { commands = c, status = 'idle' } "
    .. "end return { commands = {} }"

t.world(
    [==[ (
    name: "fax send request",
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
        (2, 2, "fax", { "network_1": "network_card" }),
    ],
    links: [(4, 1, 3, 2), (3, 2, 1, 2), (3, 2, 2, 2), (3, 2, 3, 1), (3, 2, 6, 1)],
    items: [(3, 1, "laptop"), (1, 1, "paper")],
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

-- Name and advertise both faxes through their player UI, then load Alpha's
-- sheet: only Alpha holds one, so the guest's request names the sender.
local function advertise(x: number, y: number, name: string)
    local fax = assert(t.target_at(crew, x, y, "fax"))
    t.click(crew, x, y, fax)
    t.run_ticks(2)
    t.ui_edit(crew, node(crew, "/controls/name").id, name)
    t.ui_press(crew, node(crew, "/controls/name/set").id)
    t.run_ticks(2)
    t.ui_press(crew, node(crew, "/controls/advertise").id)
    t.run_ticks(4)
    t.ui_close(crew, "fax")
end

t.move(crew, "west")
t.run_ticks(2)
t.move(crew, "west")
t.run_ticks(2)
advertise(1, 2, "Alpha Fax")
advertise(2, 2, "Beta Fax")

local alpha = assert(t.target_at(crew, 1, 2, "fax"))
t.click(crew, 1, 2, alpha)
t.run_ticks(2)
local sheet = assert(t.target_at(crew, 1, 1, "paper"), "Alpha's sheet is on the floor")
t.click(crew, 1, 1, sheet)
t.run_ticks(1)
t.click(crew, 1, 2, alpha)
t.run_ticks(2)
assert(t.hands(crew).held == nil, "Alpha takes its sheet")
t.ui_close(crew, "fax")
t.move(crew, "east")
t.run_ticks(2)
t.move(crew, "east")
t.run_ticks(2)

-- One player press asks Alpha to send its loaded sheet to Beta.
t.click(crew, 3, 1, assert(t.target_at(crew, 3, 1, "airlock_button")))
t.run_ticks(clock.deadline_ticks(2.0) - 1)
assert(#t.items_at(2, 2) == 0, "Beta has printed nothing before the scan's deadline")
local landed = false
for _ = 1, 12 do -- the request crosses the network before Alpha's scan starts
    t.run_ticks(1)
    if #t.items_at(2, 2) > 0 then
        landed = true
        break
    end
end
assert(landed and t.items_at(2, 2)[1] == "paper", "Beta's own queue prints the received sheet")
assert(t.items_at(1, 2)[1] == "paper", "Alpha ejects its source on Beta's page tick")

-- fax.sent is Beta's page result relayed by Alpha: it cannot reach the guest
-- on the tick the page lands, only after.
local door = assert(t.door_at(6, 1))
assert(not door.moving and not door.open, "no verdict has reached the guest yet")
t.run_ticks(clock.deadline_ticks(0.5) + clock.deadline_ticks(0.6) + 2)
assert(assert(t.door_at(6, 1)).open, "the fax.sent verdict opens the joined door")

-- Beta spent its own stock; Alpha spent none.
t.move(crew, "west")
t.run_ticks(2)
t.move(crew, "west")
t.run_ticks(2)
t.click(crew, 2, 2, assert(t.target_at(crew, 2, 2, "fax")))
t.run_ticks(2)
local beta_panel = ui_controls.record(t.ui(crew, "fax"))
local beta_view = ui_controls.record(
    beta_panel.script and ui_controls.record(beta_panel.script).data or beta_panel.data
)
assert(beta_view.paper == 29 and beta_view.toner == 29, "the recipient charged its own stock")
