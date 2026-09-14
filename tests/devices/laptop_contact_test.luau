local ui_controls = require("@helpers/ui_controls")
local ui_files = require("@helpers/ui_files")
local record, rows, text = ui_controls.record, ui_controls.rows, ui_controls.text
type Store = { key: string, owner: unknown, drive: unknown }
type File = ui_files.FileRow & { name: string, fixed: unknown, ext: unknown }

-- Copy and program through a held laptop; target identity stays native-bound.
t.world(
    [==[(
    name: "contact workspace",
    legend: {
        '.': (turf: Floor), '#': (turf: Wall),
        'G': (turf: Floor, fixture: Some(Generator)),
        'a': (turf: Floor, fixture: Some(Apc)),
        'o': (turf: Floor, fixture: Some(Outlet)),
    },
    rows: ["#######", "#.....#", "#Gao..#", "#######"],
    structures: [(2, 2, "player_spawn")],
    items: [(1, 1, "laptop"), (1, 2, "floppy_disk.atmos_stock"),
        (3, 1, "floppy_disk")],
    machines: [(2, 1, "transceiver", { "encryption_1": "encryption_key.medical" })],
    cables: [(1, 2, 2), (2, 2, 3), (3, 2, 1)],
)]==],
    0
)
local p = t.join()
t.run_ticks(20)
local laptop = assert(t.target_at(p, 1, 1, "laptop"))
local target = assert(t.target_at(p, 2, 1))

local function script(ui: ui_controls.Record): ui_controls.Record
    return record(record(ui.script).data)
end
local function workspace()
    local ui = record(t.ui(p, "programming"))
    assert(
        ui and ui.program_slots and #rows(ui.program_slots) == 1,
        "contact opens the target's program workspace"
    )
    return ui
end
local function store(ui: ui_controls.Record, side: string): Store?
    for _, row in ipairs(rows(ui.stores)) do
        if row.key == side then
            return { key = side, owner = row.owner, drive = row.drive }
        end
    end
    return nil
end
local function file(ui: ui_controls.Record, side: string, name: string): File?
    for _, row in ipairs(rows(ui.files)) do
        if row.store == side and row.name == name then
            local uid = row.uid
            assert(type(uid) == "string" or type(uid) == "number", "a file has a UID")
            return { store = side, name = name, uid = uid, fixed = row.fixed, ext = row.ext }
        end
    end
    return nil
end
-- Which drives a file's rendered copy press lands on, by id.
local function copies(side: string, uid: string | number)
    local found = {}
    for _, destination in ipairs({ "host", "media", "tool_host", "tool_media" }) do
        if
            pcall(function()
                return ui_files.row(p, side, uid, "copy-" .. destination)
            end)
        then
            table.insert(found, destination)
        end
    end
    return table.concat(found, ",")
end

-- On a contact a file's one copy press lands on the drive the far side
-- shows, and its id names that side: bring the destination up first.
local function copy(
    row: (ui_files.FileRow & { name: string })?,
    destination: { key: string }?,
    name: string
)
    assert(row and destination, "both copy endpoints are disclosed")
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
for _ = 1, 3 do
    t.use_item(p, laptop, "secondary")
    t.run_ticks(2)
