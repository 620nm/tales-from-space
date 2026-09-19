-- Select rendered pack controls; the shared host reducer invokes their callbacks.
local controls = {}

export type Record = { [string]: unknown }
export type Node = { [string]: unknown, id: string }
export type Scope = { document: number, generation: number }
export type Option = string | number | boolean
type TargetKind = "toggle" | "label" | "setpoint"
type Target = {
    kind: TargetKind,
    row: Record,
    index: number,
    child: boolean,
}

function controls.record(value: unknown): Record
    assert(type(value) == "table", "expected a disclosed record")
    return value :: Record
end

function controls.text(value: unknown): string
    assert(type(value) == "string", "expected disclosed text")
    return value
end

function controls.number(value: unknown): number
    assert(type(value) == "number", "expected a disclosed number")
    return value
end

function controls.word(value: unknown): string
    if type(value) == "string" then
        return value
    end
    local label = controls.record(value)
    return controls.text(label.id or label.text)
end

function controls.array(value: unknown): { unknown }
    assert(type(value) == "table", "expected a disclosed array")
    local source = value :: { [unknown]: unknown }
    local length = #source
    for key in pairs(source) do
        assert(
            type(key) == "number" and key % 1 == 0 and key >= 1 and key <= length,
            "expected contiguous disclosed array indices"
        )
    end
    for index = 1, length do
        assert(source[index] ~= nil, "expected contiguous disclosed array indices")
    end
    return value :: { unknown }
end

