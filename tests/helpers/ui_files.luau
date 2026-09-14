-- File workflows select disclosed rows and edit the rendered workspace controls.
local ui_controls = require("@helpers/ui_controls")
local files = {}

export type FileRow = { store: string, uid: string | number }
local function scope(p: number): ui_controls.Scope?
    return t.ui_document(p, "programming") or t.ui_document(p)
end
local function node(p: number, suffix: string): ui_controls.Node
    return ui_controls.node(p, suffix, scope(p))
end
local function find(p: number, suffix: string): ui_controls.Node?
    return ui_controls.find(p, suffix, scope(p))
end
local function press(p: number, suffix: string): ()
    return ui_controls.press(p, suffix, nil, scope(p))
end
local function state(p: number): ui_controls.Record
    return ui_controls.record(t.ui(p, "programming") or t.ui(p))
end
-- A contact side draws one drive at a time: bring `side` up where a
-- rendered switch names it.
local function show(p: number, side: string): ()
    local switch = find(p, "/show/" .. side)
    if switch then
        t.ui_press(p, switch.id)
    end
end
files.show = show
function files.create(p: number, side: string, ext: string, name: string): ()
    show(p, side)
    local base = "/drive/" .. side .. "/create"
    press(p, base)
    t.ui_edit(p, node(p, base .. "/stem").id, name)
    t.ui_edit(p, node(p, base .. "/ext").id, ext)
    press(p, base .. "/confirm")
end
function files.row(p: number, side: string, uid: string | number, action: string): ui_controls.Node
    show(p, side)
    local index = 0
    for _, row in ipairs(ui_controls.rows(state(p).files or {})) do
        if row.store == side then
            if tostring(row.uid) == tostring(uid) then
                return node(p, "/drive/" .. side .. "/file/" .. index .. "/" .. action)
            end
            index += 1
        end
    end
    error("file is absent from the rendered drive")
end
function files.press(p: number, row: FileRow, action: string): ()
    local node = files.row(p, row.store, row.uid, action)
    t.ui_press(p, node.id)
end
function files.address(p: number, address: string, action: string): ()
    local side, uid = address:match("^([^:]+):([^:]+):")
    assert(side ~= nil and uid ~= nil, "file address contains a store and uid")
    t.ui_press(p, files.row(p, side, uid, action).id)
end
function files.edit(p: number, text: string): string
    if find(p, "/editor/mode/edit") then
        press(p, "/editor/mode/edit")
    end
    local root = node(p, "/editor")
    local function find(value: unknown): ui_controls.Node?
        if type(value) ~= "table" then
            return nil
        end
        local node = ui_controls.record(value)
        if type(node.id) == "string" and node.id:find("/editor/body/", 1, true) then
            return node :: ui_controls.Node
        end
        for _, child in pairs(node) do
            if type(child) == "table" then
                local found = find(child)
                if found then
                    return found
                end
            end
        end
        return nil
    end
    local input = assert(find(root), "the rendered source editor is available")
    t.ui_edit(p, input.id, text)
    return input.id
end
function files.save(p: number, text: string): ()
    files.edit(p, text)
    press(p, "/editor/save")
end
function files.rename(p: number, name: string): ()
    t.ui_edit(p, node(p, "/editor/name").id, name)
    press(p, "/editor/rename-button")
end
function files.program(p: number, slot: string, uid: (string | number)?): ()
    for index, row in ipairs(ui_controls.rows(state(p).program_slots or {})) do
        if row.id == slot then
            if uid == nil then
                press(p, "/program/" .. (index - 1) .. "/unload")
                return
            end
            local load = 0
            for _, file in ipairs(ui_controls.rows(state(p).files or {})) do
                if file.store == "host" and file.ext == "disl" then
                    if tostring(file.uid) == tostring(uid) then
                        press(p, "/program/" .. (index - 1) .. "/load/" .. load)
                        return
                    end
                    load += 1
                end
            end
        end
    end
    error("program file is not offered")
end
return files
