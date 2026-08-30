-- A morgue drawer: the thing medbay keeps the dead in until somebody
-- fetches them. The engine owns the mechanism — a dense cabinet that
-- slides a dense tray onto the tile it faces, stows bodies and items
-- with no position at all, and picks one of three lamps for what is
-- inside. This file is every noun, picture, sound and light that goes
-- with it.
--
-- tg's bodycontainer is the source (code/game/objects/structures/
-- morgue.dm): `open()` steps one tile along `dir` and moves everything
-- inside onto it, tray included (:135-170 for both halves); the
-- morgue subtype points EAST and names `m_tray` as its tray
-- (:226-237); `update_icon_state` swaps `morgue0` open, `morgue1`
-- empty, `morgue3` for things with no mob in them and `morgue2` for a
-- dead one (:384-403); both transitions play a pair of clips
-- (:140-141, :155-156). The tray is its own entry (:608-621) because
-- an open drawer genuinely occupies a second tile.
--
-- NOT PORTED, and each for a thing that does not exist yet: the
-- `morgue4` revivable light and its beeper (no ghosts, no
-- defibrillator), the lock and the sixty-second breakout
-- (`container_resist_act`, :112-129 — only the crematorium locks), and
-- the crematorium itself.
return {
    id = "morgue",
    name = "morgue",
    sprite = "morgue1",
    dense = true,
    opaque = false,
    states = { "closed", "open" },
    state_sprites = { open = "morgue0" },
    drawer = {
        closed = "closed",
        open = "open",
        tray = "morgue_tray",
        open_sound = "morgue_roll",
        close_sound = "morgue_roll",
        lights = { items = "morgue3", bodies = "morgue2" },
    },
    examine = {
        flavor = "A refrigerated drawer with a slab that rolls out of "
            .. "it. Used to keep bodies in until someone fetches them.",
    },
    -- The drawer that is already occupied when the shift starts.
    --
    -- tg bakes no corpse into a morgue type: an area helper walks the
    -- morgue at roundstart and fills three of the closed trays it finds
    -- (`/obj/effect/mapping_helpers/dead_body_placer`,
    -- code/modules/mapping/mapping_helpers.dm:920-969), each body a
    -- `create_lost_crew(revivable = FALSE)` in a tagged body bag. Tales
    -- from Space says it as a VARIANT a mapper places instead — one
    -- prototype id on the map, the way `locker.tools` is — so nothing
    -- in the engine has to learn what an area is. The bodycount, the
    -- body bag and the revivable flag are NOT PORTED.
    --
    -- The 200 is NOT PORTED either, and cannot be: tg's whole injury
    -- model here is `new_body.death()`, which takes no number at all
    -- (code/modules/lost_crew/lost_crew_manager.dm:24-26). 200 brute is
    -- what puts a human's health FRACTION on -1 — 200 damage against
    -- `max_health` 100, and the chest's own `max` is exactly 200
    -- (content/items/human_chest.luau) — which is the `dead` line
    -- content/bodies/human.luau draws (docs/BIOLOGY.md §3.4). The
    -- engine never learns the word: it applies the number, the plan's
    -- threshold hook decides what crossing it means.
    variants = {
        cadaver = {
            name = "morgue drawer",
            drawer = {
                stock = {
                    { body = "human", damage = { brute = 200 }, outfit = "cadaver" },
                },
            },
        },
    },
}
