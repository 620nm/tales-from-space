-- The pill: one dose, once. tg's
-- `/obj/item/reagent_containers/applicator/pill`
-- (code/modules/reagents/reagent_containers/pill.dm:1-11).
--
-- It arrives EMPTY off the shelf and empty out of the packager's
-- extruder; what makes a pill a dose of anything is the transfer the
-- packager makes into it (fixtures/chem_packager.luau), exactly as what
-- makes a beaker a beaker of libital is the pour. One prototype, every
-- medicine.
--
-- One gesture: a click on your own tile swallows it, which is the swig
-- every vessel in this pack already has (beaker.luau, cola.luau) with
-- two differences. It moves EVERYTHING rather than a mouthful -- a pill
-- is not something you sip -- and it moves every phase rather than the
-- condensed ones, because the coating is about to be gone and anything
-- left in it would be annihilated with it rather than swallowed. Then
-- the pill itself is spent: `Handle:consume` is the verb for a whole
-- item being used up (the pipe dispenser swallows fittings with it,
-- fixtures/pipe_dispenser.luau), and it lands on the record as
-- `ItemConsumed` rather than as the LOSS `entity.despawn` would write.
local content = {
    id = "pill",
    name = "pill",
    sprite = "pill",
    inhand_sprite = { "held_pill_l", "held_pill_r" },
    examine = {
        flavor = "A tablet with a smooth coating. Whatever is in it, it "
            .. "is all in there at once.",
    },
    -- tg's `volume = 50` (pill.dm:11). A tablet reading fifty
    -- millilitres is tg's own arithmetic rather than a coating anybody
    -- could measure, and it is the number that matters: the shell is
    -- the whole of what a vessel holds (docs/MATTER.md 5), so a smaller
    -- one would trim a chemist's dose at the extruder for no reason
    -- anybody at the bench could see.
    volume_ml = 50,
    -- A coating is a lid. Nothing evaporates out of a pill in a pocket.
    sealed = true,
    -- tg's pill has ONE fill picture and no thresholds -- `pill` on the
    -- shared fill sheet, tinted by what is inside -- the same bargain
    -- the dropper takes (docs/ASSETS.md; reagent_containers.dm:287-307).
    fill_sprites = {
        { 1, "pill_fill" },
    },
}

if sim ~= nil then
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })
    script_definition:handle("interaction.use", { kind = "replace", route = "use" }, function(ev)
        local self, user, x, y, choice = ev.subject, ev.actor, ev.at.x, ev.at.y, ev.choice
        local clicked, target = ev.claim, ev.claim
        local _choice, _clicked, _target = choice, clicked, target
        local px, py = user.tile.x, user.tile.y
        if x ~= px or y ~= py then
            return { replaced = false } -- only a click on your own tile swallows
        end
        local read = sim.matter_read(self)
        if read == nil or read.moles < 1e-9 then
            sim.message.send({
                recipient = user,
                message = sim.msg("lunatic/tfs:items.pill.the_pill_is_a_blank", {}),
            })
            return true
        end
        sim.matter.drink({ from = self, who = user })
        self:consume()
        sim.sound.play({ asset = "lunatic/tfs:sound/drink", at = ev.at })
        sim.message.send({
            recipient = user,
            message = sim.msg("lunatic/tfs:items.pill.you_swallow_the_pill", {}),
        })
        return true
    end)
end

return content
