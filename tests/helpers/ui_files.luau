-- File workflows select disclosed rows and edit the rendered workspace controls.
local files = {}
local function scope(p) return t.ui_document(p, "programming") or t.ui_document(p) end
local function node(p, suffix) return ui_controls.node(p, suffix, scope(p)) end
local function find(p, suffix) return ui_controls.find(p, suffix, scope(p)) end
local function press(p, suffix) return ui_controls.press(p, suffix, nil, scope(p)) end
local function state(p)
    return t.ui(p, "programming") or t.ui(p)
end
-- A contact side draws one drive at a time: bring `side` up where a
-- rendered switch names it.
local function show(p, side)
    local switch = find(p, "/show/" .. side)
    if switch then t.ui_press(p, switch.id) end
end
files.show = show
function files.create(p, side, ext, name)
    show(p, side)
    local base = "/drive/" .. side .. "/create"
    press(p, base)
    t.ui_edit(p, node(p, base .. "/stem").id, name)
    t.ui_edit(p, node(p, base .. "/ext").id, ext)
    press(p, base .. "/confirm")
end
function files.row(p, side, uid, action)
    show(p, side)
    local index = 0
    for _, row in ipairs(state(p).files or {}) do
        if row.store == side then
            if tostring(row.uid) == tostring(uid) then
                return node(p, "/drive/" .. side .. "/file/" .. index .. "/" .. action)
            end
            index += 1
        end
    end
    error("file is absent from the rendered drive")
end
function files.press(p, row, action)
    local node = files.row(p, row.store, row.uid, action)
    t.ui_press(p, node.id)
end
function files.address(p, address, action)
    local side, uid = address:match("^([^:]+):([^:]+):")
    t.ui_press(p, files.row(p, side, uid, action).id)
end
function files.edit(p, text)
    if find(p, "/editor/mode/edit") then press(p, "/editor/mode/edit") end
    local root = node(p, "/editor")
    local function find(node)
        if type(node) ~= "table" then return nil end
        if type(node.id) == "string" and node.id:find("/editor/body/", 1, true) then return node end
        for _, child in pairs(node) do
            if type(child) == "table" then local found = find(child); if found then return found end end
        end
    end
    local input = assert(find(root), "the rendered source editor is available")
    t.ui_edit(p, input.id, text)
    return input.id
end
function files.save(p, text)
    files.edit(p, text)
    press(p, "/editor/save")
end
function files.rename(p, name)
    t.ui_edit(p, node(p, "/editor/name").id, name)
    press(p, "/editor/rename-button")
end
function files.program(p, slot, uid)
    for index, row in ipairs(state(p).program_slots or {}) do
        if row.id == slot then
            if uid == nil then press(p, "/program/" .. (index - 1) .. "/unload"); return end
            local load = 0
            for _, file in ipairs(state(p).files or {}) do
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
