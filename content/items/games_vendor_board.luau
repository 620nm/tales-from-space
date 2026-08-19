-- The board that makes an assembly a Good Clean Fun. The third of
-- these, and still one item file and one machine file apiece — which is
-- the whole argument for boards, and the reason a rec-room vendor cost
-- no engine edit at all.
return {
    id = "games_vendor_board",
    name = "machine board (Good Clean Fun)",
    sprite = "board",
    inhand_sprite = { "held_board_l", "held_board_r" },
    board = { machine = "games_vendor" },
}
