-- Tg crate names, descriptions and art:
-- `code/game/objects/structures/crates_lockers/crates.dm:1-5,226-236,352-356,379-382,411-415`;
-- secure art: `code/game/objects/structures/crates_lockers/crates/secure.dm:1-5`.
-- Crates stay dense when open and have no lid animation
-- (`code/game/objects/structures/crates_lockers/crates.dm:11,18`). Their climb
-- elevation is 14 pixels (`crates.dm:22-27,41-45`); manifests and paint jobs
-- stay omitted (`crates.dm:28-29,48-54`). Bodies use the base closet's capacity
-- (`code/game/objects/structures/crates_lockers/closets.dm:54-56,575-592`).
return {
    id = "crate",
    script = "crate",
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
    climbable = { elevation = 14 },
    gestures = { "alt_primary" },
    interaction_labels = {
        alt_primary = { label = "lunatic/tfs:action.climb" },
    },
    loose = true,
    -- Tg's crate drag slowdown is zero (`code/game/objects/structures/crates_lockers/crates.dm:17`).
    drag_slowdown = 0,
    container = {
        -- Tg's closet item and body capacities are independent
        -- (`code/game/objects/structures/crates_lockers/closets.dm:54-56,575-592`).
        capacity = 30,
        body_capacity = 3,
        max_body_size = 2,
        occupant_speech = true,
        occupant_hearing = true,
        closed = "closed",
        open = "open",
        -- Tg's crate sounds (`code/game/objects/structures/crates_lockers/crates.dm:13-14`).
        open_sound = "crate_open",
        close_sound = "crate_close",
        stock = {},
        -- Tg's `breakout_time = 1200` deciseconds (`closets.dm:47`); a break-out
        -- clears every holding latch and breaks the lock (`closets.dm:1141-1146`).
        breakout = { seconds = 120, broken = "broken" },
    },
    -- Tg's `locked`/`welded` closet bits hold the door shut; `broken` marks a
    -- busted lock that refuses a relock (`closets.dm:1141-1146,1169-1170`).
    latches = {
        { id = "locked", holds = true },
        { id = "welded", holds = true },
        { id = "broken" },
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
        -- Closet ID swipes are bound by `content/fixtures/closets.luau`; secure
        -- state follows tg's `/crate/secure` (`crates/secure.dm:6-10`).
        secure = {
            access = "station.command",
            props = { locked = true },
            name_label = "lunatic/tfs:entity.crate.secure.name",
            name = "secure crate",
            sprite = "crate_secure",
            state_sprites = { open = "crate_secure_open" },
            examine = { flavor = "A secure crate." },
        },
    },
}
