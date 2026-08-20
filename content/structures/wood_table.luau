-- A wooden table, and the reason the group above it is a word rather
-- than a flag.
--
-- tg's `/obj/structure/table/wood`
-- (code/game/objects/structures/tables_racks.dm:618-631). One line of
-- it is why this file exists at all: `smoothing_groups =
-- SMOOTH_GROUP_WOOD_TABLES //Don't smooth with SMOOTH_GROUP_TABLES`
-- (:628-629). Wood joins wood. A wooden table pushed against a steel
-- one is two pieces of furniture touching, and both of them know it --
-- which is only expressible because the group is a name two files may
-- agree on and not a property the engine hands out.
--
-- NO CONSTRUCTION LADDER, and it is missing rather than simplified:
-- tg's wooden table is a wooden frame with planks laid over it
-- (`table_frame/wood`, table_frames.dm:108-120), and this pack has no
-- wood stack -- no sheet, no rod, nothing that comes off a tree. An
-- invented recipe out of steel would be a lie about what the thing is
-- made of, and a deconstruction yielding nothing would be a table that
-- evaporates. So it is furniture a map puts down, until wood exists;
-- the day it does, this file grows the same two transitions
-- structures/table.luau has and a wooden frame stands beside the metal
-- one.
--
-- It is a surface on the same terms as every other table: a click with
-- something in hand leaves it on the wood at the pixel you pointed at.
return {
    id = "wood_table",
    name = "wooden table",
    sprite = "wood_table-0",
    dense = true,
    opaque = false,
    surface = true,
    smooth = {
        group = "wood_tables",
        sprites = "wood_table",
    },
}
