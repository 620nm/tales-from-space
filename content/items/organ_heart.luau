-- The heart (docs/BIOLOGY.md §1.2). An organ is an ITEM with an `organ`
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
-- STANDARD_ORGAN_DECAY 111e-5 x 2.5
-- (code/modules/surgery/organs/internal/heart/_heart.dm:11): a heart
-- out of a chest is on a clock.
--
-- `vital = true` is what makes this organ the body's LIFE. The engine's
-- `viability` port reads 0 the moment a vital organ is missing or
-- FAILING (docs/BIOLOGY.md §5.41), the plan's `undone` threshold reads
-- that port, and the plan's own hook turns `undone` into `animate =
-- false`. So "the heart has stopped" and "this body is dead" are one
-- fact with one storage location, and nothing else has to be latched.
--
-- Which is how tg's beating/stopped heart arrives after all. It is NOT
-- ported as tg spells it -- a second boolean plus a 12-second timer
-- (_heart.dm:50-74) -- because this organ already has a state that
-- means "not working": ORGAN_FAILING, damage at `max_health`
-- (_organ.dm:283-305). A stopped heart IS a failing heart here.
-- Crossing the plan's `dead` line drives it there
-- (content/bodies/human.luau), and it comes back only the two ways tg
-- allows: a new heart in the socket, or a defibrillator
-- (content/items/defib.luau).
--
-- Consequences worth knowing, both deliberate:
--   * Healing a corpse's PARTS to full does not revive it. The dead
--     line clears; the heart is still failing.
--   * A heart heals itself while its body runs and decays while it does
--     not, so a heart torn out of a chest is on a clock -- but a
--     failing one never heals on its own (_organ.dm:296-299), which is
--     exactly the latch this needs.
return {
    id = "organ_heart",
    name = "heart",
    sprite = "organ_heart",
    organ = {
        slot = "heart",
        max_health = 100,
        low = 10,
        high = 45,
        heal_per_s = 0.0005,
        decay_per_s = 0.0027750,
        tags = { "heart" },
        vital = true,
    },
}
