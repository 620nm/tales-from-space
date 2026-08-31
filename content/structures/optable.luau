-- An operating table: the best surface in the station to cut somebody
-- open on, and the one piece of furniture you put a patient ON rather
-- than beside.
--
-- tg's `/obj/structure/table/optable`
-- (code/game/objects/structures/tables_racks.dm:898-919). Three of its
-- lines are the whole file:
--
--   * a private icon and `smoothing_flags = NONE` (:901-906) -- an
--     operating table never joins a row of tables, so it wears one
--     picture chosen by nothing.
--   * `can_buckle` with `buckle_lying = 90` (:907-908): a mob dropped
--     on it goes horizontal. Here that is `body_surface = true` and
--     nothing else -- drag a body onto it with the mouse and it comes
--     to rest lying there (the engine's drag seam, docs/NETCODE.md).
--     tg additionally STRAPS the patient down; this pack does not, so a
--     patient who wants up simply gets up, which is the rule the
--     surgery guard already plays by.
--   * the 1.0 location modifier (`_operation.dm:789`), the best there
--     is: bare deck is 2.0 and an ordinary table 1.25.
--
-- Not dense, unlike every other table here: the whole point of it is
-- that a body shares its tile.
--
-- WHAT IS NOT PORTED: the operating computer LINK. tg swaps between
-- `surgery_table_linked` and `surgery_table_unlinked` and mirrors the
-- procedure onto a console beside it (:919-926, with the patient
-- bookkeeping at :1050-1120); that needs patient-presence tracking this
-- game does not keep, so the console in the medbay reads the tiles it
-- faces and this table wears one state. Also absent: the tank and mask
-- fittings (:913-918), and construction -- an operating table is placed
-- by the mapper rather than raised out of silver.
return {
    id = "optable",
    name = "operating table",
    sprite = "optable",
    dense = false,
    surface = true,
    body_surface = true,
    surgery_surface = 1.0,
    examine = {
        flavor = "A padded slab with a drain channel around its rim. "
            .. "Somebody laid out on it is exactly where a surgeon "
            .. "wants them.",
    },
}
