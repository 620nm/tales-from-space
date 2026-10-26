-- Tg crate names, descriptions and art:
-- `code/game/objects/structures/crates_lockers/crates.dm:1-5,226-236,352-356,379-382,411-415`;
-- secure art: `code/game/objects/structures/crates_lockers/crates/secure.dm:1-5`.
-- Crates stay dense when open and have no lid animation
-- (`code/game/objects/structures/crates_lockers/crates.dm:11,18`). Climbing,
-- elevation and manifests stay omitted (`code/game/objects/structures/crates_lockers/crates.dm:22-29,41-45`);
-- people storage and paint jobs stay omitted
-- (`code/game/objects/structures/crates_lockers/closets.dm:36-56,122-140`).
return {
    id = "crate",
    script = "crate",
    placement = {
        access = {
            var = "lunatic/tfs:closet_access",
            kind = "choice",
            default = "station.command",
            options = { "station.engineering", "station.medical", "station.security", "station.command" },
            label = "lunatic/tfs:editor.closet_access",
        },
    },
    visual_layer = "large_object",
    name_label = "lunatic/tfs:entity.crate.name",
    name = "crate",
    sprite = "crate",
    -- Tg inherits closet density (`code/game/objects/structures/crates_lockers/closets.dm:7-14`).
    dense = true,
    -- Pack judgment: a movable crate uses this heavy-body response profile.
    motion_response = {
        mass = 50.0,
        restitution = 0.1,
        friction = 0.8,
        half_extent = 0.45,
        public_contacts = true,
    },
    opaque = false,
    states = { "closed", "open" },
    state_sprites = { open = "crate_open" },
    loose = true,
    -- Tg's crate drag slowdown is zero (`code/game/objects/structures/crates_lockers/crates.dm:17`).
    drag_slowdown = 0,
    container = {
        -- Tg's closet item capacity is 30 (`code/game/objects/structures/crates_lockers/closets.dm:56`).
        capacity = 30,
        closed = "closed",
        open = "open",
        -- Tg's crate sounds (`code/game/objects/structures/crates_lockers/crates.dm:13-14`).
        open_sound = "crate_open",
        close_sound = "crate_close",
        stock = {},
    },
    -- Examine flavor is content text under the current keying limitation
    -- (`docs/WORDS.md:71-73`).
    examine = { flavor = "A rectangular steel crate." },
    variants = {
        -- `/crate/medical` uses medicalcrate art, not the department subtype's
        -- `medical` art (`code/game/objects/structures/crates_lockers/crates.dm:232-252`).
        medical = {
            name_label = "lunatic/tfs:entity.crate.medical.name",
            name = "medical crate",
            sprite = "crate_medical",
            state_sprites = { open = "crate_medical_open" },
            examine = { flavor = "A medical crate." },
        },
        -- Tg's engineering subtype inherits the base description
        -- (`code/game/objects/structures/crates_lockers/crates.dm:379-382`).
        engineering = {
            name_label = "lunatic/tfs:entity.crate.engineering.name",
            name = "engineering crate",
            sprite = "crate_engineering",
            state_sprites = { open = "crate_engineering_open" },
        },
        science = {
            name_label = "lunatic/tfs:entity.crate.science.name",
            name = "science crate",
            sprite = "crate_science",
            state_sprites = { open = "crate_science_open" },
            examine = { flavor = "A science crate." },
        },
        hydroponics = {
            name_label = "lunatic/tfs:entity.crate.hydroponics.name",
            name = "hydroponics crate",
            sprite = "crate_hydroponics",
            state_sprites = { open = "crate_hydroponics_open" },
            examine = { flavor = "All you need to destroy those pesky weeds and pests." },
        },
        internals = {
            name_label = "lunatic/tfs:entity.crate.internals.name",
            name = "internals crate",
            sprite = "crate_internals",
            state_sprites = { open = "crate_internals_open" },
            examine = { flavor = "An internals crate." },
        },
        -- Closet locks are bound by `content/fixtures/closets.luau`; secure
        -- state follows tg's `/crate/secure` (`crates/secure.dm:6-10`).
        secure = {
            name_label = "lunatic/tfs:entity.crate.secure.name",
            name = "secure crate",
            sprite = "crate_secure",
            state_sprites = { open = "crate_secure_open" },
            examine = { flavor = "A secure crate." },
        },
    },
}
