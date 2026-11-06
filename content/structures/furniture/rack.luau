-- A rack: what the storeroom has instead of a table.
--
-- tg's `/obj/structure/rack` (code/game/objects/structures/tables_racks.dm:1330-1340).
-- It differs from a table by one line: a table places a thing at the
-- pixel clicked, and a rack calls `transfer_item_to_turf` with no offset
-- (:1388), so nothing on it sits where it was aimed. tg's rack centers
-- everything into one pile; `surface_slots` keeps that "the rack decides"
-- and spreads things across the rack's two shelves, left to right,
-- evenly once every slot holds something.
--
-- Dense, not opaque, and bolted down, as tg's (:1336-1337). A wrench
-- takes it apart (`wrench_act_secondary`, :1377-1380) on the primary
-- click, as every table here does.
--
-- WHAT IS NOT PORTED: `rack_parts` (:1430), since this pack's sheets build
-- the structure directly and hand the sheet back; throwing past it
-- (`LETPASSTHROW`, :1338, :1370-1375), and the kick and its integrity
-- (:1395-1404), which tables here lack too.
return {
    id = "rack",
    visual_layer = "fixture",
    name_label = "lunatic/tfs:entity.rack.name",
    name = "rack",
    sprite = "rack",
    dense = true,
    opaque = false,
    -- `AddElement` climbable and its 12px lift (:1351-1352).
    climbable = { elevation = 12 },
    surface = true,
    surface_slots = {
        { x = -8, y = 5 },
        { x = 0, y = 5 },
        { x = 8, y = 5 },
        { x = -8, y = -3 },
        { x = 0, y = -3 },
        { x = 8, y = -3 },
    },
    -- One sheet (`custom_materials`, :1340), and tg's five-second
    -- assembly (`attack_self`, :1471).
    build = {
        sound = "smash",
        on = { "component:station_base" },
        with = { metal = 1 },
        secs = 5.0,
        start = "You start constructing a rack...",
        done = "You assemble a rack.",
    },
    transitions = {
        {
            sound = "smash",
            tool = "wrench",
            yields = { metal = 1 },
            gone = true,
            done = "The rack comes apart.",
        },
    },
}
