-- Rebuild the commissioned bench by hand: release, rejoin, reinstall, then operate it.
-- Keep this test's map local so its two candidate points can be assigned to
-- distinct jobs without changing the shipped map's weighted pool.
local AIRLOCK = [==[
(
    name: "Programmable Exterior Airlock",
    environment: (gravity_m_s2: Exact(9.80665)),
    legend: {
        ' ': (turf: Space), '.': (turf: Plating), '#': (turf: Wall),
        'G': (turf: Plating, fixture: Some(Generator)),
        'A': (turf: Plating, fixture: Some(Apc)),
        'o': (turf: Plating, fixture: Some(Outlet)),
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
        (4, 3, "access_point", { "network_1": "network_card", "file.airlock_controller": true, "program.controller": "airlock_controller" }),
        (2, 3, "airlock_button"), (7, 4, "airlock_button"),
        (5, 3, "airlock", { "bolted": true }),
        (8, 3, "airlock", { "open": true, "bolted": false }),
        (6, 3, "airlock_pump", { "dir": "north" }),
        (6, 1, "passive_vent", { "layer": 4, "pipe": "south" }),
        (8, 1, "passive_vent", { "layer": 2, "pipe": "south" }),
    ],
    mounts: [(4, 3, North), (2, 3, North), (7, 4, South)],
    links: [
        (4, 3, 2, 3), (4, 3, 5, 3), (4, 3, 6, 3),
        (4, 3, 8, 3), (4, 3, 7, 4),
    ],
    pipes: [(6, 2, 8), (6, 2, 2), (7, 2, 2), (8, 2, 2)],
    cables: [(1, 4, 2), (2, 4, 3), (3, 4, 1), (4, 4, 1),
        (2, 3, 1), (3, 3, 1), (4, 3, 1), (5, 3, 1),
        (6, 3, 1), (7, 3, 1), (8, 3, 1)],
    items: [(3, 3, "laptop"), (3, 3, "floppy_disk.atmos_stock"),
        (2, 4, "disk_box"), (3, 4, "screwdriver"), (3, 4, "wrench"),
        (3, 4, "airlock_button_fitting"), (3, 4, "airlock_pump_fitting")],
)
]==]
t.set_breathing(false)
t.world(AIRLOCK, 0)
t.set_environment({ sink_k = 293.15, insolation = 0 })
local operator = t.join("assistant")
local visitor = t.join("engineer")
t.run_ticks(20)
local host = t.target_at(operator, 4, 3, "access_point")
local lap = t.target_at(operator, 3, 3, "laptop")
assert(t.door_at(5, 3).bolted and not t.door_at(5, 3).open, "interior starts closed and bolted")
assert(t.door_at(8, 3).open and not t.door_at(8, 3).bolted, "exterior starts open and unbolted")
assert(t.room_pressure(6, 3) < 1, "the chamber starts evacuated")

-- The map joined every endpoint to a host that boots locked. A laptop held
-- against it meets the lock screen; unlocking goes straight to the members.
local function members()
    local rows = {}
    for _, row in ipairs(laptop.ui(operator).toggles or {}) do
        if row.field == "link_drop" then table.insert(rows, row.option) end
    end
    return rows
