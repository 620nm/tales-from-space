local ignition = require("@lib/ignition")

-- The gravity battery's assembly rules: where the eight parts must stand
-- and face, the wrench that sets a packed ring between two emitters, and the
-- torch weld that fuses the parts into one 3x3 machine.
--
-- Layout, center C, north up:  ring emitter ring / emitter C emitter /
-- ring emitter ring. An emitter's facing is the way its nozzle points, so
-- the north emitter faces south. A ring's facing names the corner arc it
-- draws: north is the north-west arc, then clockwise.

local grav_smes = {}

local WELDER = "welder"
local BODY = "grav_smes"
local EMITTER = "grav_emitter"
local PACKED_RING = "grav_supermagnet"
local RING = "grav_supermagnet_ring"
local ANCHORED = "anchored"
local WELDED = "welded"
local LIT = "lit"
-- Hint flags: whether this part's assembly would weld, and whether this
-- cart would set where it stands. The click inspects again, so a flag a
-- missed event left stale only misleads a tooltip.
grav_smes.ASSEMBLY_READY = "assembly_ready"
grav_smes.RING_FITS = "ring_fits"
-- Far enough to reach every part of an assembly from any one of them.
local REFRESH_TILES = 3

-- The welder's reservoir substance (items/tools/welder.luau `fuel`).
local FUEL = "naphtha"
-- Pack-tuned: tg has no machine like this one. The weld takes three
-- times a tank-frame seam's fuel (tank.dm:675-697 spends 0.3).
local WELD_FUEL_MOLES = 0.9
local WELD_SECONDS = 6.0
local RING_SECONDS = 1.0

type PartSpec = {
    position: string,
    prototype: string,
    facing: string,
    dx: number,
    dy: number,
}

-- Fixed report order: emitters, then rings.
local PARTS: { PartSpec } = {
    { position = "n", prototype = EMITTER, facing = "south", dx = 0, dy = -1 },
    { position = "e", prototype = EMITTER, facing = "west", dx = 1, dy = 0 },
    { position = "s", prototype = EMITTER, facing = "north", dx = 0, dy = 1 },
    { position = "w", prototype = EMITTER, facing = "east", dx = -1, dy = 0 },
    { position = "nw", prototype = RING, facing = "north", dx = -1, dy = -1 },
    { position = "ne", prototype = RING, facing = "east", dx = 1, dy = -1 },
    { position = "se", prototype = RING, facing = "south", dx = 1, dy = 1 },
    { position = "sw", prototype = RING, facing = "west", dx = -1, dy = 1 },
}

local MESSAGE = "lunatic/tfs:lib.grav_smes."

-- Every message key this module speaks, for the roster file to define.
function grav_smes.message_keys(): { string }
    local keys = {
        MESSAGE .. "torch_unlit",
        MESSAGE .. "torch_empty",
        MESSAGE .. "blocked",
        MESSAGE .. "weld_start",
        MESSAGE .. "weld_stopped",
        MESSAGE .. "weld_done",
        MESSAGE .. "welded_fast",
        MESSAGE .. "glass_wrong_cell",
        MESSAGE .. "glass_start",
        MESSAGE .. "stop_first",
        MESSAGE .. "glass_done",
        MESSAGE .. "ring_too_few",
        MESSAGE .. "ring_too_many",
        MESSAGE .. "ring_opposite",
        MESSAGE .. "ring_blocked",
        MESSAGE .. "ring_needs_wrench",
        MESSAGE .. "ring_start",
        MESSAGE .. "ring_stopped",
        MESSAGE .. "ring_done",
    }
    for _, part in ipairs(PARTS) do
        table.insert(keys, MESSAGE .. "missing." .. part.position)
        table.insert(keys, MESSAGE .. "loose." .. part.position)
        table.insert(keys, MESSAGE .. "facing." .. part.position)
    end
    return keys
end

local function send(actor: Handle, key: string): ()
    sim.message.send({ recipient = actor, message = sim.msg(key, {}) })
end

local function part_at(tile: TileAddress, prototype: string): Handle?
    for _, candidate in ipairs(sim.query.range(tile, 0, {})) do
        if candidate.alive and candidate.prototype == prototype then
            return candidate
        end
    end
    return nil
end

-- Nil past the map's edge, which a part drifting in open space can reach.
local tile_beside = ignition.tile_beside

-- The center a standing part implies: the tile it would stand beside.
local function implied_centre(part: Handle): TileAddress?
    local tile = part.tile
    if tile == nil then
        return nil
    end
    local facing = part.facing or "north"
    for _, spec in ipairs(PARTS) do
        if spec.prototype == part.prototype and spec.facing == facing then
            return tile_beside(tile, -spec.dx, -spec.dy)
        end
    end
    return nil
end

type Inspection = {
    centre: TileAddress?,
    parts: { Handle },
    refusal: string?,
}

