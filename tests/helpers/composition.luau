-- Exact component membership and retained substrate assertions for specs.
local composition = {}

function composition.matches(x: number, y: number, components: {string}): boolean
    local tile = t.composition(x, y)
    if tile == nil or #tile.components ~= #components then return false end
    local expected: {[string]: boolean} = {}
    for _, component in ipairs(components) do expected[component] = true end
    for _, component in ipairs(tile.components) do
        if not expected[component.component] then return false end
        expected[component.component] = nil
    end
    return true
end

function composition.bare(x: number, y: number, substrate: string): boolean
    local tile = t.composition(x, y)
    return tile ~= nil and #tile.components == 0 and tile.resolved_substrate == substrate
end

function composition.describe(x: number, y: number): string
    local tile = t.composition(x, y)
    if tile == nil then return "outside map" end
    local names: {string} = {}
    if tile.resolved_substrate ~= nil then table.insert(names, tile.resolved_substrate) end
    for _, component in ipairs(tile.components) do table.insert(names, component.component) end
    return table.concat(names, " + ")
end

function composition.deck_instance(x: number, y: number): number?
    for _, component in ipairs({ "floor_tiles", "grid_cover", "reinforcement", "station_base" }) do
        local instance = t.component_instance(x, y, component)
        if instance then return instance end
    end
    return nil
end

function composition.deck_target(x: number, y: number): SpecActionTarget
    local instance = composition.deck_instance(x, y)
    if instance then return { Component = { tile = { x = x, y = y }, instance = instance } } end
    return { Turf = { x = x, y = y } }
end

function composition.click_deck(player: number, x: number, y: number)
    local instance = composition.deck_instance(x, y)
    if instance then t.click_component(player, x, y, instance)
    else t.click_turf(player, x, y) end
end

function composition.examine_deck(player: number, x: number, y: number): SpecExamine?
    local instance = composition.deck_instance(x, y)
    if instance then return t.examine_component(player, x, y, instance) end
    return t.examine_turf(player, x, y)
end

return composition
