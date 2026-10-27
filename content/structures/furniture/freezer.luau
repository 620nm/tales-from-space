-- Tg's freezer inherits the crate mechanics but has its own name, description
-- and art (`code/game/objects/structures/crates_lockers/crates.dm:1-18,254-260`).
-- Powered preservation stops natural organ decay without modeling an internal
-- cold gas cell (`code/modules/surgery/organs/_organ.dm:159-171`).
return {
    id = "freezer",
    script = "freezer",
    visual_layer = "large_object",
    energy_network = "power",
    corded = true,
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
    climbable = { elevation = 14 },
    gestures = { "alt_primary" },
    interaction_labels = {
        alt_primary = { label = "lunatic/tfs:action.climb" },
    },
    loose = true,
    drag_slowdown = 0,
    container = {
        capacity = 30,
        body_capacity = 3,
        max_body_size = 2,
        occupant_speech = true,
        occupant_hearing = true,
        preserves = 0.0,
        closed = "closed",
        open = "open",
        open_sound = "crate_open",
        close_sound = "crate_close",
        stock = {},
    },
    -- A welded closet stays shut until unwelded or broken out of
    -- (`closets.dm:1085-1118,1141-1146`).
    latches = { { id = "welded", holds = true } },
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
                -- Tg also stocks blood/lizard and blood/ethereal; TfS declares neither (`code/game/objects/structures/crates_lockers/crates.dm:293-294`).
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
