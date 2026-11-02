-- What a tub on wheels answers: a loose vessel too heavy to lift. It rolls
-- on a pull, takes what is poured in with the secondary gesture, and with
-- `dump_seconds` tips out under a crowbar. tg: `/obj/structure/mop_bucket`
-- and its cart (code/game/objects/structures/janitor.dm); the rows are
-- docs/janitorial/trolley.md. Its pictures are the vessel's `fill_sprites`.
local action_rules = require("@lib/action_rules")
local vessel = require("@lib/vessel")

local wheeled_tub = {}

export type Spec = {
    id: string,
    noun: string,
    dump_seconds: number?,
}

-- tg's `CART_HAS_MINIMUM_REAGENT_VOLUME` (janitor.dm:1) is one unit, the
-- pack's bridge of 0.025 mol.
local MINIMUM_MOL = 0.025

local function say(user: Handle, key: string, noun: string): ()
    sim.message.send({ recipient = user, message = sim.msg(key, { noun = noun }) })
end

function wheeled_tub.actions(spec: Spec): { action_rules.Action }
    local actions: { action_rules.Action } = {
        {
            id = "pour_in",
            gesture = "secondary",
            route = "self_use",
            label = "lunatic/tfs:action.wheeled_tub.pour_in",
            target = true,
            held = action_rules.fact("held.present", true),
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

    local function dump(tub: Handle, user: Handle): ()
        if (vessel.moles(tub) or 0) < MINIMUM_MOL then
            say(user, "lunatic/tfs:lib.wheeled_tub.empty", spec.noun)
            return
        end
        say(user, "lunatic/tfs:lib.wheeled_tub.dumping", spec.noun)
        sim.spawn_task(user, function()
            if sim.do_after(user, sim.ticks(assert(spec.dump_seconds)), {}) ~= "ok" or not tub.alive then
                return
            end
            sim.matter.spill({ from = tub, at = tub.tile })
            say(user, "lunatic/tfs:lib.wheeled_tub.dumped", spec.noun)
        end)
    end

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
        if vessel.moles(held) == nil then
            return { replaced = false }
        end
        if (vessel.moles(held) or 0) < MINIMUM_MOL then
            say(user, "lunatic/tfs:lib.wheeled_tub.source_empty", spec.noun)
            return true
        end
        sim.sound.play({ asset = "lunatic/tfs:sound/slosh", at = ev.at })
        -- `pour`: what will not fit runs onto the deck under the tub.
        sim.matter.pour({ from = held, to = tub, amount = "all" })
        say(user, "lunatic/tfs:lib.wheeled_tub.poured", spec.noun)
        return true
    end)

    return definition
end

return wheeled_tub