function controls.texts(value: unknown): { string }
    local values = controls.array(value)
    local texts = table.create(#values, "")
    for index, value in ipairs(values) do
        texts[index] = controls.text(value)
    end
    return texts
end

function controls.rows(value: unknown): { Record }
    local source = controls.array(value)
    local rows = table.create(#source) :: { Record }
    for _, row in ipairs(source) do
        table.insert(rows, controls.record(row))
    end
    return rows
end

function controls.state(p: number, channel: string?): Record
    return controls.record(t.ui(p, channel) or {})
end

function controls.find(p: number, suffix: string, scope: Scope?): Node?
    local found: Node? = nil
    local function visit(value: unknown): ()
        if type(value) ~= "table" then
            return
        end
        local node = controls.record(value)
        if scope and node.window then
            local window = controls.record(node.window)
            if window.document ~= scope.document or window.generation ~= scope.generation then
                return
            end
        end
        if type(node.id) == "string" and node.id:sub(-#suffix) == suffix then
            assert(found == nil, "ambiguous rendered control: " .. suffix)
            found = node :: Node
        end
        for _, child in pairs(node) do
            if type(child) == "table" then
                visit(child)
            end
        end
    end
    visit(t.ui_tree(p))
    return found
end

function controls.node(p: number, suffix: string, scope: Scope?): Node
    return assert(controls.find(p, suffix, scope), "missing rendered control: " .. suffix)
end

function controls.press(p: number, suffix: string, gesture: string?, scope: Scope?): ()
    local node = controls.node(p, suffix, scope)
    t.ui_press(p, node.id, gesture)
end

-- A workspace draws its own device rows under a Details press. The body
-- wrapper is the open marker; the old `/information` module id is absent
-- from the workspace tree (ui/files.ts).
function controls.details(p: number, scope: Scope?): ()
    if controls.find(p, "/details", scope) and not controls.find(p, "/details-body", scope) then
        controls.press(p, "/details", nil, scope)
    end
end

-- Child rows are visible only on the workspace's Controls tab. Selecting the
-- tab also folds an open Details body (ui/files.ts).
function controls.controls_page(p: number, scope: Scope?): ()
    if not controls.find(p, "/controls-body", scope) then
        controls.press(p, "/workspace/controls", nil, scope)
    end
end

local function option_matches(row: Record, option: Option?): boolean
    if option == nil then
        return row.option == nil
    end
    return row.option == tostring(option)
end

local function target_in_rows(
    value: unknown,
    field: string,
    option: Option?,
    kind: TargetKind,
    child: boolean
): Target?
    for index, row in ipairs(controls.rows(value or {})) do
        if row.field == field and option_matches(row, option) then
            return { kind = kind, row = row, index = index, child = child }
        end
    end
    return nil
end

local function toggle_target(state: Record, field: string, option: Option?): Target?
    local target = target_in_rows(state.toggles, field, option, "toggle", false)
    if target then
        return target
    end
    target = target_in_rows(state.labels, field, option, "label", false)
    if target then
        return target
    end
    for _, panel in ipairs(controls.rows(state.control_panels or {})) do
        target = target_in_rows(panel.toggles, field, option, "toggle", true)
        if target then
            return target
        end
        target = target_in_rows(panel.labels, field, option, "label", true)
        if target then
            return target
        end
    end
    return nil
end

local function setpoint_target(state: Record, field: string): Target?
    local target = target_in_rows(state.setpoints, field, nil, "setpoint", false)
    if target then
        return target
    end
    for _, panel in ipairs(controls.rows(state.control_panels or {})) do
        target = target_in_rows(panel.setpoints, field, nil, "setpoint", true)
        if target then
            return target
        end
    end
    return nil
end

local function target_suffix(target: Target): string
    if target.kind == "label" then
        local label = if target.child then "press-" .. (target.index - 1) else tostring(target.index - 1)
        return "/label/" .. label .. "/press"
    end
    if target.kind == "setpoint" then
        return "/set/" .. controls.text(target.row.field) .. "/value"
    end
    local option = target.row.option
    local suffix = "/toggle/" .. controls.text(target.row.field) .. "/" .. (option == nil and "switch" or tostring(option))
    return if target.child and option == nil then suffix .. "/press" else suffix
end

local function fallback_suffix(target: Target): string
    if target.kind == "label" then
        local label = if target.child then "press-" .. (target.index - 1) else tostring(target.index - 1)
        return "/label/" .. label .. "/press"
    end
    local suffix = "/toggle-index/" .. (target.index - 1)
    return if target.child and target.row.option == nil then suffix .. "/press" else suffix
end

-- `channel` names a script channel's document ("programming" for a laptop
-- contact); nil is the default document.
function controls.toggle(p: number, field: string, option: Option?, channel: string?): ()
    local scope = assert(t.ui_document(p, channel), "no document observed")
    local state = controls.state(p, channel)
    local target = assert(toggle_target(state, field, option), "missing disclosed switch: " .. field)
    if target.child then
        controls.controls_page(p, scope)
    else
        controls.details(p, scope)
    end
    local suffix = target_suffix(target)
    local node = controls.find(p, suffix, scope)
    if not node and target.kind ~= "setpoint" then
        node = controls.find(p, fallback_suffix(target), scope)
    end
    controls.press(p, assert(node, "missing rendered switch: " .. suffix).id, nil, scope)
end

function controls.set(p: number, field: string, value: number | "min" | "max", channel: string?): ()
    local scope = assert(t.ui_document(p, channel), "no document observed")
    local state = controls.state(p, channel)
    local target = assert(setpoint_target(state, field), "missing disclosed setpoint: " .. field)
    if target.child then
        controls.controls_page(p, scope)
    else
        controls.details(p, scope)
    end
    local suffix = target_suffix(target)
    local node = controls.node(p, suffix, scope)
    if value == "min" or value == "max" then
        local bound = target.row[value]
        assert(type(bound) == "number", "the setpoint bound is numeric")
        value = bound
    end
    t.ui_edit(p, node.id, tostring(value))
    t.ui_press(p, node.id, "change")
end

function controls.product(p: number, product: string): Node
    for index, row in ipairs(controls.rows(controls.state(p).products or {})) do
        if controls.record(row.payload).product == product then
            return controls.node(p, "/product/" .. (index - 1) .. "/vend", t.ui_document(p))
        end
    end
    error("product is not on the disclosed shelf: " .. product)
end

function controls.vend(p: number, product: string): ()
    t.ui_press(p, controls.product(p, product).id)
end

function controls.has_product(p: number, product: string): boolean
    for index, row in ipairs(controls.rows(controls.state(p).products or {})) do
        if controls.record(row.payload).product == product then
            return controls.find(p, "/product/" .. (index - 1) .. "/vend") ~= nil
        end
    end
    return false
end

function controls.input(p: number, field: string, value: string): ()
    local node = controls.node(p, "/label/" .. field .. "/value")
    t.ui_edit(p, node.id, value)
    controls.press(p, "/label/" .. field .. "/send")
end

function controls.build(p: number, item: string, recipe: string, x: number, y: number): ()
    controls.press(p, "open_build")
    local panel = controls.record(assert(t.ui(p), "build window opens"))
    for index, row in ipairs(controls.rows(panel.recipes or {})) do
        if row.item == item and row.recipe == recipe then
            controls.press(p, "/recipe/" .. (index - 1) .. "/arm")
            t.place_build(p, x, y)
            t.ui_close(p)
            return
        end
    end
    error("recipe is not in the disclosed build window: " .. recipe)
end

return controls
