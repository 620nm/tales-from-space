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
    assert(ui and ui.program_slots and #ui.program_slots == 1, "contact opens the target's program workspace")
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

-- On a contact a file's one copy press lands on the drive the far side
-- shows, and its id names that side: bring the destination up first.
local function copy(row, destination, name)
    t.run_ticks(10)
    ui_files.show(p, destination.key)
    ui_files.press(p, row, "copy-" .. destination.key)
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
assert(#ui.stores == 3 and store(ui, "tool_host") and store(ui, "tool_media") and store(ui, "media") == nil,
    "the laptop side lists its A: and the disk in it as B:; the target has no slot loaded")
assert(store(ui, "tool_host").owner == "tool" and store(ui, "tool_media").drive == "media",
    "each drive says whose it is and which")
local carried = assert(file(ui, "tool_host", "local_program"), "the laptop's A: lists its own files")
assert(file(ui, "tool_media", "readme"), "the laptop's B: lists its disk")
assert(file(ui, "tool_host", "readme") and not file(ui, "host", "readme"), "and nothing of the target's")
copy(carried, store(ui, "host"), carried.name)
ui = workspace()
assert(file(ui, "host", "local_program"), "a laptop file copies onto the target")
assert(file(ui, "tool_host", "local_program"), "and stays on the laptop")
assert(ui.script.data.wallpaper == desktop.script.data.wallpaper,
    "the target workspace uses the held laptop's wallpaper")
-- The window is titled with the laptop in hand; the workspace's own bar
-- names the target, and its panel rows wait under a shut Details.
local scope = t.ui_document(p, "programming")
local function window()
    local found = nil
    local function visit(node)
        if type(node) ~= "table" or found then return end
        if node.window and node.window.document == scope.document and node.window.generation == scope.generation then
            found = node.window
            return
        end
        for _, child in pairs(node) do visit(child) end
    end
    visit(t.ui_tree(p))
    return assert(found, "the contact workspace has a window")
end
assert(ui.script.data.tool.sprite == "laptop_on", "the script names the running laptop")
assert(window().title == ui.script.data.tool.name and window().titleAsset == "laptop_on",
    "the window wears the laptop, got: " .. tostring(window().title))
local bar = ui_controls.node(p, "/machine-name", scope)
assert(bar.text == ui.name, "the bar names the target, got: " .. tostring(bar.text))
assert(ui_controls.find(p, "/details", scope) and ui_controls.find(p, "/information", scope) == nil,
    "the target's own rows start behind Details")
ui_files.details(p)
assert(ui_controls.find(p, "/information", scope), "and Details opens them")
local panes = ui_controls.node(p, "/panes", scope).children
assert(panes[1].id:sub(-#"/side/target") == "/side/target" and panes[#panes].id:sub(-#"/side/tool") == "/side/tool",
    "the target's side stands left of the laptop's")
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
assert(#ui.stores == 4 and store(ui, "media"), "B: on the device side is the target's inserted disk")
assert(file(ui, "media", "readme") == nil and file(ui, "media", "local_program") == nil,
    "neither laptop store leaks into the target disk")
-- Disk to disk: the laptop's B: copies straight onto the device's B:.
copy(file(ui, "tool_media", "readme"), store(ui, "media"), "readme")
assert(file(workspace(), "media", "readme"), "the laptop's disk copies onto the device's disk")
-- One copy press per file, and it follows the far side's drive switch.
local function copies(side, uid)
    local found = {}
    for _, destination in ipairs({ "host", "media", "tool_host", "tool_media" }) do
        if pcall(function() return ui_files.row(p, side, uid, "copy-" .. destination) end) then
            table.insert(found, destination)
        end
    end
    return table.concat(found, ",")
end
local shared = file(workspace(), "host", "local_program")
ui_files.show(p, "tool_media")
assert(copies("host", shared.uid) == "tool_media", "a device file copies to the laptop's shown B:")
ui_files.show(p, "tool_host")
assert(copies("host", shared.uid) == "tool_host", "and to its A: once A: is shown")
t.run_ticks(10)
ui_files.create(p, "media", "disl", "disk_program")
t.run_ticks(2)
ui_files.save(p, "return { pass = true }")
t.run_ticks(2)
-- Device B: to device A: goes by way of the laptop, the side across.
ui = workspace()
copy(file(ui, "media", "disk_program"), store(ui, "tool_host"), "carried_program")
ui = workspace()
copy(file(ui, "tool_host", "carried_program"), store(ui, "host"), "target_program")
ui = workspace()
local target_file = assert(file(ui, "host", "target_program"), "copy places a program on target A:")
ui_files.press(p, target_file, "open")
t.run_ticks(2)
assert(workspace().open.body == "return { pass = true }", "the copied bytes arrive whole")
ui_files.program(p, "carry", target_file.uid)
t.run_ticks(2)
assert(workspace().program_slots[1].uid == target_file.uid, "target slot loads its host copy")
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
copy(target_file, store(ui, "tool_host"), "disk_return")
assert(file(workspace(), "tool_host", "disk_return"), "the target copies back to the laptop")
local stale_source = file(workspace(), "media", "disk_program")
ui_files.show(p, "tool_host")
local stale_copy_control = ui_files.row(p, stale_source.store, stale_source.uid, "copy-tool_host").id
ui_files.show(p, "media")
ui_controls.press(p, "/drive/media/eject")
t.run_ticks(2)
assert(store(workspace(), "media") == nil, "eject removes the target disk from the workspace")
local copied = #t.ledger_rows("file_copied")
assert(not pcall(function() t.ui_press(p, stale_copy_control) end), "removed disk exposes no copy control")
assert(#t.ledger_rows("file_copied") == copied, "an ejected disk cannot supply a stale copy")
ui_files.program(p, "carry")
t.run_ticks(2)
assert(workspace().program_slots[1].state.id == "program_slots.state.empty", "contact unloads the target slot")

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
-- The laptop's own power button, pressed on its desktop mid-contact.
t.use_self(p)
t.run_ticks(2)
ui_controls.press(p, "/power")
t.run_ticks(20)
assert(t.ui(p, "programming") == nil, "switching the laptop off revokes contact")
t.use_self(p)
t.run_ticks(2)
contact()
t.outage()
t.run_ticks(20)
assert(t.ui(p, "programming") == nil, "target power loss revokes contact")
