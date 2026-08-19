-- Reads what a wire is doing before you cut it, and defeats a safety
-- interlock if you would rather it did that.
--
-- It has a tool class now, and one machine in the game answers to it:
-- a multitool on a volumetric gas pump throws its pressure limiters
-- (tg's `multitool_act`, volume_pump.dm:162-170), after which the pump
-- will push past what the kit is rated for and leak a tenth of
-- everything it moves into the room. Nothing else in the construction
-- chain dispatches on the class yet -- a target that declares no
-- multitool step simply is not interested.
--
-- tg: /obj/item/multitool (multitool.dm:14).
return {
    id = "multitool",
    name = "multitool",
    sprite = "multitool",
    tool = "multitool",
    inhand_sprite = { "held_multitool_l", "held_multitool_r" },
    stowed_sprite = "belt_multitool",
    -- tg multitool.dm:28-29.
    pickup_sound = "multitool_pickup",
    drop_sound = "multitool_drop",
}