end
laptop.ready(operator, 3, 3)
local locked = laptop.connect(operator, 4, 3, host)
assert(locked and locked.contact_locked, "the shipped host shows a laptop its lock screen first")
assert(locked.stores == nil and #members() == 0, "with nothing behind the lock")
laptop.unlock(operator)
t.run_ticks(2)
assert(not laptop.ui(operator).contact_locked, "unlocking goes straight into the workspace")
assert(#members() == 5, "the map joined two doors, two buttons and the vent: " .. #members())
for dropped = 1, 5 do
    laptop.toggle(operator, "link_drop", members()[1])
    t.run_ticks(2)
    assert(#members() == 5 - dropped, "each release removes one member")
end
laptop.close(operator)
t.drop(operator)
t.run_ticks(2)
local _ = t.messages(operator)
t.click(operator, 2, 3, assert(t.target_at(operator, 2, 3, "airlock_button")))
t.run_ticks(2)
local heard = table.concat(t.messages(operator), " | ")
assert(heard:find("The button clicks, but nothing answers.", 1, true), "a released button has nobody to ask: " .. heard)

-- Rejoin the same endpoints through the laptop; the lock is already open.
laptop.take(operator, 3, 3)
laptop.connect(operator, 4, 3, host)
local joined = 0
while true do
    local candidate
    for _, row in ipairs(laptop.ui(operator).toggles or {}) do
        if row.field == "link_join" and row.label.id == "link.candidate.endpoint" then candidate = row.option; break end
    end
    if not candidate then break end
    laptop.toggle(operator, "link_join", candidate)
    t.run_ticks(2)
    joined += 1
    if joined > 8 then
        local facts = {}
        for _, row in ipairs(laptop.ui(operator).readouts or {}) do
            table.insert(facts, tostring(row.label.id) .. "=" .. tostring(row.value.id or row.value.text))
        end
        for _, row in ipairs(t.ledger_rows("link_denied")) do table.insert(facts, "denied=" .. tostring(row.why)) end
        error("joins make progress " .. candidate .. " " .. table.concat(facts, " | "))
    end
end
assert(joined == 5, "two doors, two buttons and one vent join the same host")
laptop.close(operator)

local function workspace()
    local ui = t.ui(operator, "programming")
    assert(ui and ui.program_slots, "the contact workspace belongs to the target")
    return ui
end
local function file(ui, side)
    for _, row in ipairs(ui.files) do if row.store == side and row.name == "airlock" then return row end end
end

-- The distribution disk goes into the laptop, whose desktop copies its
-- fixed original onto the laptop's own store: its A:, `tool_host` in contact.
t.drop(operator)
t.run_ticks(2)
t.click(operator, 3, 3, t.target_at(operator, 3, 3, "floppy_disk.atmos_stock"))
t.run_ticks(2)
t.click(operator, 3, 3, assert(t.target_at(operator, 3, 3, lap)))
t.run_ticks(2)
t.use_item(operator, assert(t.target_at(operator, 3, 3, lap)), "secondary")
t.run_ticks(2)
local disk = file(t.ui(operator), "media")
assert(disk and disk.fixed, "the distribution disk contains a fixed original")
t.run_ticks(10)
ui_files.press(operator, disk, "copy")
t.run_ticks(2)
assert(file(t.ui(operator), "host"), "the laptop keeps an editable copy")
t.ui_close(operator)
t.run_ticks(2)
laptop.take(operator, 3, 3)
laptop.connect(operator, 4, 3, host)

local ui = workspace()
local shipped = file(ui, "host")
assert(shipped and not shipped.fixed and ui.program_slots[1].uid == shipped.uid,
    "the map installed an editable copy and loaded it into the slot")
-- A copy cannot land on a taken name, and a bound file cannot be deleted: unload, then delete.
ui_files.program(operator, "controller", nil)
t.run_ticks(10)
ui_files.press(operator, file(workspace(), "host"), "delete")
t.run_ticks(2)
assert(file(workspace(), "host") == nil, "the old copy is gone before the new one lands")
ui = workspace()
local original = file(ui, "tool_host")
assert(original and file(ui, "media") == nil, "the laptop's A: carries its copy; the host has no disk slot")
t.run_ticks(10)
ui_files.press(operator, original, "copy-host")
t.run_ticks(2)
ui = workspace()
local installed = file(ui, "host")
assert(installed and not installed.fixed, "the target copy is editable")
ui_files.press(operator, installed, "open")
t.run_ticks(2)
local source = workspace().open.body
assert(#source <= 8192 and source:find("local function permitted", 1, true), "the installed file is the guest controller source")
ui_files.program(operator, "controller", installed.uid)
t.run_ticks(2)
assert(workspace().program_slots[1].uid == installed.uid, "the controller slot runs the target copy")

local function close_contact()
    t.ui_close(operator, "programming")
    t.run_ticks(2)
    t.drop(operator)
    t.run_ticks(2)
end
close_contact()
local function press_inside()
    local px, py = t.pos(operator)
    assert(px == 3 and py == 3 and t.hands(operator).held == nil,
        "operator ready " .. px .. "," .. py .. " held=" .. tostring(t.hands(operator).held))
    local button = assert(t.target_at(operator, 2, 3, "airlock_button"), "the inside button is targetable")
    local offered = false
    for _, action in ipairs(t.action_hints(operator, { Entity = button })) do
        if action.id == "press" and action.gesture == "primary" then offered = true end
    end
    assert(offered, "the button offers its left-click press action")
    local mark = airlock_cycle.mark()
    t.click(operator, 2, 3, t.target_at(operator, 2, 3, "airlock_button"))
    t.run_ticks(2)
    return mark
end
-- Polled every tick: the visitor keeps (7, 3). While the watched door rests shut, the
-- four chamber tiles are recorded, so the record is the last tick before it moves; then
-- all four read at least 100 kPa (the interior) or below 10 (space). Rest re-arms it.
local CHAMBER = { { 6, 3 }, { 7, 3 }, { 6, 4 }, { 7, 4 } }
local function until_door(x, open, since, each)
    local last
    return airlock_cycle.until_door(x, open, operator, since, function()
        local vx, vy = t.pos(visitor)
        assert(vx == 7 and vy == 3, "the visitor keeps (7, 3): " .. vx .. "," .. vy)
        local d = t.door_at(x, 3)
        if not (d.open or d.moving) then
            last = {}
            for _, tile in ipairs(CHAMBER) do
                table.insert(last, { tile[1], tile[2], t.room_pressure(tile[1], tile[2]) })
            end
        elseif last then
            for _, row in ipairs(last) do
                assert(if x == 5 then row[3] >= 100 else row[3] < 10, "chamber tile " .. row[1] .. "," .. row[2]
                    .. " read " .. row[3] .. " kPa just before door " .. x .. " moved")
            end
            last = nil
        end
        if each then each() end
    end, 1)
end
-- Walk in through the initially open exterior, leaving both tracks clear.
for _ = 1, 2 do t.move(visitor, "west"); t.run_ticks(4) end
assert(t.pos(visitor) == 7, "the visitor stands in the chamber")
until_door(5, true, press_inside())
assert(t.door_at(8, 3).bolted and not t.door_at(8, 3).open, "the exterior is secured before the interior opens")
local pressure_result = airlock_cycle.pressure
assert(pressure_result() and pressure_result() >= 100,
    "the native pressure completion measures at least 100 kPa before opening")
t.run_ticks(100)
assert(t.door_at(5, 3).open, "bolting the open leaf holds it against autoclose")

-- The chamber button reverses the cycle: close, drain, then open space.
local since = airlock_cycle.mark()
t.click(visitor, 7, 4, t.target_at(visitor, 7, 4, "airlock_button"))
t.run_ticks(2)
until_door(8, true, since)
assert(t.door_at(5, 3).bolted and not t.door_at(5, 3).open, "the interior is secured before space opens")
assert(pressure_result() < 10, "the distinct effluent main evacuates below 10 kPa before opening")
assert((t.pipe_pressure(6, 2, 8) or 0) > (t.pipe_pressure(6, 2, 2) or 0), "intake and effluent remain distinct mains")

-- A repeat press of the same button requests the opposite destination.
since = press_inside()
t.run_ticks(8)
press_inside()
t.run_ticks(80)
until_door(8, true, since)
assert(not t.door_at(5, 3).open and pressure_result() < 10,
    "the same button reverses the pending cycle and drains before opening")
until_door(5, true, press_inside())

-- An opposite request during travel supersedes the older operation.
since = airlock_cycle.mark()
t.click(visitor, 7, 4, t.target_at(visitor, 7, 4, "airlock_button"))
t.run_ticks(8)
press_inside()
t.run_ticks(80)
until_door(5, true, since)
assert(not t.door_at(8, 3).open and pressure_result() >= 100,
    "an interrupted outward motor settles under the newer inward generation")

-- Both buttons advance the same alternating sequence through a paced burst.
local burst_start = #t.ledger_rows("disl_run")
press_inside() -- Start this sender's pacing sleep.
for _ = 1, 7 do t.click(operator, 2, 3, t.target_at(operator, 2, 3, "airlock_button")) end
t.tick()
t.click(visitor, 7, 4, t.target_at(visitor, 7, 4, "airlock_button"))
t.run_ticks(80)
until_door(8, true, burst_start)
assert(not t.door_at(5, 3).open and pressure_result() < 10,
    "nine accepted presses advance the same sequence to the exterior")
local burst_sequences, burst_count = {}, 0
local burst_rows = t.ledger_rows("disl_run")
for index = burst_start + 1, #burst_rows do
    local row = burst_rows[index]
    local event = row.env.Map.event.Map
    if event.kind.String == "button" and row.value.Map.accepted and row.value.Map.accepted.Bool then
        local sequence = event.sequence.Integer or event.sequence.Number
        assert(not burst_sequences[sequence], "a press is accepted only once")
        burst_sequences[sequence], burst_count = true, burst_count + 1
    end
end
assert(burst_count == 9, "all nine admitted presses survive batching and cross-button reordering: " .. burst_count)
until_door(5, true, press_inside())

-- Edit the installed source through the same contact and deny public requests.
t.click(operator, 3, 3, assert(t.target_at(operator, 3, 3, lap)))
t.run_ticks(2)
t.click(operator, 4, 3, assert(t.target_at(operator, 4, 3, host)))
t.run_ticks(2)
ui = workspace()
installed = file(ui, "host")
ui_files.press(operator, installed, "open")
t.run_ticks(2)
local denied = source:gsub("return true", "return false", 1)
t.run_ticks(10)
ui_files.save(operator, denied)
t.run_ticks(2)
assert(workspace().open.body == denied, "a running program is editable from the laptop")
close_contact()
local _ = t.messages(visitor)
since = airlock_cycle.mark()
t.click(visitor, 7, 4, t.target_at(visitor, 7, 4, "airlock_button"))
t.run_ticks(100)
assert(t.door_at(5, 3).open and not t.door_at(8, 3).open, "denied requests leave the completed state alone")
assert(#t.ledger_rows("disl_run") > since, "the denied press reached the guest")
local refusal = table.concat(t.messages(visitor), " | ")
assert(refusal:find("The controller refuses your airlock request.", 1, true), "the presser hears the refusal: " .. refusal)

local function edit_program(body)
    t.click(operator, 3, 3, assert(t.target_at(operator, 3, 3, lap)))
    t.run_ticks(2)
    t.click(operator, 4, 3, assert(t.target_at(operator, 4, 3, host)))
    t.run_ticks(2)
    local current = file(workspace(), "host")
    ui_files.press(operator, current, "open")
    t.run_ticks(2)
    t.run_ticks(10)
    ui_files.save(operator, body)
    t.run_ticks(2)
    assert(workspace().open.body == body, "the edited guest is installed")
    close_contact()
end

-- Replacing a long deadline with a short one wakes at the new deadline.
edit_program([==[
if event.kind == "button" then
    local n = (mem("timer_test") or 0) + 1
    mem("timer_test", n)
    return { commands = {}, accepted = true,
        timer = { id = "timer-" .. tostring(n), ticks = n == 1 and 100 or 5 } }
end
if event.kind == "timeout" then return { commands = {}, status = "fault" } end
return { commands = {} }
]==])
press_inside()
press_inside()
t.run_ticks(15)
local short_timeout, old_timeout = false, false
for _, row in ipairs(t.ledger_rows("disl_run")) do
    local event = row.env.Map.event.Map
    if event.kind.String == "timeout" then
        short_timeout = short_timeout or event.id.String == "timer-2"
        old_timeout = old_timeout or event.id.String == "timer-1"
    end
end
assert(short_timeout and not old_timeout, "the shorter replacement fires without the stale timer")
t.run_ticks(100)
for _, row in ipairs(t.ledger_rows("disl_run")) do
    local event = row.env.Map.event.Map
    assert(event.kind.String ~= "timeout" or event.id.String ~= "timer-1", "the canceled timer never returns")
end

-- An editable guest cannot turn an arbitrary address into a device capability.
edit_program('return { commands = {{ mac = "ff-ff-ff-ff-ff-ff", op = "open", id = "foreign" }} }')
local _ = t.messages(operator)
since = press_inside()
t.run_ticks(30)
assert(t.door_at(5, 3).open and not t.door_at(8, 3).open,
    "a foreign address is rejected before a door operation can apply")
assert(#t.ledger_rows("disl_run") > since, "the press reached the edited guest")
local stopped = table.concat(t.messages(operator), " | ")
assert(stopped:find("The controller has stopped the airlock cycle.", 1, true), "the presser hears the controller stop: " .. stopped)

-- Cutting actual membership prevents requests reaching the installed guest.
laptop.take(operator, 3, 3)
laptop.connect(operator, 4, 3, host)
local released = 0
while true do
    local member
    for _, row in ipairs(laptop.ui(operator).toggles or {}) do
        if row.field == "link_drop" then member = row.option; break end
    end
    if not member then break end
    laptop.toggle(operator, "link_drop", member)
    t.run_ticks(2)
    released += 1
    assert(released <= 5, "each release removes one member")
end
assert(released == 5, "all five endpoints leave the controller")
laptop.close(operator)
t.drop(operator)
t.run_ticks(10)
local isolated_runs = #t.ledger_rows("disl_run")
press_inside()
t.click(visitor, 7, 4, t.target_at(visitor, 7, 4, "airlock_button"))
t.run_ticks(30)
assert(#t.ledger_rows("disl_run") == isolated_runs, "disconnected buttons cannot reach the guest")
