-- Tg's freezer inherits the crate mechanics but has its own name, description
-- and art (`code/game/objects/structures/crates_lockers/crates.dm:1-18,254-260`).
-- Its cooling is deferred, per
-- `code/game/objects/structures/crates_lockers/crates.dm:261-265`; it remains
-- a separate base prototype.
return {
    id = "freezer",
    script = "freezer",
    visual_layer = "large_object",
    name_label = "lunatic/tfs:entity.freezer.name",
    name = "freezer",
    sprite = "freezer",
    dense = true,
    -- Pack judgment: a movable freezer uses the crate's heavy-body profile.
    motion_response = {
        mass = 50.0,
        restitution = 0.1,
        friction = 0.8,
        half_extent = 0.45,
        public_contacts = true,
    },
    opaque = false,
    states = { "closed", "open" },
    state_sprites = { open = "freezer_open" },
    loose = true,
    drag_slowdown = 0,
    container = {
        capacity = 30,
        closed = "closed",
        open = "open",
        open_sound = "crate_open",
        close_sound = "crate_close",
        stock = {},
    },
    -- Tg's freezer description uses the native examine flavor field.
    examine = { flavor = "A freezer." },
    variants = {
        blood = {
            name = "blood freezer",
            name_label = "lunatic/tfs:entity.freezer.blood.name",
            examine = { flavor = "A freezer containing packs of blood." },
            container = {
                -- Tg creates this sequence in PopulateContents on first dump
                -- (`code/game/objects/structures/crates_lockers/crates.dm:280-297`,
                -- `code/game/objects/structures/crates_lockers/closets.dm:507-515`).
                stock = {
                    { item = "blood_pack", count = 2 },
                    { item = "blood_pack.a_minus" },
                    { item = "blood_pack.b_minus" },
                    { item = "blood_pack.b_plus" },
                    { item = "blood_pack.o_minus" },
                    { item = "blood_pack.o_plus" },
                    { item = "blood_pack.random", count = 3 },
                    { item = "paper.blood_types" },
                },
            },
        },
    },
}
