-- A closet-sized item container, and the tool-room variant the station
-- places. The engine knows only the generic `container` mechanism; all
-- names, pictures, sounds, and possible interiors live here.
--
-- tg's base closet is dense, carries a drag slowdown of 1.5, holds 30
-- things, and names its open/close clips in the same declaration
-- (`code/game/objects/structures/crates_lockers/closets.dm:7-16,
-- 43-59`). Its `open()` drops density and dumps the inside onto the
-- turf; `close()` gathers that turf back up
-- (`closets.dm:538-556,612-625`). Those mutations are native here for
-- the same reason movement and visibility are native; this file says
-- which two authored states they select.
--
-- The tool loadout copies tg's independent rolls, omitting only item
-- types TfS does not yet declare. Each cable row is a separate 30%
-- chance, exactly as the source makes three separate attempts
-- (`code/game/objects/structures/crates_lockers/closets/
-- utility_closets.dm:93-129`). A variant replaces `container.stock`
-- while inheriting capacity and behavior, so a mapper places one real
-- prototype id rather than a structure plus an out-of-band loot table.
return {
    id = "locker",
    name = "locker",
    sprite = "locker",
    dense = true,
    opaque = false,
    states = { "closed", "open" },
    state_sprites = { open = "locker_open" },
    loose = true,
    drag_slowdown = 1.5,
    container = {
        capacity = 30,
        closed = "closed",
        open = "open",
        open_sound = "locker_open",
        close_sound = "locker_close",
        stock = {},
    },
    variants = {
        tools = {
            name = "tool locker",
            sprite = "locker_tools",
            state_sprites = { open = "locker_tools_open" },
            container = {
                stock = {
                    { item = "screwdriver", chance = 0.70 },
                    { item = "wrench", chance = 0.70 },
                    { item = "welder", chance = 0.70 },
                    { item = "crowbar", chance = 0.70 },
                    { item = "wirecutters", chance = 0.70 },
                    { item = "toolbelt", chance = 0.20 },
                    { item = "cable_coil", chance = 0.30 },
                    { item = "cable_coil", chance = 0.30 },
                    { item = "cable_coil", chance = 0.30 },
                    { item = "multitool", chance = 0.20 },
                },
            },
        },
    },
}
