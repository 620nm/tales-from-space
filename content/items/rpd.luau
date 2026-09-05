-- The rapid pipe dispenser: the whole atmospherics kit in one hand.
--
-- tg's `/obj/item/pipe_dispenser` (code/game/objects/items/rcd/RPD.dm).
-- It is the pipe dispenser's answer to walking back and forth: instead
-- of a fitting you carry and then wrench, the RPD conjures the fitting
-- and fastens it in the same motion (`do_pipe_build`, RPD.dm:552-572,
-- where the device hands ITSELF to the fitting's `wrench_act`). Free,
-- unlimited, 0.4 s a piece.
--
-- THE THREE QUESTIONS a technician has to answer before any of that is
-- useful — which fitting, which piping layer, which paint — are more
-- than a cycling key can carry, so this device wears a window
-- (`sim/ui/settings/dials.rs`) the way tg's does. Press the in-hand key
-- to open it; every dial below is a row of buttons in it, and the
-- caption on each row is also a button that steps to the next position.
--
-- WHAT IS NOT HERE, and deliberately:
--
-- * tg's D-pad of connection restrictions for smart pipe (`p_init_dir`,
--   RPD.dm:232-253). We have no smart pipe, so there is nothing to
--   restrict.
-- * tg's in-window rotation (`p_dir`). Loose fittings rotate directly
--   with Alt+left/Alt+right in this engine; flipped trinaries remain
--   explicit recipes, so there is no second direction dial here.
-- * tg's multi-layer build, which lays the same run on several layers
--   at once. One layer, one length: the dial names it.
-- * A colour on a DEVICE. Only the run under the deck carries one today
--   (pipes/paint.rs). The LAYER dial, by contrast, reaches everything
--   this shelf dispenses: tg programs the fitting it is about to wrench
--   down (RPD.dm:569) and every `/obj/item/pipe` carries a
--   `piping_layer`, so the optional fitting mode on `sim.fit` carries
--   the dial's position onto the part. Only the socket and the layer
--   adapter are deaf to it, and both for reasons the engine owns.

-- The shelf, in tg's own order and words (`GLOB.atmos_pipe_recipes`,
-- code/_globalvars/lists/pipe_recipes.dm), as far as this pack has
-- entries for it. `structure` names what stands up; the one row without
-- one is pipe itself, which is not a structure at all but a length in
-- the grid under the deck.
local RECIPES = {
    { label = "Pipe", item = "pipe", icon = "pipe", group = "Pipes" },
    { label = "Manual Valve", item = "manual_valve_fitting", structure = "manual_valve", icon = "manual_valve_loose", group = "Binary Devices" },
    { label = "Digital Valve", item = "digital_valve_fitting", structure = "digital_valve", icon = "digital_valve_loose", group = "Binary Devices" },
    { label = "Pump", item = "pump_fitting", structure = "pump", icon = "pump_loose", group = "Binary Devices" },
    { label = "Volume Pump", item = "volume_pump_fitting", structure = "volume_pump", icon = "volume_pump_loose", group = "Binary Devices" },
    { label = "Passive Gate", item = "passive_gate_fitting", structure = "passive_gate", icon = "passive_gate_loose", group = "Binary Devices" },
    { label = "Pressure Valve", item = "pressure_valve_fitting", structure = "pressure_valve", icon = "pressure_valve_loose", group = "Binary Devices" },
    { label = "Filter", item = "filter_fitting", structure = "filter", icon = "filter_fitting", group = "Trinary Devices" },
    { label = "Filter (flipped)", item = "filter_flipped_fitting", structure = "filter.flipped", icon = "filter_fitting", group = "Trinary Devices" },
    { label = "Mixer", item = "mixer_fitting", structure = "mixer", icon = "mixer_fitting", group = "Trinary Devices" },
    { label = "Mixer (flipped)", item = "mixer_flipped_fitting", structure = "mixer.flipped", icon = "mixer_fitting", group = "Trinary Devices" },
    { label = "Connector", item = "connector_port_fitting", structure = "connector_port", icon = "connector_port_loose", group = "Fittings & Adapters", fixed_layer = true },
    { label = "Meter", item = "pipe_meter", structure = "meter", icon = "pipe_meter", group = "Fittings & Adapters" },
    { label = "Layer Adapter", item = "layer_adapter_fitting", structure = "layer_adapter", icon = "layer_adapter_loose", group = "Fittings & Adapters", fixed_layer = true },
    { label = "Color Adapter", item = "color_adapter_fitting", structure = "color_adapter", icon = "color_adapter_loose", group = "Fittings & Adapters" },
    { label = "Temperature Gate", item = "temperature_gate_fitting", structure = "temperature_gate", icon = "temperature_gate_loose", group = "Thermal Devices" },
    { label = "Temperature Pump", item = "temperature_pump_fitting", structure = "temperature_pump", icon = "temperature_pump_loose", group = "Thermal Devices" },
    { label = "Heat Exchanger", item = "heat_exchanger_fitting", structure = "heat_exchanger", icon = "heat_exchanger_loose", group = "Thermal Devices" },
    -- tg's "Heat Exchange" category, in tg's own words
    -- (`GLOB.atmos_pipe_recipes`, _globalvars/lists/pipe_recipes.dm:29-34).
    -- tg lists "Pipe", "Manifold" and "4-Way Manifold" separately because
    -- each is a different OBJECT there; here a length's shape is derived
    -- from what it joins, so all three are one entry and a manifold is
    -- what you get by running a fourth length into a tee. The plate tg
    -- lists last is already on the shelf above, with the rest of the
    -- thermal kit.
    { label = "Pipe", item = "he_pipe", icon = "he_pipe", group = "Heat Exchange", paints = false },
    { label = "Junction", item = "he_junction_fitting", structure = "he_junction", icon = "he_junction_loose", group = "Heat Exchange" },
    { label = "Air Scrubber", item = "air_scrubber_fitting", structure = "air_scrubber", icon = "air_scrubber_loose", group = "Room Devices" },
    { label = "Air Injector", item = "air_injector_fitting", structure = "air_injector", icon = "air_injector_loose", group = "Room Devices" },
    { label = "Air Vent", item = "vent_fitting", structure = "vent", icon = "vent_loose", group = "Room Devices" },
    { label = "Passive Vent", item = "passive_vent_fitting", structure = "passive_vent", icon = "passive_vent_loose", group = "Room Devices" },
}

