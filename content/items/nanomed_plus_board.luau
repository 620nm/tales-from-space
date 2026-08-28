-- A NanoMed Plus board. tg names the machine's restock canister but
-- constructs vendors through ordinary machine boards; TfS's vendor
-- boards name only the content prototype they assemble.
return {
    id = "nanomed_plus_board",
    name = "machine board (NanoMed Plus)",
    sprite = "board",
    inhand_sprite = { "held_board_l", "held_board_r" },
    board = { machine = "nanomed_plus" },
}
