-- The eyes (docs/BIOLOGY.md §1.2). An organ is an ITEM with an `organ`
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
-- maxHealth 50, low_threshold 20, high_threshold 30
-- (code/modules/surgery/organs/internal/eyes/_eyes.dm:12-14): eyes are
-- smaller and fail sooner than anything else in the head.
return {
    id = "organ_eyes",
    name = "eyes",
    sprite = "organ_eyes",
    organ = {
        slot = "eyes",
        max_health = 50,
        low = 20,
        high = 30,
        heal_per_s = 0.0005,
        decay_per_s = 0.00111,
        tags = { "eye" },
    },
    on_threshold = function(ctx, organ, body, edge)
        if edge == "high" then
            ctx.system_msg(body, "Your vision blurs and swims.")
        elseif edge == "fail" then
            ctx.system_msg(body, "Everything goes dark.")
        end
    end,
}
