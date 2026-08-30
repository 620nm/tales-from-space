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
}
