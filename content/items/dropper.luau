-- The dropper: five units of anything, moved a unit at a time. The
-- precision end of the bench, where the beaker is the bulk end.
--
-- The shell is tg's `volume = 5`, and the shell is the whole of what it
-- holds; the picture is tg's `dropper0` (dropper.dm:5,10).
--
-- ONE UNIT A SQUEEZE, which is the bottom of tg's own
-- `possible_transfer_amounts = list(1, 2, 3, 4, 5)` (dropper.dm:9)
-- rather than its default of 5. A dropper that emptied itself in one
-- click would be a slower beaker; the reason the thing exists is that
-- it can move less than a beaker can. tg spells the choice as a dial
-- and this bench has no dial on a vessel yet, so the file takes the
-- useful end of tg's list and the dial is deferred.
--
-- The gestures are the vessel's rather than this file's
-- (`lib/vessel.luau`); only the doses and the sentences are a
-- dropper's. Liquid only: a pipette does not pick up a crystal.
local content = {
    id = "dropper",
    name = "dropper",
    sprite = "dropper",
    examine = {
        flavor = "A glass pipette under a rubber bulb. For the doses a "
            .. "beaker is too generous to measure.",
    },
    -- tg's dropper: `volume = 5` (reagent_containers/dropper.dm:10).
    volume_ml = 5,
    -- tg's dropper has no `fill_icon_thresholds` at all: it overrides
    -- `update_overlays` to add the one `dropper` state whenever there
    -- is anything in it (dropper.dm:87-93). Five units is too small a
    -- bulb to draw a level in, so the ladder here is one rung.
    fill_sprites = {
        { 1, "dropper_fill" },
    },
    acts_on_items = true,
}

if sim ~= nil then
    vessel.attach({
        id = content.id,
        noun = "dropper",
        phases = { "liquid" },
        pour = { units = 1, message = "You squeeze a drop out of the dropper." },
        sip = { units = 1, message = "You squeeze the dropper onto your tongue." },
        spill = { message = "You squeeze the dropper out onto the deck." },
    })
end

return content
