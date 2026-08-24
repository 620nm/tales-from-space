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

local function report(user, of, sample)
    sim.message.send({ recipient = user, message = "Results of analysis of " .. of .. "." })
    local gas = {}
    local gas_moles = 0
    for id, phases in pairs(sample.contents) do
        if phases.gas ~= nil and phases.gas > 0 then
            gas[id] = phases.gas
            gas_moles = gas_moles + phases.gas
        end
    end
    if gas_moles <= 0 then
        -- tg prints the volume even for an empty mixture, deliberately
        -- ("don't want to change the order volume appears in").
        sim.message.send({ recipient = user, message = sentence_case(of) .. " is empty!" })
        sim.message.send({ recipient = user, message = "Volume: " .. r2(sample.volume_l) .. " L" })
        return
    end
    sim.message.send({ recipient = user, message = "Moles: " .. r2(gas_moles) .. " mol" })
    -- Sorted, because a keyed table has no order and a readout that
    -- shuffles its own lines between two identical scans is a readout
    -- nobody trusts.
    local ids = {}
    for id in pairs(gas) do
        table.insert(ids, id)
    end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local moles = gas[id]
        local share = moles / gas_moles * 100
        sim.message.send({ recipient = user, message = (NAMES[id] or id) .. ": " .. r2(moles) .. " mol (" .. r2(share) .. " %)" })
    end
    sim.message.send({ recipient = user, message = "Temperature: " .. r2(sample.temp_k - T0C) .. " °C (" .. r2(sample.temp_k) .. " K)" })
    sim.message.send({ recipient = user, message = "Volume: " .. r2(sample.volume_l) .. " L" })
    sim.message.send({ recipient = user, message = "Pressure: " .. r2(sample.pressure_kpa) .. " kPa" })
end

local content = {
    id = "analyzer",
    name = "gas analyzer",
    sprite = "analyzer",
    -- tg gas_analyzer.dm:20-21.
    pickup_sound = "analyzer_pickup",
    drop_sound = "analyzer_drop",
}

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    script_definition:handle("interaction.use", { kind = "replace", route = "use" }, function(ev)
        local user, target = ev.actor, ev.claim
        -- The thing you pointed at, if it holds gas of its own. tg's
        -- `return_analyzable_air()`; here the only portable that has
        -- one is the canister, and a machine that is not one (a vent,
        -- a pump) falls through to the run it stands on -- which is the
        -- same answer tg gives for those.
        if target and target.kind == "machine" then
            local can = sim.matter_read(target.entity)
            if can then
                sim.sound.play({ asset = "lunatic/tfs:sound/click", at = ev.at })
                report(user, "the gas canister", can)
                return true
            end
        end
        -- The run you actually TOUCHED. The pixel hit-test names the
        -- exact carrier sprite under the cursor (the pipe wrench's own
        -- aim, hit_test_subfloor), and the server has already checked
        -- the deck is open and that run exists -- so a click on the
        -- pixels of one pipe out of five reads that one and no other,
        -- named by its layer.
        if target and target.kind == "pipe" then
            local layer = 1
            while 2 ^ (layer - 1) < target.layer do
                layer += 1
            end
            local pipe = sim.matter_read(ev.at:network(target.layer))
            if pipe then
                sim.sound.play({ asset = "lunatic/tfs:sound/click", at = ev.at })
                report(user, "the layer " .. layer .. " pipe", pipe)
                return true
            end
        end
        -- ...and any click that touched no container -- bare deck,
        -- the gap between runs, a cable (which holds no gas) -- reads
        -- the air, which is what a turf click means (tg
        -- gas_analyzer.dm:159-162).
        local room = sim.matter_read(ev.at.matter)
        if not room then
            sim.message.send({ recipient = user, message = "The analyzer has nothing to read here." })
            return true
        end
        sim.sound.play({ asset = "lunatic/tfs:sound/click", at = ev.at })
        report(user, "the air", room)
        return true
    end)
end

return content