-- tg's destroy mode accepts `/obj/item/pipe` and pipe meters, not an
-- arbitrary wrench or sandwich which happened to be on the same turf.
-- The RPD's own shelf is the authoritative roster of implemented pipe
-- construction items, so it cannot drift from the build recipes.
local BREAKDOWN = {}
for _, recipe in ipairs(RECIPES) do
    BREAKDOWN[recipe.item] = true
end

-- The painter and the map editor read the same content-owned roster.
local COLORS = pipe_paints.colors

-- The five piping layers as bitmasks, the same list the length of pipe
-- carries (items/pipe.luau; PIPING_LAYER_MIN..MAX,
-- __DEFINES/atmospherics/atmos_piping.dm:78-80).
local LAYERS = { 1, 2, 4, 8, 16 }

local BUILD, DESTROY, COPY = 0, 1, 2

local function recipe_of(self)
    return RECIPES[sim.dial(self, "recipe").index + 1]
end

local function layer_of(self)
    return LAYERS[sim.dial(self, "layer").index + 1]
end

local function paint_of(self)
    return COLORS[sim.dial(self, "paint").index + 1]
end

-- Pipe is subfloor infrastructure: you lay it where the deck is open
-- and put the floor back over it. The engine refuses a covered deck
-- silently, so this says why first — a refusal with no explanation
-- reads as a dropped click.
local function lay_run(self, recipe, user, x, y, at)
    if not sim.subfloor_exposed(x, y) then
        sim.message.send({
            recipient = user,
            message = sim.msg("lunatic/tfs:lib.subfloor.covered", {}),
        })
        return
    end
    local mask = layer_of(self)
    if sim.pipe_occupancy(x, y) % (mask * 2) >= mask then
        sim.message.send({
            recipient = user,
            message = sim.msg("lunatic/tfs:lib.pipe.layer_taken", {}),
        })
        return
    end
    if sim.pipe(x, y) % (mask * 2) >= mask then
        sim.message.send({
            recipient = user,
            message = sim.msg("lunatic/tfs:lib.pipe.occupied", {}),
        })
        return
    end
    -- tg's `atmos_build_speed` (RPD.dm:53). Half of what the same
    -- length costs by hand, which is the whole reason to carry one.
    sim.spawn_task(user, function()
        if sim.do_after(user, sim.ticks(0.4), {}) == "interrupted" then
            return
        end
        -- The same question at the end: while you worked, another engineer
        -- may have run the line through this very tile.
        mask = layer_of(self)
        if sim.pipe_occupancy(x, y) % (mask * 2) >= mask then
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:lib.pipe.layer_taken", {}),
            })
            return
        end
        if sim.pipe(x, y) % (mask * 2) >= mask then
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:lib.pipe.occupied", {}),
            })
            return
        end
        -- WHICH kind of length, as the item it comes on. A kind with a
        -- colour of its own takes no paint at all (the engine refuses
        -- it), so the paint dial simply does not reach that row.
        sim.lay_pipe(x, y, mask, recipe.item)
        if recipe.paints ~= false then
            sim.paint_pipe(x, y, mask, paint_of(self).hex)
        end
        sim.sound.play({ asset = "lunatic/tfs:sound/ratchet", at = at })
    end)
