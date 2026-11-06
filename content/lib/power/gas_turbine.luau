local assembly = require("@lib/assembly")
local ignition = require("@lib/ignition")
local multitool_buffer = require("@lib/tools/multitool_buffer")

-- The gas turbine's three sections and its console: what each section
-- declares, and the discrete verbs tg's turbine.dm and turbine_computer.dm
-- run at a click. A compressor stands behind the core rotor and the outlet
-- ahead of it, along the rotor's facing; the rotor checks the line, the
-- multitool carries the rotor to the console. Running is
-- lib/power/gas_turbine_run.luau and gas_turbine_turns.luau.
local gas_turbine = {}

gas_turbine.COMPRESSOR = "inlet_compressor"
gas_turbine.CORE = "core_rotor"
gas_turbine.OUTLET = "turbine_outlet"
gas_turbine.CONSOLE = "turbine_computer"
gas_turbine.SECTIONS = { gas_turbine.COMPRESSOR, gas_turbine.CORE, gas_turbine.OUTLET }

local CLOSED = "closed"
local OPEN = "open"
local RUNNING = "running"
local MULTITOOL = "multitool"

-- Panel shut, panel open (tg's `panel_open`), then shut and turning (tg's
-- `<prefix>_on` overlay while the rotor is active, turbine.dm:117-128).
gas_turbine.STATES = { CLOSED, OPEN, RUNNING }
gas_turbine.CLOSED = CLOSED
gas_turbine.RUNNING = RUNNING
-- The states the running loop moves a section between; the panel steps
-- own the rest (the engine's docs/content-schema/structures.md).
gas_turbine.SCRIPTED_STATES = { CLOSED, RUNNING }
-- tg's machines default to SOUTH.
gas_turbine.FACINGS = { "south", "west", "north", "east" }

-- Whether the rotor last found its line whole (tg `all_parts_connected`).
-- A reader asks `connected`, which checks the line again.
gas_turbine.LINKED = "lunatic/tfs:turbine_linked"
-- The rotor a console is linked to, as a buffer ref (tg `turbine_core`).
gas_turbine.CONSOLE_LINK = "lunatic/tfs:turbine_core"
-- The rotor's map knob: a placement that sets it starts the rotor's first
-- run once its line links at stand-up (lib/power/gas_turbine_run.luau).
gas_turbine.STARTS_RUNNING = "lunatic/tfs:turbine_starts_running"

-- Every line is the pack's own sentence for one of tg's: the refusals for
-- the balloons of turbine.dm:519-558, `linked` and `buffer_stored` for
-- :466 and :469, `wrong_buffer`, `relinking` and `console_linked` for
-- turbine_computer.dm:27, :30 and :36.
local MESSAGE = "lunatic/tfs:lib.gas_turbine."
local REFUSALS = {
    "wrong_way",
    "missing_compressor",
    "compressor_misaligned",
    "compressor_panel_open",
    "missing_turbine",
    "turbine_misaligned",
    "turbine_panel_open",
    "not_facing_away",
}
-- A running section's panel stays shut (`screwdriver_act`, turbine.dm:169-171).
local STOP_FIRST = MESSAGE .. "stop_first"
-- The rotor's examine hint while its line is not linked (turbine.dm:438-439).
local UNLINKED = MESSAGE .. "unlinked"

-- Every key this module sends, for the roster file to define.
function gas_turbine.message_keys(): { string }
    local keys = {
        MESSAGE .. "linked",
        MESSAGE .. "buffer_stored",
        MESSAGE .. "wrong_buffer",
        MESSAGE .. "relinking",
        MESSAGE .. "console_linked",
        STOP_FIRST,
        UNLINKED,
    }
    for _, refusal in ipairs(REFUSALS) do
        table.insert(keys, MESSAGE .. refusal)
    end
    return keys
end

local SUFFIX: { [string]: string } = { north = "n", south = "s", east = "e", west = "w" }
local STEP: { [string]: { number } } = {
    north = { 0, -1 },
    south = { 0, 1 },
    east = { 1, 0 },
    west = { -1, 0 },
}
local REVERSE: { [string]: string } =
    { north = "south", south = "north", east = "west", west = "east" }

-- `<prototype>_<state>_<n|s|e|w>`, baked in assets/sprites/63-gas-turbine.ron.
function gas_turbine.facing_sprites(prototype: string): { [string]: { [string]: string } }
    local pictures: { [string]: { [string]: string } } = {}
    for _, state in ipairs(gas_turbine.STATES) do
        local row: { [string]: string } = {}
        for _, facing in ipairs(gas_turbine.FACINGS) do
            row[facing] = prototype .. "_" .. state .. "_" .. SUFFIX[facing]
        end
        pictures[state] = row
    end
    return pictures
end

-- A section's panel and teardown. The screwdriver toggles the panel at no
-- delay (`screwdriver_act`, turbine.dm:167-184), and is refused while the
-- turbine runs (:169-171); the crowbar takes an
-- open section apart at no delay (`default_deconstruction_crowbar`,
-- _machinery.dm:912-923), leaving the frame it came from with the board,
-- the board's ten units and the frame's five lengths of cable.
function gas_turbine.section_transitions(prototype: string): { { [string]: any } }
    local words = "lunatic/tfs:entity." .. prototype .. "."
    return {
        {
            sound = "smash",
            at = CLOSED,
            tool = "screwdriver",
            to = OPEN,
            hint = { label = "lunatic/tfs:ui.affordance.open_panel" },
            done = "lunatic/tfs:lib.gas_turbine.panel_opened",
        },
        {
            sound = "smash",
            at = OPEN,
            tool = "screwdriver",
            to = CLOSED,
            hint = { label = "lunatic/tfs:ui.affordance.close_panel" },
            done = "lunatic/tfs:lib.gas_turbine.panel_closed",
        },
        {
            at = RUNNING,
            tool = "screwdriver",
            hint = { label = "lunatic/tfs:ui.affordance.open_panel" },
            refuse = { { when = true, label = STOP_FIRST } },
        },
        {
            sound = "crowbar",
            at = OPEN,
            tool = "crowbar",
            hint = assembly.back("lunatic/tfs:ui.affordance.deconstruct"),
            gone = true,
            leaves = "machine_frame",
            yields = {
                ["machine_board." .. prototype] = 1,
                cable_coil = 10,
                metal = 5,
            },
            done = words .. "deconstructed",
        },
    }
end

-- The multitool row on the core rotor, the pack's words for tg's
-- "Link/Log parts" screentip (turbine.dm:427-432), offered with the panel shut.
function gas_turbine.link_parts_row(): { [string]: any }
    return {
        id = "link_parts",
        gesture = "primary",
        route = "receiver",
        label = "lunatic/tfs:ui.affordance.link_parts",
        target = { fact = "target.state", value = CLOSED },
        held = { fact = "held.proto", value = MULTITOOL },
        uses_held = true,
        suggest_implement = { item = MULTITOOL },
    }
end

-- The multitool row on the console (`multitool_act`, turbine_computer.dm:24-37).
function gas_turbine.link_console_row(): { [string]: any }
    return {
        id = "link_console",
        gesture = "primary",
        route = "receiver",
        label = "lunatic/tfs:ui.affordance.link_console",
        held = { fact = "held.proto", value = MULTITOOL },
        uses_held = true,
        suggest_implement = { item = MULTITOOL },
    }
end

local function send(actor: Handle, key: string): ()
    sim.message.send({ recipient = actor, message = sim.msg(MESSAGE .. key, {}) })
end

local function prototype_of(thing: Handle): string?
    return thing.base or thing.prototype
end

local function beside(tile: TileAddress, facing: string, sign: number): TileAddress?
    local step = STEP[facing]
    return ignition.tile_beside(tile, step[1] * sign, step[2] * sign)
end

local function section_at(tile: TileAddress?, prototype: string): Handle?
    if tile == nil then
        return nil
    end
    for _, candidate in ipairs(sim.query.range(tile, 0, {})) do
        if candidate.alive and prototype_of(candidate) == prototype then
            return candidate
        end
    end
    return nil
end

-- Every section declares `facings`, so its handle always reads one.
local function facing_of(section: Handle): string
    local facing = section.facing
    if facing == nil then
        error("gas_turbine: " .. tostring(prototype_of(section)) .. " reads no facing")
    end
    return facing
end

local function aligned(section: Handle, facing: string): boolean
    local own = facing_of(section)
    return own == facing or own == REVERSE[facing]
end

-- The tile one step along a section's own facing (`get_step(loc, dir)`), or
-- one step behind it with `sign = -1`; nil past the map edge.
function gas_turbine.along(section: Handle, sign: number): TileAddress?
    return beside(section.tile, facing_of(section), sign)
end

-- The compressor behind a rotor and the outlet ahead of it, either nil
-- where none stands; `inspect` says whether they make a line.
function gas_turbine.ends(core: Handle): (Handle?, Handle?)
    return section_at(gas_turbine.along(core, -1), gas_turbine.COMPRESSOR),
        section_at(gas_turbine.along(core, 1), gas_turbine.OUTLET)
end

-- The rotor a section turns with: itself, the one ahead of a compressor, or
-- the one behind an outlet; nil where none stands.
function gas_turbine.core_of(section: Handle): Handle?
    local kind = prototype_of(section)
    if kind == gas_turbine.CORE then
        return section
    end
    local sign = if kind == gas_turbine.COMPRESSOR
        then 1
        elseif kind == gas_turbine.OUTLET then -1
        else 0
    if sign == 0 then
        return nil
    end
    return section_at(gas_turbine.along(section, sign), gas_turbine.CORE)
end

-- tg's `core_rotor/activate_parts` (turbine.dm:497-572), its checks in its
-- order: nil when the line is whole, else the refusal it names. The part
-- checks fall away: a section's socket cannot stand empty here.
function gas_turbine.inspect(core: Handle): string?
    local tile = core.tile
    local facing = facing_of(core)
    local behind, ahead = beside(tile, facing, -1), beside(tile, facing, 1)
    local compressor = section_at(behind, gas_turbine.COMPRESSOR)
    local turbine = section_at(ahead, gas_turbine.OUTLET)
    if compressor == nil and turbine == nil then
        local reversed = section_at(ahead, gas_turbine.COMPRESSOR) ~= nil
            or section_at(behind, gas_turbine.OUTLET) ~= nil
        if reversed then
            return "wrong_way"
        end
    end
    if compressor == nil then
        return "missing_compressor"
    end
    if not aligned(compressor, facing) then
        return "compressor_misaligned"
    end
    if compressor.state == OPEN then
        return "compressor_panel_open"
    end
    if turbine == nil then
        return "missing_turbine"
    end
    if not aligned(turbine, facing) then
        return "turbine_misaligned"
    end
    if turbine.state == OPEN then
        return "turbine_panel_open"
    end
    -- tg: the two face the same way, which reads as facing apart (:556-559).
    if facing_of(compressor) ~= facing_of(turbine) then
        return "not_facing_away"
    end
    return nil
end

-- Checks the line and remembers the answer; an actor hears a refusal.
local function link(core: Handle, actor: Handle?): boolean
    local refusal = gas_turbine.inspect(core)
    core.vars[gas_turbine.LINKED] = if refusal == nil then true else nil
    if refusal ~= nil and actor ~= nil then
        send(actor, refusal)
    end
    return refusal == nil
end

-- Whether the rotor's line is linked and still whole: tg's `check_only`
-- pass (turbine.dm:626). A section gone without its panel opening first (a
-- blast, a staff delete) leaves the flag stale, which this read clears.
function gas_turbine.connected(core: Handle): boolean
    return core.vars[gas_turbine.LINKED] == true and link(core, nil)
end

-- The rotors a section can belong to: itself, or one a step away.
local function cores_around(section: Handle): { Handle }
    if prototype_of(section) == gas_turbine.CORE then
        return { section }
    end
    local cores: { Handle } = {}
    for _, facing in ipairs(gas_turbine.FACINGS) do
        local core = section_at(beside(section.tile, facing, 1), gas_turbine.CORE)
        if core ~= nil then
            table.insert(cores, core)
        end
    end
    return cores
end

-- An opened panel breaks the line (tg `deactivate_parts`, turbine.dm:229-234,
-- :302-307, :355-360, :575-586): every linked rotor beside a section asks again.
local function recheck_around(section: Handle): ()
    if prototype_of(section) == gas_turbine.CORE then
        section.vars[gas_turbine.LINKED] = nil
        return
    end
    for _, core in ipairs(cores_around(section)) do
        gas_turbine.connected(core)
    end
end

-- `entity.initialize.done` on every section, mapped or built: the line links
-- silently, as tg's `post_machine_initialize` -> `activate_parts` does
-- (turbine.dm:39-42). tg runs it from the rotor; here whichever section
-- stands up last completes the line, so each asks the rotors beside it.
function gas_turbine.on_section_initialized(ev: EntityInitializeDonePayload): ()
    local section = ev.entity
    if not section.alive then
        return
    end
    for _, core in ipairs(cores_around(section)) do
        link(core, nil)
    end
end

-- `structure.changed` on every section. Shutting the rotor's own panel
-- links the line or says why not (`screwdriver_act` -> `activate_parts`,
-- turbine.dm:178-181).
function gas_turbine.on_section_changed(ev: StructureChangedPayload): ()
    local section = ev.structure
    if ev.previous == ev.state or not section.alive then
        return
    end
    if ev.state == OPEN then
        recheck_around(section)
    elseif
        ev.state == CLOSED
        and ev.previous == OPEN
        and prototype_of(section) == gas_turbine.CORE
    then
        link(section, ev.actor)
    end
end

local function multitool_in(ev: InteractionUsePayload): Handle?
    local tool = ev.implement
    if tool == nil or not tool.alive or prototype_of(tool) ~= MULTITOOL then
        return nil
    end
    return tool
end

-- A multitool on the rotor, panel shut: link the line and log the rotor
-- in the buffer (`multitool_act`, turbine.dm:456-472). An open panel is
-- tg's cable-layer change, which this pack has no use for.
function gas_turbine.link_parts(ev: InteractionUsePayload): boolean | { replaced: boolean }
    local core, actor = ev.subject, ev.actor
    local tool = multitool_in(ev)
    if tool == nil or core.state ~= CLOSED then
        return { replaced = false }
    end
    if link(core, actor) then
        send(actor, "linked")
        multitool_buffer.store(tool, core)
        send(actor, "buffer_stored")
    end
    return true
end

-- How long tg's console takes to read the buffer (turbine_computer.dm:31).
local CONSOLE_LINK_SECONDS = 0.2
local CONSOLE_CLICK_VOLUME = 0.1

-- A multitool on the console: link the rotor in its buffer
-- (`multitool_act`, turbine_computer.dm:24-37). A buffer naming a rotor
-- taken apart, or rebuilt since it was logged, names no rotor.
function gas_turbine.link_console(ev: InteractionUsePayload): boolean | { replaced: boolean }
    local console, actor = ev.subject, ev.actor
    local tool = multitool_in(ev)
    if tool == nil then
        return { replaced = false }
    end
    local core = multitool_buffer.read(tool)
    if core == nil or prototype_of(core) ~= gas_turbine.CORE then
        send(actor, "wrong_buffer")
        return true
    end
    -- tg says so whenever the console already holds a link (:29-30).
    if console.vars[gas_turbine.CONSOLE_LINK] ~= nil then
        send(actor, "relinking")
    end
    sim.spawn_task(actor, function()
        if sim.do_after(actor, sim.ticks(CONSOLE_LINK_SECONDS), {}) ~= "ok" then
            return
        end
        if not actor.alive or not console.alive or not core.alive then
            return
        end
        -- tg clicks at the user's turf, volume 10 of 100 (:34).
        sim.sound.play({ sound = "click", at = actor.tile, volume = CONSOLE_CLICK_VOLUME })
        console.vars[gas_turbine.CONSOLE_LINK] = core:ref()
        send(actor, "console_linked")
    end)
    return true
end

-- `examine.lines` on the core rotor: the unlinked hint, read from the
-- remembered flag as tg's `examine` reads `all_parts_connected`. A read,
-- never an effect.
function gas_turbine.examine_lines(ev: ExamineLinesPayload): { lines: { ExamineLineRow } }
    local lines = table.clone(ev.lines)
    if ev.subject.vars[gas_turbine.LINKED] ~= true then
        table.insert(lines, { key = "turbine_unlinked", text = sim.msg(UNLINKED, {}) })
    end
    return { lines = lines }
end

return gas_turbine
