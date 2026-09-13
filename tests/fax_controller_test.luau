-- A player installs an AP guest that prints through a reachable fax service.
-- The press, addressed request, native 40-tick job, and reply all cross the
-- player-facing seams; no script handle is supplied by the fixture.
local PROGRAM = "if event.kind == 'button' then "
    .. "local d = directory[1] local print_ad = false local send_ad = false "
    .. "for _, row in ipairs(directory) do print_ad = print_ad or row.service == 'fax.print'; send_ad = send_ad or row.service == 'fax.send' end "
    .. "if d == nil or not print_ad or not send_ad then return { commands = {}, status = 'fault' } end "
    .. "return { commands = {{ op = 'service', id = 'print', to = d.mac, "
    .. "service = 'fax.print', request = true, payload = { chunks = {string.rep('a', 4093) .. '€', 'tail'} }}}, "
    .. "status = 'working', accepted = true } "
    .. "elseif event.kind == 'service' then "
    .. "if event.payload.kind ~= 'fax.printed' then return { commands = {}, status = 'fault' } end "
    .. "local c = {} for _, d in ipairs(devices) do if d.kind == 'door' then table.insert(c, { mac = d.mac, op = 'open', id = 'reply' }) end end "
    .. "return { commands = c, status = 'idle' } "
    .. "end return { commands = {} }"

t.world([==[ (
    name: "fax controller",
    legend: {
        '.': (turf: Floor), '#': (turf: Wall),
        'G': (turf: Floor, fixture: Some(Generator)),
        'a': (turf: Floor, fixture: Some(Apc)),
        'o': (turf: Floor, fixture: Some(Outlet)),
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
    ],
    machines: [
        (4, 1, "network_router", { "network_1": "network_card" }),
        (1, 2, "fax", { "network_1": "network_card" }),
    ],
    links: [(4, 1, 3, 2), (3, 2, 1, 2), (3, 2, 3, 1), (3, 2, 6, 1)],
    items: [(3, 1, "laptop")],
    cables: [
        (1, 1, 2), (2, 1, 3), (3, 1, 1), (4, 1, 1),
        (5, 1, 1), (6, 1, 1), (7, 1, 1), (8, 1, 1),
        (9, 1, 1), (10, 1, 1), (11, 1, 1),
        (3, 2, 1), (4, 2, 1), (5, 2, 1), (8, 2, 1),
    ],
) ]==], 0)

local crew = t.join()
t.run_ticks(10)

local function node(player, suffix)
    local found
    local function visit(value)
        if type(value) ~= "table" then return end
        if found == nil and type(value.id) == "string" and value.id:sub(-#suffix) == suffix then found = value end
        for _, child in pairs(value) do visit(child) end
    end
    visit(t.ui_tree(player))
    return assert(found, "missing UI control " .. suffix)
end

-- Install the source through the laptop's actual contact and file panes.
laptop.ready(crew, 3, 1)
local connected = laptop.connect(crew, 3, 2, "access_point")
assert(connected ~= nil, "the laptop reaches the access point")
laptop.unlock(crew)
t.run_ticks(2)

local joined = 0
while true do
    local candidate
    for _, row in ipairs(laptop.ui(crew).toggles or {}) do
        if row.field == "link_join" then
            candidate = row.option
            break
        end
    end
    if candidate == nil then break end
    laptop.toggle(crew, "link_join", candidate)
    t.run_ticks(2)
    joined += 1
    assert(joined < 8, "the AP candidate list terminates")
end
assert(joined > 0, "the laptop joins the controller button")

ui_files.create(crew, "host", "disl", "fax_controller")
t.run_ticks(2)
local uid = string.format("%d", laptop.ui(crew).open.uid)
t.run_ticks(10)
ui_files.save(crew, PROGRAM)
t.run_ticks(2)
assert(laptop.ui(crew).open.body == PROGRAM, "the source is saved on the AP")
ui_files.program(crew, "controller", uid)
t.run_ticks(2)
assert(laptop.ui(crew).program_slots[1].state.id == "program_slots.state.loaded",
    "the controller slot accepts the player-authored guest")
laptop.close(crew)
t.drop(crew)
t.run_ticks(2)

-- Advertise the reachable fax through its player UI before pressing.
t.move(crew, "west"); t.run_ticks(2)
t.move(crew, "west"); t.run_ticks(2)
t.move(crew, "south"); t.run_ticks(2)
local remote_fax = assert(t.target_at(crew, 1, 2, "fax"))
t.click(crew, 1, 2, remote_fax)
t.run_ticks(2)
t.ui_edit(crew, node(crew, "/controls/name").id, "Controller Fax")
t.ui_press(crew, node(crew, "/controls/name/set").id)
t.run_ticks(2)
t.ui_press(crew, node(crew, "/controls/advertise").id)
t.run_ticks(4)
t.ui_close(crew, "fax")
t.move(crew, "north"); t.run_ticks(2)
t.move(crew, "east"); t.run_ticks(2)
t.move(crew, "east"); t.run_ticks(2)

-- One player press starts the addressed fax.print job.
t.click(crew, 3, 1, assert(t.target_at(crew, 3, 1, "airlock_button")))
t.run_ticks(1)
local heard = table.concat(t.messages(crew), " | ")
assert(heard == "", "button routing: " .. heard)
assert(#t.items_at(1, 2) == 0, "the fax has no output before its job completes")
t.run_ticks(39)
assert(#t.items_at(1, 2) == 0, "the print job still runs through tick 39")
t.run_ticks(1)
assert(t.items_at(1, 2)[1] == "paper", "the fax ejects fresh paper at tick 40")
t.run_ticks(10) -- delivery, command completion, then the door animation
local replying_door = t.door_at(6, 1)
assert(replying_door.moving and not replying_door.open,
    "the correlated fax.printed callback starts the joined door")
t.run_ticks(12)
assert(t.door_at(6, 1).open, "the door becomes passable after its swing")

-- The input crosses the 4096-byte boundary with a three-byte codepoint. The
-- received paper proves the service chunker retained the complete character.
t.move(crew, "west"); t.run_ticks(2)
t.move(crew, "west"); t.run_ticks(2)
t.move(crew, "south"); t.run_ticks(2)
local printed = assert(t.target_at(crew, 1, 2, "paper"), "printed paper is readable")
t.click(crew, 1, 2, printed)
t.run_ticks(2)
local printed_window = assert(t.ui(crew, "writing"), "printed paper opens")
local printed_data = printed_window.script and printed_window.script.data or printed_window.data
local expected = string.rep("a", 4093) .. "€" .. "tail"
local received = {}
for _, fragment in ipairs(printed_data.committed or {}) do table.insert(received, fragment.text) end
local actual = table.concat(received)
assert(actual == expected, "multibyte fax text survives service chunking: bytes=" .. #actual .. ", expected=" .. #expected .. ", tail=" .. actual:sub(-16))
t.ui_close(crew, "writing")
t.drop(crew)
t.run_ticks(1)

local fax = assert(t.target_at(crew, 1, 2, "fax"))
t.click(crew, 1, 2, fax)
t.run_ticks(2)
local panel = t.ui(crew, "fax")
local data = panel.script and panel.script.data or panel.data
assert(data.paper == 29 and data.toner == 29, "printing debits one paper and one toner")
