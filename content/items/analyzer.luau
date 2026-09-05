-- The analyzer: tg's `/obj/item/analyzer`
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
-- both scales, the volume, and the pressure. Two blocks tg has no
-- equivalent for sit between the gas rows and the temperature -- what
-- is LYING there and what is FROZEN there, in millilitres -- because
-- one reading here answers for all three states. tg rounds everything to
-- 0.01 and prints what is left, so 21.6 stays 21.6 rather than becoming
-- 21.60; `r2` below is that. (tg also prints heat capacity and thermal
-- energy. Those are matter-engine internals rather than instrument
-- readings, and the boundary does not hand them out.)
--
-- WHAT EACH SUBSTANCE is called on a readout comes off the READING.
-- tg keeps these in GAS_META[META_GAS_NAME]; the same fact lives here
-- on each substance file's own `name`, and `sim.matter_read` hands it
-- back beside the moles (docs/LUAU-API.md 7). There used to be a table
-- in this file instead, which meant a station that added a gas got a
-- readout printing a raw id until somebody remembered to come back
-- here -- and two places to spell "carbon dioxide" is one place too
-- many. A substance with no authored name answers with its id, which
-- is the registry's own default.
--
-- WHAT ORDER the lines come out in comes off the reading too:
-- `group_order` is this pack's own substance grouping
-- (content/substance_groups.luau), the same ranking a scrubber panel
-- lists its buttons in. The instrument does not get an opinion about
-- which gas matters; the station already has one.

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

-- WHAT IS STANDING IN THIS PHASE, and how much room it takes. `gas` is
-- a number of moles and `liquid_ml`/`solid_ml` are millilitres, which
-- is what a puddle and a lump are worth reading in and the unit every
-- vessel in the pack is authored in (docs/luau-api/matter.md). A phase
-- nothing is standing in is absent from the reading rather than zero,
-- so an absence here is an absence there.
local function collect(sample, phase)
    local rows, names, order, total = {}, {}, {}, 0
    for id, entry in pairs(sample.contents) do
        local amount = entry[phase]
        if amount ~= nil and amount > 0 then
            rows[id] = amount
            names[id] = entry.name
            -- Which block this substance is listed under, off the same
            -- pack roster the scrubber and filter panels read
            -- (content/substance_groups.luau). A substance no group
            -- claimed sorts after every one that has, which is where
            -- those panels put it too.
            order[id] = entry.group_order or math.huge
            total = total + amount
        end
    end
    return rows, names, order, total
end

-- One substance per line, amount and share. Sorted, because a keyed
-- table has no order and a readout that shuffles its own lines between
-- two identical scans is a readout nobody trusts. The order is the
-- station's own: the substance groups this pack declared first, the id
-- inside each block. A printout that listed the air in a different
-- order from every panel would be one more thing to hold in your head.
local function print_rows(user, rows, names, order, total, unit)
    local ids = {}
    for id in pairs(rows) do
        table.insert(ids, id)
    end
    table.sort(ids, function(a, b)
        if order[a] ~= order[b] then
            return order[a] < order[b]
        end
        return a < b
    end)
    for _, id in ipairs(ids) do
        local amount = rows[id]
        local share = amount / total * 100
        -- tg prints its gas names in Title Case; a substance file
        -- writes an ordinary noun, so the readout capitalises rather
        -- than asking every author to shout.
        sim.message.send({
            recipient = user,
            message = sentence_case(names[id] or id) .. ": " .. r2(amount) .. " " .. unit .. " (" .. r2(share) .. " %)",
        })
    end
end

local function report(user, of, sample)
    sim.message.send({ recipient = user, message = "Results of analysis of " .. of .. "." })
    local gas, gas_names, gas_order, gas_moles = collect(sample, "gas")
    local liquid, liquid_names, liquid_order, liquid_ml = collect(sample, "liquid_ml")
    local solid, solid_names, solid_order, solid_ml = collect(sample, "solid_ml")
    -- EMPTY MEANS EMPTY, which is not the same question as "no gas". A
    -- tile that vented to space and kept its puddle is a tile with
    -- something on it, and an instrument that called it empty was
    -- reading the phase it happened to be built for.
    if gas_moles <= 0 and liquid_ml <= 0 and solid_ml <= 0 then
        -- tg prints the volume even for an empty mixture, deliberately
        -- ("don't want to change the order volume appears in").
        sim.message.send({ recipient = user, message = sentence_case(of) .. " is empty!" })
        sim.message.send({ recipient = user, message = "Volume: " .. r2(sample.volume_l) .. " L" })
        return
    end
    if gas_moles > 0 then
        sim.message.send({ recipient = user, message = "Moles: " .. r2(gas_moles) .. " mol" })
        print_rows(user, gas, gas_names, gas_order, gas_moles, "mol")
    end
    -- The condensed blocks, under the gas and above the temperature:
    -- tg has neither, because tg's reagents and tg's gases are two
    -- unrelated systems and only one of them owns an analyzer. Here
    -- one reading answers for all three states, so the instrument that
    -- prints one prints them all.
    if liquid_ml > 0 then
        sim.message.send({ recipient = user, message = "Liquid: " .. r2(liquid_ml) .. " mL" })
        print_rows(user, liquid, liquid_names, liquid_order, liquid_ml, "mL")
    end
    if solid_ml > 0 then
        sim.message.send({ recipient = user, message = "Solid: " .. r2(solid_ml) .. " mL" })
        print_rows(user, solid, solid_names, solid_order, solid_ml, "mL")
    end
    sim.message.send({
        recipient = user,
        message = "Temperature: " .. r2(sample.temp_k - T0C) .. " °C (" .. r2(sample.temp_k) .. " K)",
    })
    sim.message.send({ recipient = user, message = "Volume: " .. r2(sample.volume_l) .. " L" })
    sim.message.send({
        recipient = user,
        message = "Pressure: " .. r2(sample.pressure_kpa) .. " kPa",
    })
end

local content = {
    id = "analyzer",
    name = "analyzer",
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
                report(user, "the canister", can)
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
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:items.analyzer.the_analyzer_has_nothing_to", {}),
            })
            return true
        end
        sim.sound.play({ asset = "lunatic/tfs:sound/click", at = ev.at })
        report(user, "the air", room)
        return true
    end)
end

return content
