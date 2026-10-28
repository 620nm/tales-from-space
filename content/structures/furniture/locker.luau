-- A closet-sized item container, and the tool-room variant the station
-- places. The engine knows only the generic `container` mechanism; all
-- names, pictures, sounds, and possible interiors live here.
--
-- tg's base closet is dense, carries a drag slowdown of 1.5, holds 30
-- things, and names its open/close clips in the same declaration
-- (`code/game/objects/structures/crates_lockers/closets.dm:7-16,
-- 43-59`). Its `open()` dumps the inside onto the turf, natively here;
-- `close()` gathers that turf back up through `lib/closets/closing.luau`
-- (`closets.dm:538-556,612-625`). `passable` below carries the open-density
-- rule (`closets.dm:53,548`).
--
-- The tool loadout copies tg's independent rolls, omitting only item
-- types TfS does not yet declare. Each cable row is a separate 30%
-- chance, exactly as the source makes three separate attempts
-- (`code/game/objects/structures/crates_lockers/closets/
-- utility_closets.dm:93-129`). A variant replaces `container.stock`
-- while inheriting capacity and behavior, so a mapper places one real
-- prototype id rather than a structure plus an out-of-band loot table.
local closet_data = require("@lib/closets/data")

return {
    id = "locker",
    script = "locker",
    -- Large and loose, so it draws over items (large_object in content/compositions.luau).
    visual_layer = "large_object",
    name_label = "lunatic/tfs:entity.locker.name",
    name = "locker",
    sprite = "locker",
    dense = true,
    motion_response = {
        mass = 50.0,
        restitution = 0.1,
        friction = 0.8,
        half_extent = 0.45,
        public_contacts = true,
    },
    opaque = false,
    states = { "closed", "open" },
    state_sprites = { open = "locker_open" },
    passable = { "open" },
    loose = true,
    drag_slowdown = 1.5,
    container = {
        capacity = closet_data.item_capacity,
        body_capacity = closet_data.body_capacity,
        max_body_size = closet_data.max_body_size,
        occupant_speech = true,
        occupant_hearing = true,
        -- Tg shows an occupant the closet's insides (`closet_see_inside.dm:8-10,22-60`;
        -- `code/game/objects/structures/crates_lockers/closets.dm:101,155`).
        occupant_sight = true,
        closed = "closed",
        open = "open",
        open_sound = "locker_open",
        close_sound = "locker_close",
        stock = {},
    },
    -- A welded closet stays shut until unwelded or broken out of
    -- (`closets.dm:1085-1118,1141-1146`).
    latches = { { id = "welded", holds = true } },
    variants = {
        tools = {
            name_label = "lunatic/tfs:entity.locker.tools.name",
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
