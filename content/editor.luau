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
}

local function mode(label: string)
    return {
        label = label,
        tools = { "select", "paint", "fill", "erase", "clone", "link" },
        lenses = { "surface", "subfloor", "blend", "networking" },
        prototypes = prototypes,
    }
end

return {
    version = 1,
    pack = "lunatic/tfs",
    revision = "4",
    default_mode = "space_station",
    modes = {
        space_station = mode("Space Station"),
        free_build = mode("Free Build"),
    },
}
