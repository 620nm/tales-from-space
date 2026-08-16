-- The board that makes a machine frame into a temperature control
-- unit.
--
-- tg's `/obj/item/circuitboard/machine/thermomachine`
-- (machine_circuitboards.dm:406-415), parts list and all:
--
--     req_components = list(
--         /datum/stock_part/matter_bin = 2,
--         /datum/stock_part/micro_laser = 2,
--         /obj/item/stack/cable_coil = 1,
--         /obj/item/stack/sheet/glass = 1)
--
-- The bins are the machine's heat capacity and the lasers are its
-- range, which is why those two counts are the ones that matter: the
-- thermomachine's whole spec sheet is computed from them
-- (thermomachine.dm:85-96, quoted in structures/thermomachine.luau).
--
-- It names a STRUCTURE rather than a machine, which is the difference
-- between this board and the vendor's: a temperature control unit
-- stands in a pipe run, wears assembly states and answers a crowbar,
-- and all of that is what a structure entry describes.
return {
    id = "thermomachine_board",
    name = "machine board (temperature control unit)",
    sprite = "board",
    inhand_sprite = { "held_board_l", "held_board_r" },
    board = {
        structure = "thermomachine",
        parts = {
            matter_bin = 2,
            micro_laser = 2,
            cable_coil = 1,
            glass = 1,
        },
    },
}
