-- What a tub on wheels answers: a loose vessel too heavy to lift. It rolls
-- on a pull, takes what is poured in with the secondary gesture, and with
-- `dump_seconds` tips out under a crowbar. tg: `/obj/structure/mop_bucket`
-- and its cart (code/game/objects/structures/janitor.dm); the rows are
-- docs/janitorial/trolley.md. Its pictures are the vessel's `fill_sprites`.
local action_rules = require("@lib/action_rules")

local wheeled_tub = {}

export type Spec = {
    id: string,
    noun: string,
    dump_seconds: number?,
}

-- tg's `CART_HAS_MINIMUM_REAGENT_VOLUME` (janitor.dm:1) is one unit, the
-- pack's bridge of 0.025 mol.
local MINIMUM_MOL = 0.025

-- What can be held out over the tub: the pack's pouring vessels and the mop.
local POURABLE = {
    "mop",
    "bucket",
    "beaker",
    "beaker_bluespace",
    "beaker_cryostasis",
    "beaker_large",
    "beaker_metamaterial",
    "beaker_plastic",
    "bottle",
    "cola",
    "lab_flask",
    "test_tube",
    "water_bottle",
    "water_bottle_large",
}

local function say(user: Handle, key: string, noun: string): ()
    sim.message.send({ recipient = user, message = sim.msg(key, { noun = noun }) })
end

-- A selector list holds eight rows, so the roster nests.
local function pourable_hold(): action_rules.Selector
    local groups: { action_rules.Selector } = {}
    local group: { action_rules.Selector } = {}
    for _, id in ipairs(POURABLE) do
        table.insert(group, action_rules.fact("held.proto", id))
        if #group == 8 then
            table.insert(groups, { any = group })
            group = {}
        end
    end
    if #group > 0 then
        table.insert(groups, { any = group })
    end
    return { any = groups }
end

-- Moles a pour can tip out: gas stays in the vessel.
local function condensed_moles(held: Handle): number
    local reading = sim.matter_read(held)
    if reading == nil then
        return 0
    end
    local moles = 0
    for _, entry in pairs(reading.contents) do
        moles = moles + (entry.liquid or 0) + (entry.solid or 0)
    end
    return moles
end

function wheeled_tub.actions(spec: Spec): { action_rules.Action }
    local actions: { action_rules.Action } = {
        {
            id = "pour_in",
            gesture = "secondary",
            route = "self_use",
            label = "lunatic/tfs:action.wheeled_tub.pour_in",
            target = true,
            held = pourable_hold(),
            uses_held = true,
        },
    }
    if spec.dump_seconds ~= nil then
        table.insert(actions, {
            id = "dump",
            gesture = "secondary",
            route = "self_use",
            label = "lunatic/tfs:action.wheeled_tub.dump",
            target = true,
            held = action_rules.fact("held.proto", "crowbar"),
            uses_held = true,
        })
    end
    return actions
end

function wheeled_tub.attach(spec: Spec): Definition
    local definition = sim.define("behavior", "lunatic/tfs:" .. spec.id, { prototype = spec.id })

    -- A bare hand gets the refusal in place of a pickup; a held thing passes
    -- on to its own handler, so a mop wrings and a vessel pours.
    definition:handle("interaction.use", {
        kind = "replace",
        route = "interact",
        hidden = "refuses a bare-hand pickup with a line; offers no action",
    }, function(ev)
        if ev.implement ~= nil then
            return { replaced = false }
        end
        return { refused = "lunatic/tfs:action.wheeled_tub.too_heavy" }
    end)

    -- Who asked for each command, in issue order, for its completion to answer.
    local dumps: { { tub: Handle, user: Handle } } = {}
    local pours: { Handle } = {}

    local function dump(tub: Handle, user: Handle): ()
        if condensed_moles(tub) < MINIMUM_MOL then
            say(user, "lunatic/tfs:lib.wheeled_tub.empty", spec.noun)
            return
        end
        say(user, "lunatic/tfs:lib.wheeled_tub.dumping", spec.noun)
        local start = tub.tile
        sim.spawn_task(user, function()
            local ticks = sim.ticks(assert(spec.dump_seconds))
            if sim.do_after(user, ticks, { stationary = true }) ~= "ok" or not tub.alive then
                return
            end
            local at = tub.tile
            if at == nil or start == nil or at.x ~= start.x or at.y ~= start.y then
                say(user, "lunatic/tfs:lib.wheeled_tub.rolled_away", spec.noun)
                return
            end
            table.insert(dumps, { tub = tub, user = user })
            sim.matter.spill({ from = tub, at = at })
        end)
    end

    definition:handle("matter.spill.done", { kind = "react" }, function(ev)
        for index, asked in ipairs(dumps) do
            if asked.tub == ev.from then
                table.remove(dumps, index)
                local key = if ev.moved > 0 then "dumped" else "dump_nothing"
                say(asked.user, "lunatic/tfs:lib.wheeled_tub." .. key, spec.noun)
                return
            end
        end
    end)

    definition:handle("matter.pour.done", { kind = "react" }, function(ev)
        local user = table.remove(pours, 1)
        if user ~= nil then
            local key = if ev.spilled > 0 then "overflow" else "poured"
            say(user, "lunatic/tfs:lib.wheeled_tub." .. key, spec.noun)
        end
    end)

    definition:handle("interaction.use", { kind = "replace", route = "self" }, function(ev)
        if ev.gesture ~= "secondary" then
            return { replaced = false }
        end
        local tub, user, held = ev.subject, ev.actor, ev.implement
        if held == nil or held == tub then
            return { replaced = false }
        end
        if held.prototype == "crowbar" then
            if spec.dump_seconds == nil then
                return { replaced = false }
            end
            dump(tub, user)
            return true
        end
        local source = sim.matter_read(held)
        if source == nil then
            return { replaced = false }
        end
        if source.sealed then
            sim.message.send({ recipient = user, message = sim.msg("lunatic/tfs:lib.vessel.open_before_pouring", {}) })
            return true
        end
        if condensed_moles(held) < MINIMUM_MOL then
            sim.message.send({ recipient = user, message = sim.msg("lunatic/tfs:lib.wheeled_tub.source_empty", {}) })
            return true
        end
        sim.sound.play({ asset = "lunatic/tfs:sound/slosh", at = ev.at })
        -- `pour`: what will not fit runs onto the deck under the tub.
        table.insert(pours, user)
        sim.matter.pour({ from = held, to = tub, amount = "all" })
        return true
    end)

    return definition
end

return wheeled_tub