-- Walks the eight positions around the center `part` implies and names the
-- first thing wrong, in the player's words.
local function inspect(part: Handle): Inspection
    local result: Inspection = { centre = implied_centre(part), parts = {}, refusal = nil }
    local centre = result.centre
    if centre == nil then
        result.refusal = MESSAGE .. "blocked"
        return result
    end
    for _, spec in ipairs(PARTS) do
        local at = tile_beside(centre, spec.dx, spec.dy)
        local found = if at ~= nil then part_at(at, spec.prototype) else nil
        if found == nil and at ~= nil and spec.prototype == RING and part_at(at, PACKED_RING) ~= nil then
            result.refusal = MESSAGE .. "loose." .. spec.position
            return result
        end
        if found == nil then
            result.refusal = MESSAGE .. "missing." .. spec.position
            return result
        end
        if found.state ~= ANCHORED then
            result.refusal = MESSAGE .. "loose." .. spec.position
            return result
        end
        if found.facing ~= spec.facing then
            result.refusal = MESSAGE .. "facing." .. spec.position
            return result
        end
        table.insert(result.parts, found)
    end
    return result
end

type RingFit = {
    facing: string?,
    refusal: string?,
}

local function bolted_emitter_beside(tile: TileAddress, dx: number, dy: number): boolean
    local at = tile_beside(tile, dx, dy)
    local emitter = if at ~= nil then part_at(at, EMITTER) else nil
    return emitter ~= nil and emitter.state == ANCHORED
end

-- Which corner arc a ring takes on `tile`: exactly two bolted emitters must
-- meet at it, and the arc bends round the side they stand on.
local function ring_fit(tile: TileAddress): RingFit
    local north = bolted_emitter_beside(tile, 0, -1)
    local east = bolted_emitter_beside(tile, 1, 0)
    local south = bolted_emitter_beside(tile, 0, 1)
    local west = bolted_emitter_beside(tile, -1, 0)
    local count = 0
    for _, beside in ipairs({ north, east, south, west }) do
        if beside then
            count += 1
        end
    end
    if count < 2 then
        return { refusal = MESSAGE .. "ring_too_few" }
    end
    if count > 2 then
        return { refusal = MESSAGE .. "ring_too_many" }
    end
    if (north and south) or (east and west) then
        return { refusal = MESSAGE .. "ring_opposite" }
    end
    if south then
        return { facing = if east then "north" else "east" }
    end
    return { facing = if west then "south" else "west" }
end

local function ring_replacement(cart: Handle, fit: RingFit): StructureReplaceCommand
    return {
        remove = { cart },
        spawn = { definition = RING, at = assert(cart.tile), state = ANCHORED, facing = fit.facing },
    }
end

-- The packed ring's fit where it stands, as a command, or the refusal said aloud.
local function set_ring_command(cart: Handle, actor: Handle): StructureReplaceCommand?
    local tile = cart.tile
    if tile == nil then
        send(actor, MESSAGE .. "ring_blocked")
        return nil
    end
    local fit = ring_fit(tile)
    if fit.refusal ~= nil then
        send(actor, fit.refusal)
        return nil
    end
    local command = ring_replacement(cart, fit)
    if not sim.structure.can_replace(command).ok then
        send(actor, MESSAGE .. "ring_blocked")
        return nil
    end
    return command
end

-- A wrench on a packed ring: it unfolds into the corner arc between the two
-- emitters beside it, and refuses without them.
function grav_smes.set_ring(ev: InteractionUsePayload): boolean
    local cart, actor = ev.subject, ev.actor
    -- The `set_ring` row admits only a wrench.
    local wrench = assert(ev.implement)
    if set_ring_command(cart, actor) == nil then
        return true
    end
    send(actor, MESSAGE .. "ring_start")
    sim.sound.play({ sound = "ratchet", at = assert(cart.tile) })
    sim.spawn_task(actor, function()
        if sim.do_after(actor, sim.ticks(RING_SECONDS), {}) ~= "ok" then
            if actor.alive then
                send(actor, MESSAGE .. "ring_stopped")
            end
            return
        end
        if not actor.alive or not cart.alive or not wrench.alive then
            return
        end
        -- A second look: the cart and the emitters are as free to move as
        -- the actor is.
        local command = set_ring_command(cart, actor)
        if command == nil then
            return
        end
        sim.structure.replace(command)
        sim.sound.play({ sound = "ratchet", at = assert(cart.tile) })
        send(actor, MESSAGE .. "ring_done")
    end)
    return true
end

