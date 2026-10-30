-- The gravity battery: eight welded parts become one machine on a 3x3
-- footprint, anchored on its centre tile.
--
-- Cells are row-major from the north-west, so footprint cell r * 3 + c + 1
-- wears sprite `<stage>_<r>_<c>`; the south emitter cell is cell 8, which
-- is the only one a glass panel fits (lib/grav_smes.luau). Not opaque.
--
-- ASSEMBLY, pack-tuned (tg has no such machine): welded, then metal for the
-- yoke clamps, one coil of cable, nine lengths of pipe, metal for the
-- casing, and glass for the status panel. Each step runs backwards with
-- the opposite tool and returns what it cost. Welded joints are
-- permanent; the weld itself is a script (lib/grav_smes.luau).
--
-- RUNNING STATES have sprites only: the disc over the centre tile rides
-- the centre cell's stack on a layer above standing things, and the
-- south cell wears one status glyph per `<run state>_<status>` state.
local STATUSES = { "charging", "discharging", "fault", "unpowered" }
local ANCHOR_CELL = 5
local SOUTH_CELL = 8
local DISC_LAYER = "overhead_entities"

local CLAMP_METAL = 8
local CABLE_COILS = 30
local PIPE_LENGTHS = 9
local CASING_METAL = 16

local footprint = {}
for row = 0, 2 do
    for column = 0, 2 do
        footprint[row * 3 + column + 1] = { at = { column - 1, row - 1 } }
    end
end

local function stage_row(stage: string): { any }
    local cells: { any } = {}
    for row = 0, 2 do
        for column = 0, 2 do
            cells[row * 3 + column + 1] = `grav_smes_{stage}_{row}_{column}`
        end
    end
    return cells
end

local function disc(animation: string): { sprite: string, visual_layer: string }
    return { sprite = `grav_disc_{animation}`, visual_layer = DISC_LAYER }
end

local states = { "welded", "clamped", "wired", "piped", "cased", "standby" }
local state_sprites: { [string]: { any } } = {}
for _, state in ipairs(states) do
    state_sprites[state] = stage_row(state)
end

-- The animations: the disc joins the centre cell's stack.
for _, animation in ipairs({ "startup", "active", "shutdown" }) do
    table.insert(states, animation)
    local cells = stage_row(animation)
    cells[ANCHOR_CELL] = { cells[ANCHOR_CELL], disc(animation) }
    state_sprites[animation] = cells
end

-- The steady states wear a status glyph on the south cell.
for _, run in ipairs({ "standby", "active" }) do
    for _, status in ipairs(STATUSES) do
        local state = `{run}_{status}`
        table.insert(states, state)
        local cells: { any } = {}
        for index, picture in ipairs(state_sprites[run]) do
            cells[index] = picture
        end
        cells[SOUTH_CELL] = { cells[SOUTH_CELL], `grav_led_{status}` }
        state_sprites[state] = cells
    end
end

return {
    id = "grav_smes",
    visual_layer = "fixture",
    name_label = "lunatic/tfs:entity.grav_smes.name",
    name = "gravity battery",
    sprite = "grav_smes_standby_1_1",
    dense = true,
    opaque = false,
    category = "power",
    script = "grav_smes",
    examine = {
        flavor = "Four emitters and four supermagnet rings, welded around a core.",
    },
    footprint = footprint,
    states = states,
    palette_states = { "standby", "active" },
    state_sprites = state_sprites,
    transitions = {
        {
            sound = "smash",
            at = "welded",
            with = { metal = CLAMP_METAL },
            secs = 4.0,
            to = "clamped",
            start = "lunatic/tfs:entity.grav_smes.clamp.start",
            done = "lunatic/tfs:entity.grav_smes.clamp.done",
        },
        {
            sound = "smash",
            at = "clamped",
            with = { cable_coil = CABLE_COILS },
            secs = 6.0,
            to = "wired",
            start = "lunatic/tfs:entity.grav_smes.wire.start",
            done = "lunatic/tfs:entity.grav_smes.wire.done",
        },
        {
            sound = "ratchet",
            at = "wired",
            with = { pipe = PIPE_LENGTHS },
            secs = 6.0,
            to = "piped",
            start = "lunatic/tfs:entity.grav_smes.pipe.start",
            done = "lunatic/tfs:entity.grav_smes.pipe.done",
        },
        {
            sound = "smash",
            at = "piped",
            with = { metal = CASING_METAL },
            secs = 8.0,
            to = "cased",
            start = "lunatic/tfs:entity.grav_smes.case.start",
            done = "lunatic/tfs:entity.grav_smes.case.done",
        },
        -- The glass fits the south cell alone; the other cells refuse it
        -- in the script before this step can see the click.
        {
            sound = "smash",
            at = "cased",
            with = { glass = 1 },
            secs = 3.0,
            to = "standby",
            start = "lunatic/tfs:entity.grav_smes.glaze.start",
            done = "lunatic/tfs:entity.grav_smes.glaze.done",
        },
        {
            sound = "crowbar",
            at = "standby",
            tool = "crowbar",
            secs = 3.0,
            yields = { glass = 1 },
            to = "cased",
            start = "lunatic/tfs:entity.grav_smes.unglaze.start",
            done = "lunatic/tfs:entity.grav_smes.unglaze.done",
        },
        {
            sound = "crowbar",
            at = "cased",
            tool = "crowbar",
            secs = 8.0,
            yields = { metal = CASING_METAL },
            to = "piped",
            start = "lunatic/tfs:entity.grav_smes.uncase.start",
            done = "lunatic/tfs:entity.grav_smes.uncase.done",
        },
        {
            sound = "ratchet",
            at = "piped",
            tool = "wrench",
            secs = 6.0,
            yields = { pipe = PIPE_LENGTHS },
            to = "wired",
            start = "lunatic/tfs:entity.grav_smes.unpipe.start",
            done = "lunatic/tfs:entity.grav_smes.unpipe.done",
        },
        {
            sound = "wirecutter",
            at = "wired",
            tool = "cutters",
            secs = 6.0,
            yields = { cable_coil = CABLE_COILS },
            to = "clamped",
            start = "lunatic/tfs:entity.grav_smes.unwire.start",
            done = "lunatic/tfs:entity.grav_smes.unwire.done",
        },
        {
            sound = "smash",
            at = "clamped",
            tool = "screwdriver",
            secs = 4.0,
            yields = { metal = CLAMP_METAL },
            to = "welded",
            start = "lunatic/tfs:entity.grav_smes.unclamp.start",
            done = "lunatic/tfs:entity.grav_smes.unclamp.done",
        },
    },
}
