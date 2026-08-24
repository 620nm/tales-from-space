-- The gas analyzer: tg's `/obj/item/analyzer`
-- (code/game/objects/items/devices/scanners/gas_analyzer.dm), and the
-- one thing in an atmospherics technician's pocket that is pure
-- observation. It changes nothing. Point it at something and it tells
-- you what is in it.
--
-- tg dispatches on `return_analyzable_air()`: point it at an atom that
-- has a gas mixture and you read THAT, otherwise you read the turf
-- (gas_analyzer.dm:159-162). Here the three things worth reading are a
-- bottle standing on the tile, the run buried under it, and the air
-- above it, and the same order applies -- the thing you actually
-- pointed at first, the ground last.
--
-- The output is tg's `atmos_scan` (gas_analyzer.dm:185-230), line for
-- line: total moles, then each gas with its share, then temperature in
-- both scales, the volume, and the pressure. tg rounds everything to
-- 0.01 and prints what is left, so 21.6 stays 21.6 rather than becoming
-- 21.60; `r2` below is that. (tg also prints heat capacity and thermal
-- energy. Those are matter-engine internals rather than instrument
-- readings, and the boundary does not hand them out.)

-- What each substance is called on a readout. tg keeps these in
-- GAS_META[META_GAS_NAME]; here they are content, because the engine
-- speaks in the matter registry's ids and has no business knowing that
-- "o2" is spoken aloud as "Oxygen". Anything unnamed prints its id,
-- which is how a station that adds a gas gets a usable readout on the
-- first shift rather than a blank one.
local NAMES = {
    o2 = "Oxygen",
    n2 = "Nitrogen",
    co2 = "Carbon Dioxide",
    plasma = "Plasma",
    water = "Water Vapor",
}

-- tg's `round(n, 0.01)`, and tg's printing of the result: nearest
-- hundredth, trailing zeros dropped.
local function r2(n)
    local scaled = n * 100
    local rounded = if scaled >= 0 then math.floor(scaled + 0.5) else math.ceil(scaled - 0.5)
    return tostring(rounded / 100)
end

-- Absolute zero in Celsius terms: tg's T0C (__DEFINES/atmospherics/
-- atmos_core.dm:29), so a readout in K and one in degrees agree.
local T0C = 273.15

local function sentence_case(s)
    return string.upper(string.sub(s, 1, 1)) .. string.sub(s, 2)
end

local function report(ctx, user, of, sample)
    ctx.system_msg(user, "Results of analysis of " .. of .. ".")
    if sample.moles <= 0 then
        -- tg prints the volume even for an empty mixture, deliberately
        -- ("don't want to change the order volume appears in").
        ctx.system_msg(user, sentence_case(of) .. " is empty!")
        ctx.system_msg(user, "Volume: " .. r2(sample.volume_l) .. " L")
        return
    end
    ctx.system_msg(user, "Moles: " .. r2(sample.moles) .. " mol")
    -- Sorted, because a keyed table has no order and a readout that
    -- shuffles its own lines between two identical scans is a readout
    -- nobody trusts.
    local ids = {}
    for id in pairs(sample.gas) do
        table.insert(ids, id)
    end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local moles = sample.gas[id]
        local share = moles / sample.moles * 100
        ctx.system_msg(
            user,
            (NAMES[id] or id) .. ": " .. r2(moles) .. " mol (" .. r2(share) .. " %)"
        )
    end
    ctx.system_msg(
        user,
        "Temperature: " .. r2(sample.temp_k - T0C) .. " °C (" .. r2(sample.temp_k) .. " K)"
    )
    ctx.system_msg(user, "Volume: " .. r2(sample.volume_l) .. " L")
    ctx.system_msg(user, "Pressure: " .. r2(sample.pressure_kpa) .. " kPa")
end

return {
    id = "analyzer",
    name = "gas analyzer",
    sprite = "analyzer",
    -- tg gas_analyzer.dm:20-21.
    pickup_sound = "analyzer_pickup",
    drop_sound = "analyzer_drop",
    on_use = function(ctx, self, user, x, y, choice, target)
        -- The thing you pointed at, if it holds gas of its own. tg's
        -- `return_analyzable_air()`; here the only portable that has
        -- one is the canister, and a machine that is not one (a vent,
        -- a pump) falls through to the run it stands on -- which is the
        -- same answer tg gives for those.
        if target and target.kind == "machine" then
            local can = ctx.air_sample(x, y, "canister")
            if can then
                ctx.sound("click", x, y)
                report(ctx, user, "the gas canister", can)
                return
            end
        end
        -- A turf click reads the turf (tg gas_analyzer.dm:159-162) --
        -- AND every run buried under it, each named by its layer. A
        -- click cannot land on one pipe out of five the way tg's
        -- pixel-true clicks can, so the instrument answers the way
        -- tg's does for a machine with several mixtures inside it
        -- (atmos_scan loops the airs): all of them, labelled, in a
        -- fixed order. Nothing is chosen for you and nothing is
        -- hidden.
        local read = false
        local room = ctx.air_sample(x, y, "room")
        if room then
            ctx.sound("click", x, y)
            report(ctx, user, "the air", room)
            read = true
        end
        -- Buried pipe is pipe you cannot see, and an instrument that
        -- read through a finished floor would be reading by memory
        -- (the rule the painter and the pipe wrench both keep).
        if ctx.subfloor_exposed(x, y) then
            local mask = ctx.pipe(x, y)
            for layer = 1, 5 do
                local bit = 2 ^ (layer - 1)
                if bit32.band(mask, bit) ~= 0 then
                    local pipe = ctx.air_sample(x, y, "pipe", bit)
                    if pipe then
                        if not read then
                            ctx.sound("click", x, y)
                        end
                        report(ctx, user, "the layer " .. layer .. " pipe", pipe)
                        read = true
                    end
                end
            end
        end
        if not read then
            ctx.system_msg(user, "The analyzer has nothing to read here.")
        end
    end,
}
