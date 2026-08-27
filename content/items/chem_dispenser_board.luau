-- The board that makes a machine frame into a chem dispenser.
--
-- tg's `/obj/item/circuitboard/machine/chem_dispenser`
-- (machine_circuitboards.dm:752-762):
--
--     req_components = list(
--         /datum/stock_part/matter_bin = 2,
--         /datum/stock_part/capacitor = 1,
--         /datum/stock_part/servo = 1,
--         /obj/item/stack/sheet/glass = 1,
--         /obj/item/stock_parts/power_store/cell = 1)
--
-- THE CELL IS THE ONE OMISSION. Every appliance on this bench is corded
-- and draws flat off the mains (machines/chem_dispenser.luau says so at
-- length), so tg's per-unit cell economy has nothing to sit in; there is
-- no cell prototype to ask for and inventing one for a board's list
-- would be inventing a second power path. The other four rows are
-- verbatim.
--
-- The two bins, the capacitor and the servo are not written here: a
-- board's component list is DERIVED from the product's own
-- `parts.slots` (docs/CONTENT-SCHEMA.md §1.10b), which for this machine
-- is exactly those four sockets. What is left is the pane.
return {
    id = "chem_dispenser_board",
    name = "machine board (chem dispenser)",
    sprite = "board",
    inhand_sprite = { "held_board_l", "held_board_r" },
    board = {
        machine = "chem_dispenser",
        parts = {
            glass = 1,
        },
    },
}
