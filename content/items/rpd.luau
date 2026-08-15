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
-- * tg's rotation and flip (`p_dir`, `p_flipped`). A flipped trinary is
--   a second fitting here, and rotation wants a wire command the
--   protocol has not grown (docs/construction.md).
-- * tg's multi-layer build, which lays the same run on several layers
--   at once. One layer, one length: the dial names it.
-- * A layer or a colour on a DEVICE. Only the run under the deck
--   carries either today — a machine's layer is its entry's
--   (structures/meter.luau) and devices are omni (pipes/paint.rs) — so
--   these two dials govern pipe, and a valve comes down on the layer
--   its own file names.

-- The shelf, in tg's own order and words (`GLOB.atmos_pipe_recipes`,
-- code/_globalvars/lists/pipe_recipes.dm), as far as this pack has
-- entries for it. `structure` names what stands up; the one row without
-- one is pipe itself, which is not a structure at all but a length in
-- the grid under the deck.
local RECIPES = {
    { label = "Pipe" },
    { label = "Manual Valve", structure = "manual_valve" },
    { label = "Digital Valve", structure = "digital_valve" },
    { label = "Gas Pump", structure = "gas_pump" },
    { label = "Volume Pump", structure = "volume_pump" },
    { label = "Passive Gate", structure = "passive_gate" },
    { label = "Pressure Valve", structure = "pressure_valve" },
    { label = "Gas Filter", structure = "gas_filter" },
    { label = "Gas Filter (flipped)", structure = "gas_filter_flipped" },
    { label = "Gas Mixer", structure = "gas_mixer" },
    { label = "Gas Mixer (flipped)", structure = "gas_mixer_flipped" },
    { label = "Connector", structure = "connector_port" },
    { label = "Meter", structure = "meter" },
    { label = "Layer Adapter", structure = "layer_adapter" },
    { label = "Color Adapter", structure = "color_adapter" },
    { label = "Temperature Gate", structure = "temperature_gate" },
    { label = "Temperature Pump", structure = "temperature_pump" },
    { label = "Heat Exchanger", structure = "heat_exchanger" },
    { label = "Air Scrubber", structure = "air_scrubber" },
    { label = "Air Injector", structure = "air_injector" },
}

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

-- Pipe is subfloor infrastructure: you lay it on open plating and put
-- the deck back over it. The engine refuses a finished floor silently,
-- so this says why first — a refusal with no explanation reads as a
-- dropped click.
local function lay_run(ctx, self, user, x, y)
    if ctx.turf(x, y) ~= "plating" then
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
    -- Destroy mode is aimed at the fitting lying on the deck, and a
    -- click that names one would otherwise pocket it (interact.rs
    -- step 8). tg's `interact_with_atom` reaches the same atom.
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
            -- tg ships `paint_color = "green"` (RPD.dm:51).
            start = 1,
        },
    },
    -- tg's `attack_self` is `ui_interact(user)` (RPD.dm:124-125): the
    -- in-hand key is how you open the thing's window.
    on_use_self = function(ctx, self, user)
        ctx.open_ui(user, self)
    end,
    on_use = function(ctx, self, user, x, y, _choice, target)
        local mode = ctx.dial(self, "mode").index

        if mode == DESTROY then
            -- Loose things only, and only the one the click named. tg
            -- deletes the `/obj/item/pipe` or `/obj/item/pipe_meter` it
            -- was aimed at and nothing else (RPD.dm:324-340) — an
            -- anchored machine is unwrenched, never dissolved, and the
            -- engine agrees by construction: a structure is not an item
            -- and `ctx.consume` has nothing to spend of one.
            if not target or target.kind ~= "item" then
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
            if ctx.turf(x, y) ~= "plating" then
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
        ctx.fit(x, y, recipe.structure)
        ctx.sound("ratchet", x, y)
    end,
}
