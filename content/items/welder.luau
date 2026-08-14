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
    -- The whole of what a torch knows about itself: its equipment class
    -- and its tank. What a torch DOES lives on the things it is used on
    -- (docs/construction.md). tg's max_fuel is 20.
    tool = "welder",
    fuel = { substance = "welding_fuel", capacity = 20.0 },
}
