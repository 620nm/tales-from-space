-- The appendix (docs/BIOLOGY.md §1.2). An organ is an ITEM with an `organ`
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
-- It carries no tags, feeds no capacity and does nothing at all,
-- which is the point: the plan proves an organ may be removable and
-- inert, and the appendectomy is the first operation anybody learns
-- because getting it wrong costs nothing but blood.
return {
    id = "organ_appendix",
    name = "appendix",
    sprite = "organ_appendix",
    organ = {
        slot = "appendix",
        max_health = 100,
        low = 10,
        high = 45,
        heal_per_s = 0.0005,
        decay_per_s = 0.00111,
        tags = {},
    },
}
