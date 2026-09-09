-- Install the actual shipped source, then operate the room through its buttons.
t.set_breathing(false)
t.world_file("programmable_airlock.ron", 0)
t.set_environment({ sink_k = 293.15, insolation = 0 })
local operator = t.join()
local visitor = t.join()
t.run_ticks(20)
local host = t.target_at(4, 3, "access_point")
local laptop = t.target_at(3, 3, "laptop")
assert(t.door_at(5, 3).bolted and not t.door_at(5, 3).open, "interior starts closed and bolted")
assert(t.door_at(8, 3).open and not t.door_at(8, 3).bolted, "exterior starts open and unbolted")
assert(t.room_pressure(6, 3) < 1, "the chamber starts evacuated")

-- Join actual nearby endpoints from the access point's ordinary panel.
t.click(operator, 4, 3, host)
t.run_ticks(2)
t.ui_act(operator, "toggle", '{"field":"link_lock"}')
t.run_ticks(2)
local joined = 0
while true do
    local candidate
    for _, row in ipairs(t.ui(operator).toggles or {}) do
        if row.field == "link_join" and row.label.id == "link.candidate.endpoint" then candidate = row.option; break end
    end
    if not candidate then break end
    t.ui_act(operator, "toggle", '{"field":"link_join","option":"' .. candidate .. '"}')
    t.run_ticks(2)
    joined += 1
    if joined > 8 then
        local facts = {}
        for _, row in ipairs(t.ui(operator).readouts or {}) do
            table.insert(facts, tostring(row.label.id) .. "=" .. tostring(row.value.id or row.value.text))
        end
        for _, row in ipairs(t.ledger_rows("link_denied")) do table.insert(facts, "denied=" .. tostring(row.why)) end
        error("joins make progress " .. candidate .. " " .. table.concat(facts, " | "))
    end
end
assert(joined == 5, "two doors, two buttons and one vent join the same host")
t.ui_close(operator)
t.run_ticks(2)

-- Fit the source disk in the host, boot the laptop, then hold it against the host.
t.click(operator, 3, 3, t.target_at(3, 3, "airlock_program_disk"))
t.run_ticks(2)
t.click(operator, 4, 3, host)
t.run_ticks(2)
for _ = 1, 3 do t.use_item(operator, laptop, "secondary"); t.run_ticks(2) end
t.ui_close(operator)
t.run_ticks(2)
t.click(operator, 3, 3, laptop)
t.run_ticks(2)
assert(t.hands(operator).held == "laptop", "programming uses the held powered laptop")
t.click(operator, 4, 3, host)
t.run_ticks(2)
local function workspace()
    local ui = t.ui(operator, "programming")
    assert(ui and ui.sockets, "the contact workspace belongs to the target")
    return ui
end
local function act(kind, body)
    t.ui_act(operator, kind, body, "programming")
    t.run_ticks(2)
end
local function store(ui, side)
    for _, row in ipairs(ui.stores) do if row.key == side then return row end end
end
local function file(ui, side)
    for _, row in ipairs(ui.files) do if row.store == side and row.name == "airlock" then return row end end
end
local function address(row)
    return row.store .. ":" .. tostring(row.uid) .. ":" .. row.binding
end
local ui = workspace()
local original = file(ui, "media")
assert(original and original.fixed, "the distribution disk contains a fixed original")
t.run_ticks(10)
act("text", '{"field":"file_copy","option":"' .. address(original) .. ':' .. store(ui, "host").binding
    .. '","text":"airlock"}')
