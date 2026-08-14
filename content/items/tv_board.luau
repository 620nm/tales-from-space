-- Every chill room needs one. This board is an identity, not a
-- procedure: it names the machine a finished assembly becomes, and the
-- frame it goes into never has to know. What "tv" means lives in
-- machines/tv.luau; what installing costs lives in the frame's own
-- transition table.
return {
    id = "tv_board",
    name = "machine board (television)",
    sprite = "board",
    board = { machine = "tv" },
}
