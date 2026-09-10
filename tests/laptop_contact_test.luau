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
    spawns: [(2, 1)],
    items: [(1, 1, "laptop"), (1, 2, "floppy_disk.atmos_stock"),
        (3, 1, "floppy_disk")],
    machines: [(2, 1, "transceiver", { "encryption_1": "encryption_key.medical" })],
    cables: [(1, 2, 2), (2, 2, 3), (3, 2, 1)],
)]==], 0)
local p = t.join()
t.run_ticks(20)
local laptop = t.target_at(p, 1, 1, "laptop")
local target = t.target_at(p, 2, 1)

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

local function copy(row, destination, name)
    t.run_ticks(10)
    ui_files.press(p, row, "copy")
    t.run_ticks(2)
    if name ~= row.name then
        local copied = assert(file(workspace(), destination.key, row.name))
        ui_files.press(p, copied, "open")
        t.run_ticks(10)
        ui_files.rename(p, name)
        t.run_ticks(2)
    end
end
local function contact()
    t.click(p, 2, 1, assert(t.target_at(p, 2, 1, target)))
    t.run_ticks(2)
    return workspace()
end

-- Preset text and source share the same physical medium and copy path.
t.click(p, 1, 2, assert(t.target_at(p, 1, 2, "floppy_disk.atmos_stock")))
t.run_ticks(2)
t.click(p, 1, 1, assert(t.target_at(p, 1, 1, laptop)))
t.run_ticks(2)
for _ = 1, 3 do t.use_item(p, laptop, "secondary"); t.run_ticks(2) end
local desktop = t.ui(p)
assert(desktop.stores and #desktop.stores == 2, "both laptop stores are available")
local instructions = file(desktop, "media", "readme")
assert(instructions and instructions.fixed and instructions.ext == "md", "the text reference seeds a fixed Markdown file")
ui_files.press(p, instructions, "open")
t.run_ticks(2)
local instructions_text = t.ui(p).open.body
assert(instructions_text:find("# Airlock controller", 1, true), "the reference body is readable text")
t.run_ticks(10)
ui_files.press(p, instructions, "copy")
t.run_ticks(2)
local manual = file(t.ui(p), "host", "readme")
assert(manual and not manual.fixed and manual.ext == "md", "a text reference copy is editable and keeps its extension")
ui_files.press(p, manual, "open")
t.run_ticks(2)
assert(t.ui(p).open.body == instructions_text, "copy preserves the complete reference text")
t.run_ticks(10)
desktop = t.ui(p)
ui_files.create(p, "host", "disl", "local_program")
t.run_ticks(2)
ui_files.save(p, "return { pass = true }")
t.run_ticks(2)
t.ui_close(p)
t.run_ticks(2)
t.click(p, 1, 1, assert(t.target_at(p, 1, 1, laptop)))
t.run_ticks(2)
assert(t.hands(p).held == "laptop", "the powered laptop is actively held")

local ui = contact()
assert(#ui.stores == 1 and store(ui, "media") == nil,
    "contact never mounts the laptop's internal store or inserted disk as B:")
assert(ui.script.data.wallpaper == desktop.script.data.wallpaper,
    "the target workspace uses the held laptop's wallpaper")
local connects = false
for _, action in ipairs(t.action_hints(p, { Entity = target })) do
    if action.id == "connect" then connects = true end
end
assert(connects, "the configured target offers a laptop connection")

-- Carry a separate blank disk to the target without removing the laptop disk.
t.ui_close(p, "programming")
t.run_ticks(2)
t.swap_hands(p)
t.run_ticks(2)
t.click(p, 3, 1, assert(t.target_at(p, 3, 1, "floppy_disk")))
t.run_ticks(2)
t.click(p, 2, 1, assert(t.target_at(p, 2, 1, target)))
t.run_ticks(2)
t.swap_hands(p)
t.run_ticks(2)
ui = contact()
assert(#ui.stores == 2 and store(ui, "media"), "B: is the target's inserted disk")
assert(file(ui, "media", "airlock") == nil and file(ui, "media", "local_program") == nil,
    "neither laptop store leaks into the target disk")
t.run_ticks(10)
ui_files.create(p, "media", "disl", "disk_program")
t.run_ticks(2)
ui_files.save(p, "return { pass = true }")
t.run_ticks(2)
ui = workspace()
copy(file(ui, "media", "disk_program"), store(ui, "host"), "target_program")
ui = workspace()
local target_file = assert(file(ui, "host", "target_program"), "copy places a program on target A:")
ui_files.press(p, target_file, "open")
t.run_ticks(2)
assert(workspace().open.body == "return { pass = true }", "the copied bytes arrive whole")
ui_files.socket(p, "carry", target_file.uid)
t.run_ticks(2)
assert(workspace().sockets[1].uid == target_file.uid, "target socket binds its host copy")
t.run_ticks(10)
ui_files.save(p, "return { pass = false }")
t.run_ticks(2)
assert(workspace().open.body == "return { pass = false }", "contact edits a running target file")
t.run_ticks(10)
local draft = ui_files.edit(p, "return {}")
t.ui_press(p, draft, "change")
t.run_ticks(2)
assert(workspace().open.body == "return { pass = false }", "an unsaved draft cannot overwrite source")
ui_controls.press(p, "/editor/revert")
ui_controls.press(p, "/editor/guard/discard")
t.run_ticks(2)
ui = workspace()
copy(target_file, store(ui, "media"), "disk_return")
assert(file(workspace(), "media", "disk_return"), "the target copies back to its disk")
local stale_source = file(workspace(), "media", "disk_program")
local stale_copy_control = ui_files.row(p, stale_source.store, stale_source.uid, "copy").id
ui_controls.press(p, "/drive/media/eject")
t.run_ticks(2)
assert(store(workspace(), "media") == nil, "eject removes the target disk from the workspace")
local copied = #t.ledger_rows("file_copied")
assert(not pcall(function() t.ui_press(p, stale_copy_control) end), "removed disk exposes no copy control")
assert(#t.ledger_rows("file_copied") == copied, "an ejected disk cannot supply a stale copy")
ui_files.socket(p, "carry")
t.run_ticks(2)
assert(workspace().sockets[1].state.id == "sockets.state.unbound", "contact unloads the target socket")

t.swap_hands(p)
t.run_ticks(20)
assert(t.ui(p, "programming") == nil, "switching the active hand revokes contact")
t.swap_hands(p)
t.run_ticks(2)
contact()
t.use_item_site(p, { Held = { hand = t.hands(p).active - 1 } }, "alt_primary")
t.run_ticks(20)
assert(t.ui(p, "programming") == nil, "closing the held laptop revokes contact")
t.use_self(p)
t.run_ticks(2)
contact()
t.outage()
t.run_ticks(20)
assert(t.ui(p, "programming") == nil, "target power loss revokes contact")
