-- A torch does not understand every single thing it is capable of
-- doing. It knows it is welding equipment and that it burns fuel to do
-- it; a wall knows what a torch does to a wall, a girder knows what one
-- does to a girder, and vacuum knows a torch closes it. Every one of
-- those answers lives with the thing that owns it, in
-- tfs/content/structures/.
return {
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
    -- A CLOSED tank. tg's welder holds its fuel in a sealed reservoir
    -- you refill from a tank rather than an open cup (welding_tool.dm's
    -- `/obj/item/weldingtool` carries no OPENCONTAINER flag, and
    -- refuelling goes through `refill_from`), and a welder that
    -- breathed its contents into the room would be a welder that
    -- emptied itself in a corridor. welding_fuel is Inert today, so
    -- nothing would actually evaporate; the flag says what the object
    -- IS rather than waiting for the day the fuel gets a curve.
    sealed = true,
}
