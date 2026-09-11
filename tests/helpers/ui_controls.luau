-- Select rendered pack controls; the shared host reducer invokes their callbacks.
local controls = {}

function controls.find(p, suffix, scope)
    local found = nil
    local function visit(node)
        if type(node) ~= "table" then return end
        if scope and node.window and (node.window.document ~= scope.document or node.window.generation ~= scope.generation) then return end
        if type(node.id) == "string" and node.id:sub(-#suffix) == suffix then
            assert(found == nil, "ambiguous rendered control: " .. suffix)
            found = node
        end
        for _, child in pairs(node) do
            if type(child) == "table" then visit(child) end
        end
    end
    visit(t.ui_tree(p))
    return found
end

function controls.node(p, suffix, scope)
    return assert(controls.find(p, suffix, scope), "missing rendered control: " .. suffix)
end

function controls.press(p, suffix, gesture, scope)
    local node = controls.node(p, suffix, scope)
    t.ui_press(p, node.id, gesture)
end

-- `channel` names a script channel's document ("programming" for a laptop
-- contact); nil is the default document.
function controls.toggle(p, field, option, channel)
    local scope = assert(t.ui_document(p, channel), "no document observed")
    local suffix = "/toggle/" .. field .. "/" .. (option == nil and "switch" or tostring(option))
    if controls.find(p, suffix, scope) then controls.press(p, suffix, nil, scope); return end
    local selected = nil
    if option ~= nil then selected = tostring(option) end
    for index, row in ipairs((t.ui(p, channel) or {}).toggles or {}) do
        if row.field == field and row.option == selected then
            controls.press(p, "/toggle-index/" .. (index - 1), nil, scope)
            return
        end
    end
    for index, row in ipairs((t.ui(p, channel) or {}).labels or {}) do
        if row.row == "press" and row.field == field and row.option == selected then
            controls.press(p, "/label/" .. (index - 1) .. "/press", nil, scope)
            return
        end
    end
    error("missing rendered switch: " .. suffix)
end

function controls.set(p, field, value)
    local node = controls.node(p, "/set/" .. field .. "/value", t.ui_document(p))
    if value == "min" or value == "max" then
        for _, point in ipairs((t.ui(p) or {}).setpoints or {}) do
            if point.field == field then value = point[value]; break end
        end
    end
    t.ui_edit(p, node.id, tostring(value))
    t.ui_press(p, node.id, "change")
end

function controls.product(p, product)
    for index, row in ipairs((t.ui(p) or {}).products or {}) do
        if row.payload.product == product then
            return controls.node(p, "/product/" .. (index - 1) .. "/vend", t.ui_document(p))
        end
    end
    error("product is not on the disclosed shelf: " .. product)
end

function controls.vend(p, product)
    t.ui_press(p, controls.product(p, product).id)
end

function controls.has_product(p, product)
    for index, row in ipairs((t.ui(p) or {}).products or {}) do
        if row.payload.product == product then
            return controls.find(p, "/product/" .. (index - 1) .. "/vend") ~= nil
        end
    end
    return false
end

function controls.input(p, field, value)
    local node = controls.node(p, "/label/" .. field .. "/value")
    t.ui_edit(p, node.id, value)
    controls.press(p, "/label/" .. field .. "/send")
end

function controls.build(p, item, recipe, x, y)
    controls.press(p, "open_build")
    local panel = assert(t.ui(p), "build window opens")
    for index, row in ipairs(panel.recipes or {}) do
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