end

local content = {
    id = "rpd",
    name = "rapid pipe dispenser",
    -- tg's own art off the tool sheet (`icon_state = "rpd"`, RPD.dm:26).
    sprite = "rpd",
    ui = { modules = { "dials" } },
    inhand_sprite = { "held_pipe_l", "held_pipe_r" },
    -- tg RPD.dm:39-40.
    pickup_sound = "rpd_pickup",
    drop_sound = "rpd_drop",
    -- Loose-pipe breakdown is aimed at the fitting lying on the deck,
    -- and a click that names one would otherwise pocket it
    -- (interact/click.rs step 8). tg's `interact_with_atom` reaches the
    -- same atom.
    acts_on_items = true,
    dials = {
        {
            key = "mode",
            label = "Mode",
            -- tg carries BUILD, WRENCH, DESTROY and REPROGRAM as
            -- independent flags (RPD.dm:7-10) and defaults to all of
            -- them at once, so its build mode always wrenches. Ours are
            -- exclusive positions because "dispense but do not connect"
            -- is not a thing anyone wants; Copy is tg's right-click
            -- eyedropper (RPD.dm:481-491) given a position of its own,
            -- since we have no secondary-click channel.
            options = { "Build", "Destroy", "Copy" },
        },
        { key = "recipe", label = "Fitting", options = (function()
            local names = {}
            for i, r in ipairs(RECIPES) do
                names[i] = r.label
            end
            return names
        end)(), icons = (function()
            local icons = {}
            for i, r in ipairs(RECIPES) do
                icons[i] = r.icon
            end
            return icons
        end)(), groups = (function()
            local groups = {}
            for i, r in ipairs(RECIPES) do
                groups[i] = r.group
            end
            return groups
        end)() },
        {
            key = "layer",
            label = "Piping layer",
            options = { "1", "2", "3", "4", "5" },
            -- PIPING_LAYER_DEFAULT, the distribution run
            -- (atmos_piping.dm:80, and tg's own `PIPE_LAYER(3)`,
            -- RPD.dm:61).
            start = 2,
        },
        {
            key = "paint",
            label = "Paint",
            options = (function()
                local names = {}
                for i, c in ipairs(COLORS) do
                    names[i] = c.name
                end
                return names
            end)(),
            colors = (function()
                local colors = {}
                for i, c in ipairs(COLORS) do
                    colors[i] = c.hex
                end
                return colors
            end)(),
            -- tg ships `paint_color = "green"` (RPD.dm:51).
            start = 1,
        },
    },
    -- tg's `attack_self` is `ui_interact(user)` (RPD.dm:124-125): the
    -- in-hand key or tg-style pickup double-click opens its window.
}

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    script_definition:handle("interaction.use", { kind = "replace", route = "self" }, function(ev)
        local self, user = ev.subject, ev.actor
        ui.open({ viewer = user, owner = self })
        return true
    end)
    script_definition:handle("interaction.use", { kind = "replace", route = "use" }, function(ev)
        local self, user, x, y, choice = ev.subject, ev.actor, ev.at.x, ev.at.y, ev.choice
        local clicked, target = ev.claim, ev.claim
        local _x, _y, _choice = x, y, choice
        local mode = sim.dial(self, "mode").index
        local loose_item = nil
        if target and target.kind == "item" then
            loose_item = target.entity.prototype
        end
        local can_break_down = loose_item and BREAKDOWN[loose_item]

        -- tg ships with BUILD_MODE and DESTROY_MODE enabled together,
        -- and tests the exact loose pipe branch before do_pipe_build.
        -- Our dial exposes the modes separately, but Build keeps that
        -- ordering: clicking a pipe construction item breaks down that
        -- named item instead of constructing another one over it.
        if mode == DESTROY or (mode == BUILD and can_break_down) then
            -- Loose things only, and only the one the click named. tg
            -- deletes the `/obj/item/pipe` or `/obj/item/pipe_meter` it
            -- was aimed at and nothing else (RPD.dm:324-340) — an
            -- anchored machine is unwrenched, never dissolved, and the
            -- engine agrees by construction: a structure is not an item
            -- and `sim.consume` has nothing to spend of one.
            if not can_break_down then
                sim.message.send({
                    recipient = user,
                    message = sim.msg("lunatic/tfs:items.rpd.there_is_nothing_loose_there", {}),
                })
                return true
            end
            target.entity:consume()
            sim.sound.play({ asset = "lunatic/tfs:sound/smash", at = ev.at })
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:items.rpd.broke_down", {
                    thing = target.entity.name,
                }),
            })
            return true
        end

        if mode == COPY then
            -- tg's eyedropper: point it at something already down and
            -- the RPD takes that thing's colour and layer
            -- (`interact_with_atom_secondary`, RPD.dm:481-491). tg reads
            -- them off the DEVICE; we read them off the run, which is
            -- the only thing that carries either — and a run you have
            -- not opened the deck over is one you cannot see.
            if not sim.subfloor_exposed(x, y) then
                sim.message.send({
                    recipient = user,
                    message = sim.msg("lunatic/tfs:lib.subfloor.covered", {}),
                })
                return true
            end
            for index, mask in ipairs(LAYERS) do
                local hex = sim.pipe_paint(x, y, mask)
                if hex then
                    sim.set_dial(self, "layer", index - 1)
                    for c, color in ipairs(COLORS) do
                        if color.hex == hex then
                            sim.set_dial(self, "paint", c - 1)
                            sim.message.send({
                                recipient = user,
                                message = sim.msg("lunatic/tfs:items.rpd.copied", {
                                    layer = index,
                                    color = color.name,
                                }),
                            })
                            return true
                        end
                    end
                    -- A colour off the roster: the layer is still worth
                    -- taking, and saying so beats silence.
                    sim.message.send({
                        recipient = user,
                        message = sim.msg("lunatic/tfs:items.rpd.copied_unnamed", {
                            layer = index,
                        }),
                    })
                    return true
                end
            end
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:lib.pipe.none_here", {}),
            })
            return true
        end

        -- A named ordinary item is not the turf beneath it. It neither
        -- becomes a fitting nor disappears under the machine Build
        -- would otherwise create.
        if target and target.kind == "item" then
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:items.rpd.that_loose_item_is_not", {}),
            })
            return true
        end

        local recipe = recipe_of(self)
        if not recipe.structure then
            lay_run(self, recipe, user, x, y, ev.at)
            return true
        end
        -- Dispense and connect, tg's two defaults in one motion. Every
        -- refusal a pair of hands would meet is the engine's to give
        -- (reach, the tile rules, one fitting per turf, "there is no
        -- pipe under the floor here"), so there is nothing to re-check
        -- here — and nothing content could weaken if it tried.
        sim.spawn_task(user, function()
            if sim.do_after(user, sim.ticks(0.4), {}) == "interrupted" then
                return
            end
            -- The layer dial travels with the part. tg programs the
            -- fitting it is about to wrench down (`set_piping_layer`
            -- from the RPD's own `p_layer`, RPD.dm:569) and every
            -- `/obj/item/pipe` carries one, so this is not a special
            -- case for the gauge: it is what the dial has always been
            -- for.
            --
            -- The two exceptions are exceptions in the ENGINE: a socket
            -- binds on the run every dispenser hands out, and a layer
            -- adapter stands across all five at once and has no layer
            -- of its own (tg's PIPING_DEFAULT_LAYER_ONLY). Their
            -- fittings wear no dial, so asking for one would be a
            -- refusal rather than a setting.
            local fitting_mode = nil
            if not recipe.fixed_layer then
                fitting_mode = sim.dial(self, "layer").index
            end
            sim.fit(x, y, recipe.structure, fitting_mode)
            sim.sound.play({ asset = "lunatic/tfs:sound/ratchet", at = ev.at })
        end)
        return true
    end)
end

return content
