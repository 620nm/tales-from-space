-- The door a controller drives answers to the guest, not to its own
-- access tag (docs/scripting/controllers.md, "Who a door answers to").
--
-- `content/fixtures/airlock.luau` allows every actor-less
-- `door.permission` request, and a program's command carries no actor.
-- So: one leaf, one empty-handed crewman, two paths. By hand the
-- engineering tag refuses them; through the host the same leaf opens
-- for the same hand. The gate on the second path is reaching the box
-- and loading a program -- the panel's lock and the host's own `access`
-- word -- and this host, placed with none, has no key to ask for.
--
-- The order matters and is the regression this pins: the hand's
-- refusal runs the same transform the command does. A transform that
-- answers a hand with nothing faults, and a faulted station is disabled
-- for the round -- which would take the grant with it and leave every
-- controller unable to work a keyed door.
--
-- The guest is the shortest one that answers the question: a press
-- opens every joined door. The shipped cycle program
-- (reference/scripts/airlock.luau) is programmable_airlock_test.luau's.

-- Authored straight onto the host's own `files`/`editor` panes, the
-- short route the box already carries: the laptop contact in
-- programmable_airlock_test.luau is there to fetch the DISK's fixed
-- original, and nothing here wants an original.
local PROGRAM = "if event.kind ~= 'button' then return { commands = {} } end "
    .. "local c = {} "
    .. "for _, d in ipairs(devices) do "
    .. "if d.kind == 'door' then table.insert(c, { mac = d.mac, op = 'open', id = 'open' }) end "
    .. "end "
    .. "return { commands = c, accepted = true, status = 'idle' }"

t.world([==[(
    name: "keyed doorway",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        'G': (turf: Floor, fixture: Some(Generator)),
        'A': (turf: Floor, fixture: Some(Apc)),
        'o': (turf: Floor, fixture: Some(Outlet)),
    },
    rows: [
        "#########",
        "#.......#",
        "#GAo....#",
        "#########",
    ],
    spawns: [(5, 1)],
    structures: [
        (4, 2, "access_point", { "network_1": "network_card" }),
        (6, 2, "airlock_button"),
        (6, 1, "airlock.engineering"),
    ],
    mounts: [(4, 2, South), (6, 2, South)],
    cables: [
        (1, 2, 2), (2, 2, 3), (3, 2, 1), (4, 2, 1), (5, 2, 1), (6, 2, 1),
        (6, 1, 1),
    ],
)]==], 7)

local crew = t.join()
t.run_ticks(20)

local function ui()
    local doc = t.ui(crew)
    assert(doc ~= nil, "the host's window is open")
    return doc
end
local function rows(doc, field)
    local out = {}
    for _, row in ipairs(doc.toggles or {}) do
        if row.field == field then table.insert(out, row) end
    end
    return out
end

-- The leaf carries engineering's claim and is powered, shut and free to
-- move, so nothing but the claim can be what stops a hand.
assert(t.structure_at(6, 1).id == "airlock.engineering", "the variant that says `access`")
local door = t.door_at(6, 1)
assert(door.powered and not door.open and not door.bolted, "powered, shut, unbolted")

-- ---- by hand: refused ----------------------------------------------------
t.click(crew, 6, 1, t.target_at(6, 1))
t.run_ticks(4)
assert(not t.door_at(6, 1).open, "an empty-handed crewman does not get it open")
local denied = t.ledger_rows("door_denied")
assert(#denied == 1, "and the refusal is on the record: " .. #denied)
assert(denied[1].at[1] == 6 and denied[1].at[2] == 1, "at the leaf's own tile")
assert(#t.ledger_rows("script_error") == 0, "answering a hand is not a fault")

-- ---- install policy on the host ------------------------------------------
-- Placed with no `access` word, the lock opens for whoever is standing
-- at it (tests/hardwire_test.luau).
t.click(crew, 4, 2, t.target_at(4, 2, "access_point"))
t.run_ticks(2)
t.ui_act(crew, "toggle", '{"field":"link_lock"}')
t.run_ticks(2)
assert(rows(ui(), "link_lock")[1].on, "an unkeyed host opens for an empty hand")

local joined = 0
while true do
    local candidate
    for _, row in ipairs(rows(ui(), "link_join")) do
        if row.label.id == "link.candidate.endpoint" then candidate = row.option break end
    end
    if not candidate then break end
    t.ui_act(crew, "toggle", '{"field":"link_join","option":"' .. candidate .. '"}')
    t.run_ticks(2)
    joined += 1
    assert(joined <= 2, "only the door and the button are in reach")
end
assert(joined == 2, "the door and the button hang off the host: " .. joined)

local store = ui().stores[1].binding
t.ui_act(crew, "text", '{"field":"file_create","option":"host:disl:' .. store .. '","text":"opener"}')
t.run_ticks(2)
local uid = string.format("%d", ui().open.uid)
t.run_ticks(10) -- the pacing window on text acts (docs/TGUI.md)
t.ui_act(crew, "text", '{"field":"file_save","option":"host:' .. uid .. ':' .. store
    .. '","text":"' .. PROGRAM .. '","revision":0}')
t.run_ticks(2)
assert(ui().open.body == PROGRAM, "the guest's source is on the host's own disk")
t.ui_act(crew, "toggle", '{"field":"socket_load","option":"controller:' .. uid .. ':' .. store .. '"}')
t.run_ticks(2)
assert(ui().sockets[1].state.id == "sockets.state.bound", "and the controller socket runs it")
t.ui_close(crew)
t.run_ticks(2)

-- ---- through the host: opened --------------------------------------------
t.click(crew, 6, 2, t.target_at(6, 2, "airlock_button"))
t.run_ticks(20)
assert(t.door_at(6, 1).open, "the program opened the tagged door for the hand it just refused")
assert(#t.ledger_rows("door_denied") == 1, "and refused nothing on the way")

-- The presser carried no claim and the guest was told so: the leaf
-- opened despite `engineering = false`, not because of it.
local press
for _, row in ipairs(t.ledger_rows("disl_run")) do
    local event = row.env.Map.event.Map
    if event.kind.String == "button" then press = event end
end
assert(press ~= nil, "the press reached the guest")
assert(press.engineering.Bool == false, "with the presser's missing claim spelled out")
