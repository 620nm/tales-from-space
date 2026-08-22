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
--   (pipes/paint.rs). A meter is the exception for layer: tg programs
--   the loose meter from the RPD's selected layer before auto-wrenching
--   it, and the optional fitting mode on `ctx.fit` does the same here.
--   In-line devices still come down on the layer their own file names.

-- The shelf, in tg's own order and words (`GLOB.atmos_pipe_recipes`,
-- code/_globalvars/lists/pipe_recipes.dm), as far as this pack has
-- entries for it. `structure` names what stands up; the one row without
-- one is pipe itself, which is not a structure at all but a length in
-- the grid under the deck.
local RECIPES = {
    { label = "Pipe", item = "pipe", icon = "pipe", group = "Pipes" },
    { label = "Manual Valve", item = "manual_valve_fitting", structure = "manual_valve", icon = "manual_valve_loose", group = "Binary Devices" },
    { label = "Digital Valve", item = "digital_valve_fitting", structure = "digital_valve", icon = "digital_valve_loose", group = "Binary Devices" },
    { label = "Gas Pump", item = "gas_pump_fitting", structure = "gas_pump", icon = "gas_pump_loose", group = "Binary Devices" },
    { label = "Volume Pump", item = "volume_pump_fitting", structure = "volume_pump", icon = "volume_pump_loose", group = "Binary Devices" },
    { label = "Passive Gate", item = "passive_gate_fitting", structure = "passive_gate", icon = "passive_gate_loose", group = "Binary Devices" },
    { label = "Pressure Valve", item = "pressure_valve_fitting", structure = "pressure_valve", icon = "pressure_valve_loose", group = "Binary Devices" },
    { label = "Gas Filter", item = "gas_filter_fitting", structure = "gas_filter", icon = "filter_fitting", group = "Trinary Devices" },
    { label = "Gas Filter (flipped)", item = "gas_filter_flipped_fitting", structure = "gas_filter_flipped", icon = "filter_fitting", group = "Trinary Devices" },
    { label = "Gas Mixer", item = "gas_mixer_fitting", structure = "gas_mixer", icon = "mixer_fitting", group = "Trinary Devices" },
    { label = "Gas Mixer (flipped)", item = "gas_mixer_flipped_fitting", structure = "gas_mixer_flipped", icon = "mixer_fitting", group = "Trinary Devices" },
    { label = "Connector", item = "connector_port_fitting", structure = "connector_port", icon = "connector_port_loose", group = "Fittings & Adapters" },
    { label = "Meter", item = "pipe_meter", structure = "meter", icon = "pipe_meter", group = "Fittings & Adapters" },
    { label = "Layer Adapter", item = "layer_adapter_fitting", structure = "layer_adapter", icon = "layer_adapter_loose", group = "Fittings & Adapters" },
    { label = "Color Adapter", item = "color_adapter_fitting", structure = "color_adapter", icon = "color_adapter_loose", group = "Fittings & Adapters" },
    { label = "Temperature Gate", item = "temperature_gate_fitting", structure = "temperature_gate", icon = "temperature_gate_loose", group = "Thermal Devices" },
    { label = "Temperature Pump", item = "temperature_pump_fitting", structure = "temperature_pump", icon = "temperature_pump_loose", group = "Thermal Devices" },
    { label = "Heat Exchanger", item = "heat_exchanger_fitting", structure = "heat_exchanger", icon = "heat_exchanger_loose", group = "Thermal Devices" },
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

-- tg's twelve paints, the same roster the pipe painter carries
-- (items/pipe_painter.luau, `GLOB.pipe_paint_colors`).
local COLORS = {
    { name = "omni", hex = "#EEEEEE" },
    { name = "green", hex = "#00FF00" },
    { name = "blue", hex = "#0000FF" },
    { name = "red", hex = "#FF0000" },
    { name = "orange", hex = "#FFA62B" },
    { name = "cyan", hex = "#00FFFF" },
    { name = "dark", hex = "#454545" },
    { name = "yellow", hex = "#FFFF00" },
    { name = "brown", hex = "#BA9F6D" },
    { name = "pink", hex = "#FF3CC8" },
    { name = "purple", hex = "#800080" },
    { name = "violet", hex = "#6927C5" },
}

-- The five piping layers as bitmasks, the same list the length of pipe
-- carries (items/pipe.luau; PIPING_LAYER_MIN..MAX,
-- __DEFINES/atmospherics/atmos_piping.dm:78-80).
local LAYERS = { 1, 2, 4, 8, 16 }

local BUILD, DESTROY, COPY = 0, 1, 2

local function recipe_of(ctx, self)
    return RECIPES[ctx.dial(self, "recipe").index + 1]
end

local function layer_of(ctx, self)
    return LAYERS[ctx.dial(self, "layer").index + 1]
end

local function paint_of(ctx, self)
    return COLORS[ctx.dial(self, "paint").index + 1]
end

-- Pipe is subfloor infrastructure: you lay it where the deck is open
-- and put the floor back over it. The engine refuses a covered deck
-- silently, so this says why first — a refusal with no explanation
-- reads as a dropped click.
local function lay_run(ctx, self, user, x, y)
    if not ctx.subfloor_exposed(x, y) then
        ctx.system_msg(user, "The floor is in the way. Pry the tile up first.")
        return
    end
    local mask = layer_of(ctx, self)
    if ctx.pipe_occupancy(x, y) % (mask * 2) >= mask then
        ctx.system_msg(user, "An atmospherics component already occupies that pipe layer.")
        return
    end
    if ctx.pipe(x, y) % (mask * 2) >= mask then
        ctx.system_msg(user, "Someone already ran pipe through there.")
        return
    end
    -- tg's `atmos_build_speed` (RPD.dm:53). Half of what the same
    -- length costs by hand, which is the whole reason to carry one.
    if not ctx.do_after(user, 0.4) then
        return
    end
    -- The same question at the end: while you worked, another engineer
    -- may have run the line through this very tile.
    mask = layer_of(ctx, self)
    if ctx.pipe_occupancy(x, y) % (mask * 2) >= mask then
        ctx.system_msg(user, "An atmospherics component already occupies that pipe layer.")
        return
    end
    if ctx.pipe(x, y) % (mask * 2) >= mask then
        ctx.system_msg(user, "Someone already ran pipe through there.")
        return
    end
    local paint = paint_of(ctx, self)
    ctx.lay_pipe(x, y, mask)
    ctx.paint_pipe(x, y, mask, paint.hex)
    ctx.sound("ratchet", x, y)
end

return {
    id = "rpd",
    name = "rapid pipe dispenser",
    -- tg's own art off the tool sheet (`icon_state = "rpd"`, RPD.dm:26).
    sprite = "rpd",
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
    on_use_self = function(ctx, self, user)
        ctx.open_ui(user, self)
    end,
    on_use = function(ctx, self, user, x, y, _choice, target)
        local mode = ctx.dial(self, "mode").index
        local loose_item = nil
        if target and target.kind == "item" then
            loose_item = ctx.item_id(target.entity)
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
            -- and `ctx.consume` has nothing to spend of one.
            if not can_break_down then
                ctx.system_msg(user, "There is nothing loose there to break down.")
                return
            end
            ctx.consume(target.entity)
            ctx.sound("smash", x, y)
            ctx.system_msg(user, "You break down the " .. ctx.name(target.entity) .. ".")
            return
        end

        if mode == COPY then
            -- tg's eyedropper: point it at something already down and
            -- the RPD takes that thing's colour and layer
            -- (`interact_with_atom_secondary`, RPD.dm:481-491). tg reads
            -- them off the DEVICE; we read them off the run, which is
            -- the only thing that carries either — and a run you have
            -- not opened the deck over is one you cannot see.
            if not ctx.subfloor_exposed(x, y) then
                ctx.system_msg(user, "The floor is in the way. Pry the tile up first.")
                return
            end
            for index, mask in ipairs(LAYERS) do
                local hex = ctx.pipe_paint(x, y, mask)
                if hex then
                    ctx.set_dial(self, "layer", index - 1)
                    for c, color in ipairs(COLORS) do
                        if color.hex == hex then
                            ctx.set_dial(self, "paint", c - 1)
                            ctx.system_msg(user, "Layer " .. index .. ", " .. color.name .. ".")
                            return
                        end
                    end
                    -- A colour off the roster: the layer is still worth
                    -- taking, and saying so beats silence.
                    ctx.system_msg(user, "Layer " .. index .. ", and a paint this thing has no name for.")
                    return
                end
            end
            ctx.system_msg(user, "There is no pipe under the floor here.")
            return
        end

        -- A named ordinary item is not the turf beneath it. It neither
        -- becomes a fitting nor disappears under the machine Build
        -- would otherwise create.
        if target and target.kind == "item" then
            ctx.system_msg(user, "That loose item is not atmospherics construction.")
            return
        end

        local recipe = recipe_of(ctx, self)
        if not recipe.structure then
            lay_run(ctx, self, user, x, y)
            return
        end
        -- Dispense and connect, tg's two defaults in one motion. Every
        -- refusal a pair of hands would meet is the engine's to give
        -- (reach, the tile rules, one fitting per turf, "there is no
        -- pipe under the floor here"), so there is nothing to re-check
        -- here — and nothing content could weaken if it tried.
        if not ctx.do_after(user, 0.4) then
            return
        end
        local fitting_mode = nil
        if recipe.structure == "meter" then
            fitting_mode = ctx.dial(self, "layer").index
        end
        ctx.fit(x, y, recipe.structure, fitting_mode)
        ctx.sound("ratchet", x, y)
    end,
}
