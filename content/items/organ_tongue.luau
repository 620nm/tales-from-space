-- The tongue (docs/BIOLOGY.md §1.2). An organ is an ITEM with an `organ`
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
-- decay_factor 0 (code/modules/surgery/organs/internal/tongue/_tongue.dm):
-- a tongue on the deck keeps forever, which is exactly the sort of
-- thing a tongue on the deck does.
return {
    id = "organ_tongue",
    name = "tongue",
    sprite = "organ_tongue",
    organ = {
        slot = "tongue",
        max_health = 100,
        low = 10,
        high = 45,
        -- tg's tongue sets no healing_factor, so it inherits 0
        -- (_organ.dm:30) like the brain: a tongue does not knit itself
        -- back together.
        heal_per_s = 0,
        decay_per_s = 0,
        tags = { "tongue" },
    },
}
