-- Reads what a wire is doing before you cut it. No tool class yet:
-- nothing in the construction chain dispatches on a multitool, so this
-- file says only what the thing IS and waits for the verb. It earns
-- its keep meanwhile as the seventh thing on an engineer's belt.
--
-- tg: /obj/item/multitool (multitool.dm:14).
return {
    id = "multitool",
    name = "multitool",
    sprite = "multitool",
    inhand_sprite = { "held_multitool_l", "held_multitool_r" },
    stowed_sprite = "belt_multitool",
}
