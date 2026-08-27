-- The board that makes a machine frame into a reaction chamber.
--
-- tg's `/obj/item/circuitboard/machine/chem_heater`
-- (machine_circuitboards.dm:803-809), verbatim:
--
--     req_components = list(
--         /datum/stock_part/micro_laser = 1,
--         /obj/item/stack/sheet/glass = 1)
--
-- ONE laser, and the pane. The laser is the whole of the machine's spec
-- sheet: tg's `RefreshParts` sets `heater_coefficient = 0.1` and then
-- multiplies it by the laser it finds (chem_heater.dm:86-90), which is
-- why the chamber's `parts.scale` has exactly one row and it names
-- `coeff`.
--
-- The socket is not written here. A board's component list is DERIVED
-- from the product's own `parts.slots` (docs/CONTENT-SCHEMA.md §1.10b),
-- so what this file carries is the pane a socket cannot hold.
return {
    id = "chem_heater_board",
    name = "machine board (reaction chamber)",
    sprite = "board",
    inhand_sprite = { "held_board_l", "held_board_r" },
    board = {
        machine = "chem_heater",
        parts = {
            glass = 1,
        },
    },
}
