-- The board that turns a machine frame into a ChemDrobe. The machine
-- it names is the TfS port of tg wardrobes.dm:600-629.
return {
    id = "chemdrobe_board",
    name = "machine board (ChemDrobe)",
    sprite = "board",
    inhand_sprite = { "held_board_l", "held_board_r" },
    board = { machine = "chemdrobe" },
}
