-- The lungs (docs/BIOLOGY.md §1.2). An organ is an ITEM with an `organ`
-- block: it fits a socket, carries its own pool, and adds its tags to
-- that socket while it is seated. Take it out and the hole it leaves is
-- what every capacity reading its tag sees.
--
-- Pools and decay are STANDARD_ORGAN_THRESHOLD 100 / HEALING 50e-5 /
-- DECAY 111e-5 per second (code/__DEFINES/DNA.dm:137-140)
-- with the thresholds low 10 / high 45
-- (code/modules/surgery/organs/_organ.dm:32-33), unless this file says
-- otherwise below.
--
-- STANDARD_ORGAN_DECAY 111e-5 x 0.9
-- (code/modules/surgery/organs/internal/lungs/_lungs.dm:11).
return {
    id = "organ_lungs",
    name = "lungs",
    sprite = "organ_lungs",
    organ = {
        slot = "lungs",
        max_health = 100,
        low = 10,
        high = 45,
        heal_per_s = 0.0005,
        decay_per_s = 0.000999,
        tags = { "lung" },
    },
}