end
local desktop = record(t.ui(p))
assert(desktop.stores and #rows(desktop.stores) == 2, "both laptop stores are available")
local instructions = file(desktop, "media", "readme")
assert(
    instructions and instructions.fixed and instructions.ext == "md",
    "the text reference seeds a fixed Markdown file"
)
ui_files.press(p, instructions, "open")
t.run_ticks(2)
local instructions_text = text(record(ui_controls.state(p).open).body)
assert(
    instructions_text:find("# Airlock controller", 1, true),
    "the reference body is readable text"
)
t.run_ticks(10)
ui_files.press(p, instructions, "copy")
t.run_ticks(2)
local manual = file(record(t.ui(p)), "host", "readme")
assert(
    manual and not manual.fixed and manual.ext == "md",
    "a text reference copy is editable and keeps its extension"
)
ui_files.press(p, manual, "open")
t.run_ticks(2)
assert(
    record(ui_controls.state(p).open).body == instructions_text,
    "copy preserves the complete reference text"
)
t.run_ticks(10)
desktop = record(t.ui(p))
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
assert(
    #rows(ui.stores) == 3
        and store(ui, "tool_host")
        and store(ui, "tool_media")
        and store(ui, "media") == nil,
    "the laptop side lists its A: and the disk in it as B:; the target has no slot loaded"
)
assert(
    assert(store(ui, "tool_host")).owner == "tool"
        and assert(store(ui, "tool_media")).drive == "media",
    "each drive says whose it is and which"
)
local carried =
    assert(file(ui, "tool_host", "local_program"), "the laptop's A: lists its own files")
assert(file(ui, "tool_media", "readme"), "the laptop's B: lists its disk")
assert(
    file(ui, "tool_host", "readme") and not file(ui, "host", "readme"),
    "and nothing of the target's"
)
-- A file opens by the drive on its own side: the laptop reads Markdown
-- though the target's drive reads only `disl`.
local function press_open(row: ui_files.FileRow)
    t.run_ticks(10)
    local _ = t.messages(p)
    ui_files.press(p, row, "open")
    t.run_ticks(2)
    local opened = workspace().open
    return if opened then record(opened) else nil, table.concat(t.messages(p), " | ")
end
for _, side in ipairs({ "tool_media", "tool_host" }) do
    local row = assert(file(ui, side, "readme"))
    local open, heard = press_open(row)
    assert(
        open
            and open.store == side
            and open.uid == row.uid
            and not heard:find("can't open", 1, true),
        "the laptop opens its own " .. side .. " Markdown: " .. heard
    )
end
copy(file(ui, "tool_host", "readme"), store(ui, "host"), "readme")
local refused, heard = press_open(assert(file(workspace(), "host", "readme")))
assert(
    (refused == nil or refused.store ~= "host") and heard:find("can't open", 1, true),
    "the target's own disl-only drive still refuses Markdown: " .. heard
)
-- Creates narrow the same way: each side offers what its own drive reads.
local creates = record(workspace().create)
local function offers(value: unknown, extension: string): boolean
    for _, offered in ipairs(ui_controls.texts(value or {})) do
        if offered == extension then
            return true
        end
    end
    return false
end
assert(
    offers(creates.host, "disl") and not offers(creates.host, "md"),
    "the target's disl-only A: offers no Markdown create"
)
assert(offers(creates.tool_host, "md"), "the laptop's A: offers Markdown")
t.run_ticks(10)
ui_files.create(p, "tool_host", "md", "notes")
t.run_ticks(2)
local notes =
    assert(file(workspace(), "tool_host", "notes"), "the Markdown create lands on the laptop")
local opened = record(workspace().open)
assert(
    opened and opened.store == "tool_host" and opened.uid == notes.uid,
    "and opens by the laptop's drive"
)
-- The far side showing its empty B: takes no copy at all.
assert(
    ui_controls.find(p, "/show/media", t.ui_document(p, "programming")),
    "the target's empty slot is a drive"
)
ui_files.show(p, "media")
assert(copies("tool_host", carried.uid) == "", "no copy lands on a drive with no disk in it")
ui_files.show(p, "host")
copy(carried, store(ui, "host"), carried.name)
ui = workspace()
assert(file(ui, "host", "local_program"), "a laptop file copies onto the target")
assert(file(ui, "tool_host", "local_program"), "and stays on the laptop")
assert(
    script(ui).wallpaper == script(desktop).wallpaper,
    "the target workspace uses the held laptop's wallpaper"
)
-- The window is titled with the laptop in hand; the workspace's own bar
-- names the target, and its panel rows wait under a shut Details.
local scope = assert(t.ui_document(p, "programming"))
local function window()
    local found: ui_controls.Record? = nil
    local function visit(value: unknown): ()
        if type(value) ~= "table" or found then
            return
        end
        local node = record(value)
        local window = if node.window then record(node.window) else nil
        if
            window
            and window.document == scope.document
            and window.generation == scope.generation
        then
            found = window
            return
        end
        for _, child in pairs(node) do
            visit(child)
        end
    end
    visit(t.ui_tree(p))
    return assert(found, "the contact workspace has a window")
end
local tool = record(script(ui).tool)
assert(tool.sprite == "laptop_on", "the script names the running laptop")
assert(
    window().title == tool.name and window().titleAsset == "laptop_on",
    "the window wears the laptop, got: " .. tostring(window().title)
)
local bar = ui_controls.node(p, "/machine-name", scope)
assert(bar.text == ui.name, "the bar names the target, got: " .. tostring(bar.text))
assert(
    ui_controls.find(p, "/details", scope) and ui_controls.find(p, "/information", scope) == nil,
    "the target's own rows start behind Details"
)
assert(ui_controls.find(p, "/programs", scope), "while its program slots stand in view")
ui_controls.details(p, scope)
assert(ui_controls.find(p, "/information", scope), "and Details opens them")
local panes = rows(ui_controls.node(p, "/panes", scope).children)
assert(
    text(panes[1].id):sub(-#"/side/target") == "/side/target"
        and text(panes[#panes].id):sub(-#"/side/tool") == "/side/tool",
    "the target's side stands left of the laptop's"
)
local connects = false
for _, action in ipairs(t.action_hints(p, { Entity = target })) do
    if action.id == "connect" then
        connects = true
    end
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
assert(
    #rows(ui.stores) == 4 and store(ui, "media"),
    "B: on the device side is the target's inserted disk"
)
assert(
    file(ui, "media", "readme") == nil and file(ui, "media", "local_program") == nil,
    "neither laptop store leaks into the target disk"
)
-- Disk to disk: the laptop's B: copies straight onto the device's B:.
copy(file(ui, "tool_media", "readme"), store(ui, "media"), "readme")
assert(file(workspace(), "media", "readme"), "the laptop's disk copies onto the device's disk")
-- One copy press per file, and it follows the far side's drive switch.
local shared = assert(file(workspace(), "host", "local_program"))
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
assert(record(workspace().open).body == "return { pass = true }", "the copied bytes arrive whole")
ui_files.program(p, "carry", target_file.uid)
t.run_ticks(2)
assert(rows(workspace().program_slots)[1].uid == target_file.uid, "target slot loads its host copy")
t.run_ticks(10)
ui_files.save(p, "return { pass = false }")
t.run_ticks(2)
assert(
    record(workspace().open).body == "return { pass = false }",
    "contact edits a running target file"
)
t.run_ticks(10)
local draft = ui_files.edit(p, "return {}")
t.ui_press(p, draft, "change")
t.run_ticks(2)
assert(
    record(workspace().open).body == "return { pass = false }",
    "an unsaved draft cannot overwrite source"
)
ui_controls.press(p, "/editor/revert")
ui_controls.press(p, "/editor/guard/discard")
t.run_ticks(2)
ui = workspace()
copy(target_file, store(ui, "tool_host"), "disk_return")
assert(file(workspace(), "tool_host", "disk_return"), "the target copies back to the laptop")
local stale_source = assert(file(workspace(), "media", "disk_program"))
ui_files.show(p, "tool_host")
local stale_copy_control =
    ui_files.row(p, stale_source.store, stale_source.uid, "copy-tool_host").id
ui_files.show(p, "media")
ui_controls.press(p, "/drive/media/eject")
t.run_ticks(2)
assert(store(workspace(), "media") == nil, "eject removes the target disk from the workspace")
local copied = #t.ledger_rows("file_copied")
assert(not pcall(function()
    t.ui_press(p, stale_copy_control)
end), "removed disk exposes no copy control")
assert(#t.ledger_rows("file_copied") == copied, "an ejected disk cannot supply a stale copy")
ui_files.program(p, "carry")
t.run_ticks(2)
assert(
    record(rows(workspace().program_slots)[1].state).id == "program_slots.state.empty",
    "contact unloads the target slot"
)

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
