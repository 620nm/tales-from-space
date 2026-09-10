-- Copy and program through a held laptop; target identity stays native-bound.
t.world([==[(
    name: "contact workspace",
    legend: {
        '.': (turf: Floor), '#': (turf: Wall),
        'G': (turf: Floor, fixture: Some(Generator)),
        'a': (turf: Floor, fixture: Some(Apc)),
        'o': (turf: Floor, fixture: Some(Outlet)),
    },
    rows: ["#######", "#.....#", "#Gao..#", "#######"],
    spawns: [(1, 1)],
    items: [(1, 1, "laptop"), (1, 1, "floppy_disk.atmos_stock"),
        (1, 1, "floppy_disk")],
    machines: [(2, 1, "transceiver", { "encryption_1": "encryption_key.medical" })],
    cables: [(1, 2, 2), (2, 2, 3), (3, 2, 1)],
)]==], 0)
local p = t.join()
t.run_ticks(20)
local laptop = t.target_at(1, 1, "laptop")
local target = t.target_at(2, 1)

local function act(kind, payload)
    t.ui_act(p, kind, payload, "programming")
    t.run_ticks(2)
end
local function workspace()
    local ui = t.ui(p, "programming")
    assert(ui and ui.sockets and #ui.sockets == 1, "contact opens the target's socket workspace")
    return ui
end
local function store(ui, side)
    for _, row in ipairs(ui.stores) do if row.key == side then return row end end
    return nil
end
local function file(ui, side, name)
    for _, row in ipairs(ui.files) do
        if row.store == side and row.name == name then return row end
    end
    return nil
end
local function address(row)
    return row.store .. ":" .. tostring(row.uid) .. ":" .. row.binding
end
local function copy(row, destination, name)
    t.run_ticks(10)
    act("text", '{"field":"file_copy","option":"' .. address(row) .. ':' .. destination.binding
        .. '","text":"' .. name .. '"}')
end
local function contact()
    t.click(p, 2, 1, target)
    t.run_ticks(2)
    return workspace()
end

-- Preset text and source share the same physical medium and copy path.
t.click(p, 1, 1, t.target_at(1, 1, "floppy_disk.atmos_stock"))
t.run_ticks(2)
t.click(p, 1, 1, laptop)
t.run_ticks(2)
for _ = 1, 3 do t.use_item(p, laptop, "secondary"); t.run_ticks(2) end
local desktop = t.ui(p)
assert(desktop.stores and #desktop.stores == 2, "both laptop stores are available")
local instructions = file(desktop, "media", "readme")
assert(instructions and instructions.fixed and instructions.ext == "md", "the text reference seeds a fixed Markdown file")
t.ui_act(p, "toggle", '{"field":"file_open","option":"' .. address(instructions) .. '"}')
t.run_ticks(2)
local instructions_text = t.ui(p).open.body
assert(instructions_text:find("# Airlock controller", 1, true), "the reference body is readable text")
t.run_ticks(10)
t.ui_act(p, "text", '{"field":"file_copy","option":"' .. address(instructions) .. ':'
    .. store(desktop, "host").binding .. '","text":"manual"}')
t.run_ticks(2)
local manual = file(t.ui(p), "host", "manual")
assert(manual and not manual.fixed and manual.ext == "md", "a text reference copy is editable and keeps its extension")
t.ui_act(p, "toggle", '{"field":"file_open","option":"' .. address(manual) .. '"}')
t.run_ticks(2)
assert(t.ui(p).open.body == instructions_text, "copy preserves the complete reference text")
t.run_ticks(10)
desktop = t.ui(p)
t.ui_act(p, "text", '{"field":"file_create","option":"host:disl:' .. desktop.stores[1].binding
    .. '","text":"local_program"}')
t.run_ticks(2)
local local_file = t.ui(p).open
t.ui_act(p, "text", '{"field":"file_save","option":"' .. address(local_file)
    .. '","text":"return { pass = true }","revision":0}')
t.run_ticks(2)
t.ui_close(p)
t.run_ticks(2)
t.click(p, 1, 1, laptop)
t.run_ticks(2)
assert(t.hands(p).held == "laptop", "the powered laptop is actively held")

local ui = contact()
assert(#ui.stores == 1 and store(ui, "media") == nil,
    "contact never mounts the laptop's internal store or inserted disk as B:")
assert(ui.script.data.wallpaper == desktop.script.data.wallpaper,
    "the target workspace uses the held laptop's wallpaper")
for _, row in ipairs(t.actions(p)) do
    if row.target.Entity == target then
        local connects = false
        for _, action in ipairs(row.actions) do
            if action.id == "connect" then connects = true end
        end
        assert(connects, "the configured target offers a laptop connection")
    end
end

-- Carry a separate blank disk to the target without removing the laptop disk.
t.ui_close(p, "programming")
t.run_ticks(2)
t.swap_hands(p)
t.run_ticks(2)
t.click(p, 1, 1, t.target_at(1, 1, "floppy_disk"))
t.run_ticks(2)
t.click(p, 2, 1, target)
t.run_ticks(2)
t.swap_hands(p)
t.run_ticks(2)
ui = contact()
assert(#ui.stores == 2 and store(ui, "media"), "B: is the target's inserted disk")
assert(file(ui, "media", "airlock") == nil and file(ui, "media", "local_program") == nil,
    "neither laptop store leaks into the target disk")
t.run_ticks(10)
act("text", '{"field":"file_create","option":"media:disl:' .. store(ui, "media").binding
    .. '","text":"disk_program"}')
local disk_file = workspace().open
act("text", '{"field":"file_save","option":"' .. address(disk_file)
    .. '","text":"return { pass = true }","revision":0}')
ui = workspace()
copy(file(ui, "media", "disk_program"), store(ui, "host"), "target_program")
ui = workspace()
local target_file = assert(file(ui, "host", "target_program"), "copy places a program on target A:")
act("toggle", '{"field":"file_open","option":"' .. address(target_file) .. '"}')
assert(workspace().open.body == "return { pass = true }", "the copied bytes arrive whole")
act("toggle", '{"field":"socket_load","option":"carry:' .. tostring(target_file.uid)
    .. ':' .. store(ui, "host").binding .. '"}')
assert(workspace().sockets[1].uid == target_file.uid, "target socket binds its host copy")
t.run_ticks(10)
act("text", '{"field":"file_save","option":"' .. address(target_file)
    .. '","text":"return { pass = false }","revision":0}')
assert(workspace().open.body == "return { pass = false }", "contact edits a running target file")
t.run_ticks(10)
act("text", '{"field":"file_save","option":"' .. address(target_file)
    .. '","text":"return {}","revision":0}')
assert(workspace().open.body == "return { pass = false }", "stale revision cannot overwrite source")
ui = workspace()
copy(target_file, store(ui, "media"), "disk_return")
assert(file(workspace(), "media", "disk_return"), "the target copies back to its disk")
local stale_source = file(workspace(), "media", "disk_program")
local target_store = store(workspace(), "host")
act("toggle", '{"field":"media_eject","option":"' .. store(workspace(), "media").binding .. '"}')
assert(store(workspace(), "media") == nil, "eject removes the target disk from the workspace")
local copied = #t.ledger_rows("file_copied")
copy(stale_source, target_store, "stale_copy")
assert(#t.ledger_rows("file_copied") == copied, "an ejected disk cannot supply a stale copy")
act("toggle", '{"field":"socket_unload","option":"carry:' .. store(workspace(), "host").binding .. '"}')
assert(workspace().sockets[1].state.id == "sockets.state.unbound", "contact unloads the target socket")

t.swap_hands(p)
t.run_ticks(20)
assert(t.ui(p, "programming") == nil, "switching the active hand revokes contact")
t.swap_hands(p)
t.run_ticks(2)
contact()
t.use_item(p, laptop, "alt_primary")
t.run_ticks(20)
assert(t.ui(p, "programming") == nil, "closing the held laptop revokes contact")
t.use_self(p)
t.run_ticks(2)
contact()
t.outage()
t.run_ticks(20)
assert(t.ui(p, "programming") == nil, "target power loss revokes contact")
