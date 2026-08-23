-- Seat the organ in your hand into an empty socket it fits (tg
-- operation_organ_manip.dm:238-269).
return {
    id = "insert_organ", name = "insert the organ",
    organ = "insert",
    requires = { "skin_open", "organs_cut" },
    time = 1,
    implements = {
        { organ = true, mult = 1 },
    },
}
