-- The bag of dice: "Contains all the luck you'll ever need."
-- tg's `/obj/item/storage/dice` (code/game/objects/items/dice.dm:6-31).
--
-- A noun and nothing else. tg's bag has no `attack_self`, no `attack`
-- and no icon that changes with its contents -- it is a sack with a
-- roster, which is precisely what `storage` + `holds` already are, so
-- this file declares data and carries no hooks at all. That it is
-- content-only is the point: `d6.luau`'s header listed the dice bag
-- (dice.dm:9) among the things that port deliberately left out, and it
-- comes back costing one file.
--
-- THE ROSTER is tg's, minus its dice. tg guarantees the polyhedral set
-- -- d4, d6, d8, d10, d12, d20 -- and then adds ONE oddity picked at
-- random from eight (dice.dm:21-31: d1, d2, fudge, space cube, d00,
-- strange d20, 4d d6, d100). `holds` is a static list, so a random
-- seventh would have to be a hook on a seam that does not exist (there
-- is no on_spawn), and a bag whose contents vary per instance is a
-- worse thing to test than a bag whose contents are a fact. So the
-- seventh slot is the d00, deterministically: it is the only one of
-- tg's eight whose faces this pack can draw AND whose behaviour is one
-- line of arithmetic, and it is the d10's other half, which makes the
-- bag a percentile set instead of six solids and a curio.
--
-- Seven fills it exactly, which is not a coincidence: tg's
-- `/datum/storage/dice` overrides nothing but the holdable filter, so
-- it inherits `max_slots = 7` (code/datums/storage/storage.dm) and
-- ships full.
--
-- WHAT THIS BAG CANNOT SAY, and tg can: `set_holdable(/obj/item/dice)`
-- (code/datums/storage/subtypes/others/misc.dm:253-258) makes tg's bag
-- refuse everything that is not a die. `ItemProto` has no holdable
-- filter -- `storage` is a capacity and nothing more (sim/inventory.rs)
-- -- so this bag will swallow a screwdriver. The gap is the engine's
-- and it is a real one; it belongs beside a size class (tg gates on
-- `w_class` in the same breath), not bolted on for a toy.
return {
    id = "dice_bag",
    name = "bag of dice",
    sprite = "dice_bag",
    storage = 7,
    holds = { "d4", "d6", "d8", "d10", "d12", "d20", "d00" },
}
