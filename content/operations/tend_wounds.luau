-- First aid, not surgery (tg operation_healing.dm): tend bruises and
-- burns. INVERTS tg's availability on purpose: tg requires the skin cut
-- or open (any_surgery_states_required = ALL_SURGERY_SKIN_STATES,
-- operation_healing.dm:31), whereas here it is offered only on INTACT
-- skin so it does not crowd the mid-operation window. One application per
-- click; the looping and the 5 + 0.07*loss curve are simplified to a flat
-- 5 (both deviations in docs/SURGERY.md §6.7).
--
-- AND A THIRD DEVIATION, which is this file's most consequential:
-- nothing here stops it being used on a CORPSE, and five brute off a
-- body sitting on its own dead line puts it back over the line and
-- animate again. tg cannot do that, and blocks it twice -- `stat`
-- latches to DEAD until a defib or a revival surgery clears it, and
-- this very operation scales its healing to a fifth on a corpse
-- (`dead_multiplier = 0.2`, operation_healing.dm:190). Neither is
-- ported: TfS death is a recomputed threshold (content/bodies/
-- human.luau's `body.threshold.done` hook) and this file declares no
-- multiplier. A `dead_only`-style opt-out in the other direction does
-- not exist, deliberately -- tg has no operation that requires a
-- living patient either.
--
-- The behaviour is PINNED, not blessed: tests/corpse_revival_pin_test
-- .luau asserts it by name and fails the moment it changes, so the
-- ruling (latch death, port the 0.2, or accept this as the pack's
-- revival mechanism) is a decision somebody makes rather than one
-- somebody discovers.
return {
    id = "tend_wounds", name = "tend the wounds",
    blocked = { "skin_cut", "skin_open" },
    ignore_clothes = true,
    heal = { brute = 5, burn = 5 },
    time = 2.5,
    implements = {
        { tool = "hemostat", mult = 1 },
        { tool = "cutters", mult = 1.67 },
        { tool = "screwdriver", mult = 1.5 },
    },
}
