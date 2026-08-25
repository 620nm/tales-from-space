-- A torch does not understand every single thing it is capable of
-- doing. It knows it is welding equipment and that it burns fuel to do
-- it; a wall knows what a torch does to a wall, a girder knows what one
-- does to a girder, and vacuum knows a torch closes it. Every one of
-- those answers lives with the thing that owns it, in
-- tfs/content/structures/.
local content = {
    id = "welder",
    name = "welding tool",
    sprite = "welder",
    inhand_sprite = { "held_welder_l", "held_welder_r" },
    -- tg weldingtool.dm:16-17.
    pickup_sound = "welder_pickup",
    drop_sound = "welder_drop",
    -- The whole of what a torch knows about itself: its equipment class
    -- and its tank. What a torch DOES lives on the things it is used on
    -- (docs/CONSTRUCTION.md). tg's max_fuel is 20.
    tool = "welder",
    fuel = { substance = "welding_fuel", capacity = 20.0 },
    -- The reservoir, sized to the charge above: tg's torch carries 20
    -- units (weldingtool.dm:39), and 20 mol of acetylene at 1 g/mL is
    -- 521 mL, so 550 mL is that tank with a working headspace. A
    -- welder is the one vessel here whose contents are authored in
    -- moles rather than dispensed by the millilitre.
    volume_ml = 550,
    -- It can carry an open flame (tg's `welding = TRUE` while struck).
    -- Two appearance states, unlit first, both drawing the base picture
    -- (no lit sprite is baked): the flame is a fact the surgery close and
    -- `expose_heat` read off `FuelBurn`, and the state only mirrors it.
    flame = true,
    states = { "unlit", "lit" },
    -- Strike it on, or snuff it (tg's `attack_self`, weldingtool.dm). A
    -- lit welder is "hot" for surgery's close operation (docs/SURGERY.md
    -- §6.2), which is what lets the improvised floor rescue seal a wound.
    -- A CLOSED tank. tg's welder holds its fuel in a sealed reservoir
    -- you refill from a tank rather than an open cup (welding_tool.dm's
    -- `/obj/item/weldingtool` carries no OPENCONTAINER flag, and
    -- refuelling goes through `refill_from`), and a welder that
    -- breathed its contents into the room would be a welder that
    -- emptied itself in a corridor. welding_fuel is unmodeled today, so
    -- nothing would actually evaporate; the flag says what the object
    -- IS rather than waiting for the day the fuel gets a curve.
    sealed = true,
}

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    script_definition:handle("interaction.use", { kind = "replace", route = "self" }, function(ev)
        local self, user = ev.subject, ev.actor
        if self.state == "lit" then
            sim.set_flame(self, false)
            sim.message.send({ recipient = user, message = "You extinguish the welder." })
        else
            sim.set_flame(self, true)
            sim.message.send({ recipient = user, message = "You flip the welder on; the flame hisses to life." })
        end
        return true
    end)
end

return content
