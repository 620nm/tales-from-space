-- The board that makes an assembly a tool vendor. Same board item, a
-- different name inside it — which is the whole argument for boards:
-- a second vending machine costs one item file and one machine file,
-- and no engine edit at all.
return {
    id = "tool_vendor_board",
    name = "machine board (YouTool)",
    sprite = "board",
    inhand_sprite = { "held_board_l", "held_board_r" },
    board = { machine = "tool_vendor" },
}