-- The row every emitter and set ring shares. Both reasons are `hint_only`:
-- `weld` says exactly what is wrong when it is clicked.
function grav_smes.weld_row(): { [string]: any }
    return {
        id = "weld",
        gesture = "primary",
        route = "receiver",
        label = "lunatic/tfs:ui.affordance.weld_assembly",
        held = { fact = "held.proto", value = WELDER },
        uses_held = true,
        suggest_implement = { item = WELDER },
        refuse = {
            {
                when = { ["not"] = { fact = "target.flag", value = grav_smes.ASSEMBLY_READY } },
                label = MESSAGE .. "weld_incomplete",
                hint_only = true,
            },
            {
                when = {
                    all = {
                        { fact = "held.proto", value = WELDER },
                        { ["not"] = { fact = "held.state", value = LIT } },
                    },
                },
                label = MESSAGE .. "torch_unlit",
                hint_only = true,
            },
        },
    }
end

local function mark(part: Handle): ()
    if part.prototype == EMITTER or part.prototype == RING then
        sim.hints.set_flag({
            entity = part,
            flag = grav_smes.ASSEMBLY_READY,
            on = inspect(part).refusal == nil,
        })
    elseif part.prototype == PACKED_RING then
        local tile = part.tile
        sim.hints.set_flag({
            entity = part,
            flag = grav_smes.RING_FITS,
            on = tile ~= nil and ring_fit(tile).refusal == nil,
        })
    end
end

local function refresh_around(part: Handle): ()
    local tile = if part.alive then part.tile else nil
    if tile == nil then
        return
    end
    for _, near in ipairs(sim.query.range(tile, REFRESH_TILES, {})) do
        if near.alive then
            mark(near)
        end
    end
end

-- Keeps a part's hint flags, and those of the parts around it, in step
-- with anything that stands, moves or changes state.
function grav_smes.track(definition: any): ()
    definition:handle("entity.initialize.done", { kind = "react" }, function(ev)
        refresh_around(ev.entity)
    end)
    definition:handle("entity.location.changed", { kind = "react" }, function(ev)
        refresh_around(ev.entity)
    end)
    definition:handle("structure.changed", { kind = "react" }, function(ev)
        refresh_around(ev.structure)
    end)
end

local function fuel_moles(torch: Handle): number
    local read = sim.matter_read(torch)
    if read == nil then
        return 0
    end
    local fuel = read.contents[FUEL]
    return if fuel then (fuel.liquid or 0) + (fuel.gas or 0) + (fuel.solid or 0) else 0
end

-- A torch problem, as a message key.
local function torch_refusal(torch: Handle): string?
    if torch.state ~= LIT then
        return MESSAGE .. "torch_unlit"
    end
    if fuel_moles(torch) < WELD_FUEL_MOLES then
        return MESSAGE .. "torch_empty"
    end
    return nil
end

local function replacement(centre: TileAddress): StructureReplaceSpawn
    return { definition = BODY, at = centre, state = WELDED }
end

-- A lit welder on any anchored emitter or set ring: fuses the eight parts
-- standing around the implied center into the machine.
function grav_smes.weld(ev: InteractionUsePayload): boolean | { replaced: boolean }
    local part, actor, torch = ev.subject, ev.actor, ev.implement
    if torch == nil or not torch.alive or torch.prototype ~= WELDER then
        return { replaced = false }
    end
    local torch_key = torch_refusal(torch)
    if torch_key ~= nil then
        send(actor, torch_key)
        return true
    end
    local inspection = inspect(part)
    if inspection.refusal ~= nil then
        send(actor, inspection.refusal)
        return true
    end
    local centre = assert(inspection.centre)
    local request: StructureReplaceRequest = { remove = inspection.parts, spawn = replacement(centre) }
    if not sim.structure.can_replace(request).ok then
        send(actor, MESSAGE .. "blocked")
        return true
    end
    send(actor, MESSAGE .. "weld_start")
    sim.spawn_task(actor, function()
        if sim.do_after(actor, sim.ticks(WELD_SECONDS), {}) ~= "ok" then
            if actor.alive then
                send(actor, MESSAGE .. "weld_stopped")
            end
            return
        end
        if not actor.alive or not part.alive or not torch.alive then
            return
        end
        -- A second look: the work took time, and the torch and the parts
        -- are as free to change as the actor is.
        local torch_again = torch_refusal(torch)
        if torch_again ~= nil then
            send(actor, torch_again)
            return
        end
        local again = inspect(part)
        if again.refusal ~= nil then
            send(actor, again.refusal)
            return
        end
        local centre_again = assert(again.centre)
        local fresh: StructureReplaceCommand = { remove = again.parts, spawn = replacement(centre_again) }
        if not sim.structure.can_replace(fresh).ok then
            send(actor, MESSAGE .. "blocked")
            return
        end
        sim.structure.replace(fresh)
        sim.matter.extract({
            owner = torch,
            amount = WELD_FUEL_MOLES,
            phases = { "liquid", "gas", "solid" },
            substance = FUEL,
        })
        send(actor, MESSAGE .. "weld_done")
    end)
    return true
end

return grav_smes
