-- Editor declaration: the modes the map editor offers and the prototypes it
-- previews and parameterises. Contract: docs/mapping/editor-declarations.md
-- in the engine checkout.
local DOOR_FAMILIES = {
    { paint = "engineering", door = "door_eng", bolt = "door_bolt_lights" },
    { paint = "interior", door = "door_int", bolt = "door_int_bolt_lights" },
    { paint = "public", door = "door", bolt = "door_bolt_lights" },
}

-- First match wins, so the most specific condition leads each family.
local function airlock_previews()
    local previews = {}
    for _, family in DOOR_FAMILIES do
        local door = family.door
        local paint = family.paint
        table.insert(previews, {
            when = { paint = paint, glass = true, open = true },
            layers = { door .. "_glass_open" },
        })
        table.insert(previews, {
            when = { paint = paint, open = true },
            layers = { door .. "_open" },
        })
        table.insert(previews, {
            when = { paint = paint, glass = true, bolted = true },
            layers = { door .. "_glass", family.bolt },
        })
        table.insert(previews, {
            when = { paint = paint, bolted = true },
            layers = { door, family.bolt },
        })
        table.insert(previews, {
            when = { paint = paint, glass = true },
            layers = { door .. "_glass" },
        })
        table.insert(previews, {
            when = { paint = paint },
            layers = { door },
        })
    end
    return previews
end

local function airlock(id: string)
    return { kind = "structure", id = id, previews = airlock_previews() }
end

local prototypes = {
    airlock("airlock"),
    airlock("airlock.engineering"),
    airlock("airlock.engineering_glass"),
    airlock("airlock.interior_glass"),
    {
        kind = "structure",
        id = "player_spawn",
        section = "Map Markers",
        category = "",
        properties = {
            {
                key = "weight",
                kind = "number",
                label = "lunatic/tfs:editor.player_spawn.weight",
                default = 1,
                min = 0,
                max = 1000000,
                step = 1,
            },
            {
                key = "jobs",
                kind = "words",
                label = "lunatic/tfs:editor.player_spawn.jobs",
                default = "",
                options = { "assistant", "captain", "engineer", "medic", "security" },
            },
            {
                key = "roles",
                kind = "words",
                label = "lunatic/tfs:editor.player_spawn.roles",
                default = "",
                options = { "builder", "crew" },
            },
        },
    },
    {
        kind = "structure",
        id = "threat_spawn",
        section = "Map Markers",
        category = "",
        properties = {
            {
                key = "weight",
                kind = "number",
                label = "lunatic/tfs:editor.threat_spawn.weight",
                default = 1,
                min = 0,
                max = 1000000,
                step = 1,
            },
        },
    },
    -- Boulders lie on natural ground; cliffs are terrain-brush blends
    -- (`basalt_cliff`, `silica_cliff`), listed in the Terrain section; the
    -- boulders file into it under a Natural category.
    { kind = "structure", id = "outcrop", section = "terrain", category = "Natural" },
    { kind = "structure", id = "outcrop.cluster", section = "terrain", category = "Natural" },
}

return {
    version = 1,
    pack = "lunatic/tfs",
    revision = "9",
    tools = { "select", "paint", "fill", "erase", "clone", "link" },
    lenses = { "surface", "subfloor", "blend", "networking" },
    prototypes = prototypes,
    -- New-level fills by band (the engine's docs/mapping/editor-declarations.md):
    -- rock below a planet's ground, whose mined tile keeps the profile's cold
    -- ground (the icemoon mineral leaves snow, minerals.dm:677); blank below
    -- ground in space, which inherits space. Every kind inherits at ground; a
    -- blank tile above ground resolves to open sky, so `open_air` stays empty.
    levels = {
        terrestrial = { subterrain = { components = { { component = "rock" } } }, terrain = {}, open_air = {} },
        space = { subterrain = {}, terrain = {}, open_air = {} },
    },
}
