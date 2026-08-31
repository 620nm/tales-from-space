-- A cadaver chamber (tg's morgue): the thing medbay keeps the dead
-- in until somebody fetches them. The engine owns the mechanism — a
-- dense cabinet that slides a dense tray onto the tile it faces,
-- stows bodies and items
-- with no position at all, draws on a cord, holds off decay while it is
-- shut, and picks one of five lamps for what is inside. This file is
-- every noun, picture, sound and light that goes with it.
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
-- It runs on station power, which tg's does not: `morgue.dm` declares a
-- plain `/obj/structure` with no `use_power` and no controller in the
-- story, so a tg morgue cools and beeps whatever Engineering is doing.
-- A cadaver chamber here is on a cord like the vending machines, so one
-- somebody has cut the power to stops preserving, stops beeping and
-- goes dark. A deliberate divergence: a thing nobody can switch off is
-- a thing nobody can sabotage.
--
-- NOT PORTED: the lock and the sixty-second breakout
-- (`container_resist_act`, :112-129 — only the crematorium locks), the
-- alt-click that silences the beeper (:293-301 — there is no verb for
-- it yet, so one of these beeps until somebody empties it), and the
-- crematorium itself. The `morgue4` light IS ported now, as the lamp
-- for an occupant who has not stopped: tg lights it for one a
-- defibrillator could still bring back, and with no defibrillator here
-- the nearest truthful reading is "still going".
return {
    id = "cadaver_chamber",
    name = "cadaver chamber",
    sprite = "morgue1_s",
    dense = true,
    opaque = false,
    -- Plugged into the nearest socket in the room (docs/POWER.md,
    -- "Outlets and cords"); the chillstation bay has one on the south
    -- wall at (15, 9) for exactly this rank.
    corded = true,
    states = { "closed", "open" },
    state_sprites = { open = "morgue0_s" },
    -- The sheet's every state has four faces; the drawer wears the one
    -- its placement aimed, and the tray rolls out that way.
    facing_sprites = {
        closed = { north = "morgue1_n", south = "morgue1_s", east = "morgue1_e", west = "morgue1_w" },
        open = { north = "morgue0_n", south = "morgue0_s", east = "morgue0_e", west = "morgue0_w" },
    },
    drawer = {
        closed = "closed",
        open = "open",
        tray = "cadaver_drawer",
        open_sound = "morgue_clank",
        close_sound = "morgue_clank",
        lights = {
            items = { north = "morgue3_n", south = "morgue3_s", east = "morgue3_e", west = "morgue3_w" },
            bodies = { north = "morgue2_n", south = "morgue2_s", east = "morgue2_e", west = "morgue2_w" },
            living = { north = "morgue4_n", south = "morgue4_s", east = "morgue4_e", west = "morgue4_w" },
            -- No `unpowered` picture, because the sheet ships none:
            -- `morgue0` through `morgue4` are all lit states and there
            -- is no dark one (icons/obj/structures.dmi). A chamber with
            -- nothing coming down its cord therefore wears its shut
            -- face with no lamp over it, which is what an unlit readout
            -- looks like. No art is invented for it.
        },
        -- Nothing in a shut, powered one goes off at all. tg keeps an
        -- internal gas mixture, seeds it from the room and cools it
        -- toward T0C-60 at 4°/s while the tray is in, equalizing with
        -- the room while it is out (morgue.dm:249-291). The engine
        -- models the PRESERVATION rather than the temperature — there
        -- is no thermal term in the organ pass to drive — and keeps
        -- tg's open/shut half exactly: a slab rolled out preserves
        -- nothing. 0.0 rather than a small number because the number tg
        -- is reaching for is "indefinitely", and a chamber that only
        -- slowed decay down would be a chamber whose whole purpose
        -- expires while nobody is watching.
        preserves = 0.0,
        -- ...and if somebody in it has not stopped, it says so. tg
        -- plays `empty_alarm.ogg` at volume 50 once a minute while the
        -- state is MORGUE_HAS_REVIVABLE (morgue.dm:242, 274-276); the
        -- minute is kept, the volume is NOT PORTED (this roster carries
        -- no per-clip gain).
        alert = { sound = "cadaver_alert", every_s = 60 },
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
            -- Same name as the plain entry: tg calls every one of them
            -- a morgue (morgue.dm:226-237), and a chamber that announced
            -- what was in it before you opened it would be a different
            -- object.
            name = "cadaver chamber",
            drawer = {
                stock = {
                    { body = "human", damage = { brute = 200 }, outfit = "cadaver" },
                },
            },
        },
    },
}
