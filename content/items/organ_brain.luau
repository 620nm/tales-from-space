-- The brain (docs/BIOLOGY.md §1.2). An organ is an ITEM with an `organ`
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
-- The brain is the exception to every number above: maxHealth
-- BRAIN_DAMAGE_DEATH 200, low_threshold 45, high_threshold 120
-- (code/modules/mob/living/brain/brain_item.dm:18-20), no healing at
-- all (_organ.dm:30 leaves `healing_factor` at 0), and half the
-- standard decay because "a fast decay rate would be unfun
-- gameplay-wise" (brain_item.dm:16).
return {
    id = "organ_brain",
    name = "brain",
    sprite = "organ_brain",
    organ = {
        slot = "brain",
        max_health = 200,
        low = 45,
        high = 120,
        heal_per_s = 0,
        -- STANDARD_ORGAN_DECAY 111e-5 x 0.5 (brain_item.dm:16).
        decay_per_s = 0.000555,
        tags = { "brain" },
        -- NOT PORTED: a linear brain would slow every do_after from the
        -- first trauma, so this holds full output to 60% damage and
        -- falls from there. tg has no such curve; it has traumas, which
        -- are their own segment.
        curve = {{0, 1}, {0.6, 1}, {1, 0}},
        vital = true,
        mind_seat = true,
    },
    on_threshold = function(ctx, organ, body, edge)
        if edge == "low" then
            ctx.system_msg(body, "Your head swims.")
        elseif edge == "high" then
            ctx.system_msg(body, "You cannot hold a thought.")
        end
    end,
}
