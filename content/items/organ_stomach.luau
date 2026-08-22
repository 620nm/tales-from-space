-- The stomach (docs/BIOLOGY.md §1.2). An organ is an ITEM with an `organ`
-- block: it fits a socket, carries its own pool, and adds its tags to
-- that socket while it is seated. Take it out and the hole it leaves is
-- what every capacity reading its tag sees.
--
-- Pools and decay are STANDARD_ORGAN_THRESHOLD 100 / HEALING 50e-5 /
-- DECAY 111e-5 per second (code/modules/mob/dead/new_player/DNA.dm:137-140)
-- with the thresholds low 10 / high 45
-- (code/modules/surgery/organs/_organ.dm:32-33), unless this file says
-- otherwise below.
--
-- STANDARD_ORGAN_DECAY 111e-5 x 1.15
-- (code/modules/surgery/organs/internal/stomach/_stomach.dm:16).
return {
    id = "organ_stomach",
    name = "stomach",
    sprite = "organ_stomach",
    organ = {
        slot = "stomach",
        max_health = 100,
        low = 10,
        high = 45,
        heal_per_s = 0.0005,
        decay_per_s = 0.0012765,
        tags = { "stomach" },
    },
}
