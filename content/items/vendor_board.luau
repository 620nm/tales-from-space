-- The board that makes an assembly a vending machine (tg's precedent:
-- the frame is generic, the board decides). Remember the machine needs
-- a powered outlet within cord range to actually vend -- machines/
-- vendor.luau says it is corded, and docs/power.md means it.
return {
    id = "vendor_board",
    name = "machine board (vending)",
    sprite = "board",
    board = { machine = "vendor" },
}