ui = workspace()
local installed = file(ui, "host")
assert(installed and not installed.fixed, "the target copy is editable")
act("toggle", '{"field":"file_open","option":"' .. address(installed) .. '"}')
local source = workspace().open.body
assert(#source <= 8192 and source:find("local function permitted", 1, true), "the installed file is the guest controller source")
act("toggle", '{"field":"socket_load","option":"controller:' .. tostring(installed.uid)
    .. ':' .. store(workspace(), "host").binding .. '"}')
assert(workspace().sockets[1].uid == installed.uid, "the controller socket runs the target copy")

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
    local button = assert(t.target_at(2, 3, "airlock_button"), "the inside button is targetable")
    local offered = false
    for _, action in ipairs(t.action_hints(operator, { Entity = button })) do
        if action.id == "press" and action.gesture == "primary" then offered = true end
    end
    assert(offered, "the button offers its left-click press action")
    t.click(operator, 2, 3, t.target_at(2, 3, "airlock_button"))
    t.run_ticks(2)
end
local function until_door(x, open)
    for _ = 1, 160 do
        local d = t.door_at(x, 3)
        local latest_status
        for _, row in ipairs(t.ledger_rows("disl_run")) do
            local value = row.value.Map
            if value and value.status then latest_status = value.status.String end
        end
        if d.open == open and d.bolted and not d.moving and latest_status == "idle" then return end
        t.run_ticks(4)
    end
    local debug = { "sounds=" .. table.concat(t.sounds(operator), ","), "messages=" .. table.concat(t.messages(operator), " | ") }
    for _, row in ipairs(t.ledger_rows("disl_fault")) do table.insert(debug, "fault=" .. tostring(row.fault) .. ":" .. tostring(row.message)) end
    for _, row in ipairs(t.ledger_rows("script_error")) do table.insert(debug, "script=" .. tostring(row.file) .. ":" .. tostring(row.why)) end
    for _, row in ipairs(t.ledger_rows("script_var_refused")) do table.insert(debug, "var=" .. tostring(row.why)) end
    local runs = t.ledger_rows("disl_run")
    for index = math.max(1, #runs - 14), #runs do
        local row = runs[index]
        local event = row.env.Map.event.Map
        table.insert(debug, event.kind.String .. ":" .. (event.id and event.id.String or "") .. " -> "
            .. tostring(row.value.Map and row.value.Map.status and row.value.Map.status.String))
    end
    error("door rest x=" .. x .. " pressure=" .. t.room_pressure(6, 3) .. " " .. table.concat(debug, " | "))
end
-- Walk in through the initially open exterior, leaving both tracks clear.
for _ = 1, 2 do t.move(visitor, "west"); t.run_ticks(4) end
assert(t.pos(visitor) == 7, "the visitor stands in the chamber")
press_inside()
until_door(5, true)
assert(t.door_at(8, 3).bolted and not t.door_at(8, 3).open, "the exterior is secured before the interior opens")
local function pressure_result()
    local found
    for _, row in ipairs(t.ledger_rows("machine_setpoint")) do
        if row.field == "pressure_watch_result" then found = row.value end
    end
    return found
end
assert(pressure_result() and pressure_result() >= 100,
    "the native pressure completion measures at least 100 kPa before opening")
assert(t.room_pressure(6, 3) > 40, "the real intake supplied gas before the rooms joined")
t.run_ticks(100)
assert(t.door_at(5, 3).open, "bolting the open leaf holds it against autoclose")

-- The chamber button reverses the cycle: close, drain, then open space.
t.click(visitor, 7, 4, t.target_at(7, 4, "airlock_button"))
t.run_ticks(2)
until_door(8, true)
assert(t.door_at(5, 3).bolted and not t.door_at(5, 3).open, "the interior is secured before space opens")
assert(pressure_result() < 10, "the distinct effluent main evacuates below 10 kPa before opening")
assert((t.pipe_pressure(6, 2, 2) or 0) > (t.pipe_pressure(6, 4, 4) or 0), "intake and effluent remain distinct mains")

-- A repeat press of the same button requests the opposite destination.
press_inside()
t.run_ticks(8)
press_inside()
t.run_ticks(80)
until_door(8, true)
assert(not t.door_at(5, 3).open and pressure_result() < 10,
    "the same button reverses the pending cycle and drains before opening")
press_inside()
until_door(5, true)

-- An opposite request during travel supersedes the older operation.
t.click(visitor, 7, 4, t.target_at(7, 4, "airlock_button"))
t.run_ticks(8)
press_inside()
t.run_ticks(80)
until_door(5, true)
assert(not t.door_at(8, 3).open and pressure_result() >= 100,
    "an interrupted outward motor settles under the newer inward generation")

-- Both buttons advance the same alternating sequence through a paced burst.
local burst_start = #t.ledger_rows("disl_run")
press_inside() -- Start this sender's pacing sleep.
for _ = 1, 7 do t.click(operator, 2, 3, t.target_at(2, 3, "airlock_button")) end
t.tick()
t.click(visitor, 7, 4, t.target_at(7, 4, "airlock_button"))
t.run_ticks(80)
until_door(8, true)
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
press_inside()
until_door(5, true)

-- Edit the installed source through the same contact and deny public requests.
t.click(operator, 3, 3, laptop)
t.run_ticks(2)
t.click(operator, 4, 3, host)
t.run_ticks(2)
ui = workspace()
installed = file(ui, "host")
act("toggle", '{"field":"file_open","option":"' .. address(installed) .. '"}')
local denied = source:gsub("return true", "return false", 1)
local function json(s)
    return '"' .. s:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r') .. '"'
end
t.run_ticks(10)
act("text", '{"field":"file_save","option":"' .. address(installed) .. '","text":'
    .. json(denied) .. ',"revision":' .. tostring(workspace().open.revision) .. '}')
assert(workspace().open.body == denied, "a live socket is editable from the laptop")
close_contact()
t.click(visitor, 7, 4, t.target_at(7, 4, "airlock_button"))
t.run_ticks(100)
assert(t.door_at(5, 3).open and not t.door_at(8, 3).open, "denied requests leave the completed state alone")
assert(#t.ledger_rows("disl_run") > 10, "the guest ran for requests and actual completions")

local function edit_program(body)
    t.click(operator, 3, 3, laptop)
    t.run_ticks(2)
    t.click(operator, 4, 3, host)
    t.run_ticks(2)
    local current = file(workspace(), "host")
    act("toggle", '{"field":"file_open","option":"' .. address(current) .. '"}')
    t.run_ticks(10)
    act("text", '{"field":"file_save","option":"' .. address(current) .. '","text":'
        .. json(body) .. ',"revision":' .. tostring(workspace().open.revision) .. '}')
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
press_inside()
t.run_ticks(30)
assert(t.door_at(5, 3).open and not t.door_at(8, 3).open,
    "a foreign address is rejected before a door operation can apply")

-- Cutting actual membership prevents requests reaching the installed guest.
t.click(operator, 4, 3, host)
t.run_ticks(2)
local released = 0
while true do
    local member
    for _, row in ipairs(t.ui(operator).toggles or {}) do
        if row.field == "link_drop" then member = row.option; break end
    end
    if not member then break end
    t.ui_act(operator, "toggle", '{"field":"link_drop","option":"' .. member .. '"}')
    t.run_ticks(2)
    released += 1
    assert(released <= 5, "each release removes one member")
end
assert(released == 5, "all five endpoints leave the controller")
t.ui_close(operator)
t.run_ticks(10)
local isolated_runs = #t.ledger_rows("disl_run")
press_inside()
t.click(visitor, 7, 4, t.target_at(7, 4, "airlock_button"))
t.run_ticks(30)
assert(#t.ledger_rows("disl_run") == isolated_runs, "disconnected buttons cannot reach the guest")
