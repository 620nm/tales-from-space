-- The scripted vending machine from docs/LUAU-API.md's shipped-content
-- list: sim.sleep demonstrates a plain suspension (no revalidation),
-- sim.spawn_item a script-created entity with Script-actor provenance
-- in the shift ledger.
-- What the machine serves for a returned empty: forty-five of the
-- bottle's fifty millilitres. Water is 18 g/mol and a millilitre a gram,
-- so 2.5 mol is 45 mL.
local SERVE_MOL = 2.5
-- Six degrees, which is what a drinks chiller runs at. A vessel arrives
-- at the temperature of the machine that filled it.
local CHILLED_K = 279.15
-- Rinsings. A bottle with a film left in it is still an empty; a bottle
-- with a dose in it is not.
local EMPTY_MOL = 0.01

local content = {
    id = "vendor",
    name = "Robust Softdrinks vending machine",
    sprite = "vendor",
}

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    script_definition:handle("interaction.use", { kind = "replace", route = "interact" }, function(ev)
        local self, user = ev.subject, ev.actor
        if not sim.is_powered(self) then
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:fixtures.vendor.the_machine_is_dark_and", {}),
            })
            return true
        end
        -- Clicking the machine opens its content-declared clean-room
        -- shelf; dispensing happens through its exact action envelopes.
        ui.open({ viewer = user, owner = self })
        return true
    end)
    -- THE EMPTIES. Hand the machine a bottle and it gives you a cold one
    -- back. A drinks machine with nowhere to put the glass is furniture
    -- with a hole in it, and tg's own vendors stock bottled water
    -- (`/obj/item/reagent_containers/cup/glass/bottle/water` on the
    -- boozeomat shelf, code/game/machinery/vending/boozeomat.dm:14). The
    -- bottle you hand back goes into the crate; what comes out is the
    -- machine's own product, minted the way every vended thing is.
    --
    -- `Handle.base` is what makes "a bottle" mean EVERY bottle. A
    -- labelled preconfiguration is a prototype of its own with its own id
    -- (`bottle.iodine`), and asking what it was DERIVED from is how a
    -- machine accepts the whole family without listing it
    -- (docs/CONTENT-SCHEMA.md section 1.1a) -- otherwise this file needs
    -- editing every time the chemists label a new one.
    --
    -- WHICH machine this is is not a list in this file either. The tool
    -- vendor and the games machine run this same script
    -- (machines/tool_vendor.luau), and neither has anywhere to put a
    -- bottle; `sim.stocks` asks the machine's own shelf whether it sells
    -- the drink, so a machine that stops selling one stops taking the
    -- empties back, with no edit here.
    script_definition:handle("attack.swing", { kind = "replace", route = "attack" }, function(ev)
        local self, user = ev.implement, ev.actor
        local target, victim, item = ev.target, ev.target, ev.target
        local info = { surgery_refusal = ev.refusal }
        local _self, _victim, _target, _info = self, victim, target, info
        if not sim.stocks(self, "cola") or (item.base or item.prototype) ~= "bottle" then
            return { replaced = false } -- not ours; the click means whatever else it means
        end
        if not sim.is_powered(self) then
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:fixtures.vendor.the_machine_is_dark_and", {}),
            })
            return true
        end
        -- An EMPTY one. A machine that swallowed a full bottle would be a
        -- disposal chute with a chiller in it, and the chemists would
        -- find that out the hard way.
        local read = sim.matter_read(item)
        if read ~= nil and read.moles > EMPTY_MOL then
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:fixtures.vendor.the_machine_only_takes_empties", {}),
            })
            return true
        end
        local returned = item.name
        item:consume()
        sim.entity.spawn({
            definition = "bottle",
            at = self.tile,
            initial = {
                contents = { { substance = "water", mol = SERVE_MOL } },
                temperature_k = CHILLED_K,
            },
        })
        sim.sound.play({ asset = "lunatic/tfs:sound/vend", at = ev.at })
        sim.message.send({
            recipient = user,
            message = sim.msg("lunatic/tfs:fixtures.vendor.traded", {
                item = returned,
            }),
        })
        return true
    end)
    script_definition:handle("move.bump", { kind = "replace", route = "bump" }, function(ev)
        local self, user = ev.target, ev.mover
        sim.message.send({
            recipient = user,
            message = sim.msg("lunatic/tfs:fixtures.vendor.the_vending_machine_wobbles_nothing", {}),
        })
        return true
    end)
end

return content
