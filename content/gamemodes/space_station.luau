-- The full station round: persistent characters, finite supplies, and
-- the tg-derived antagonist/objective/round-end flow.
return {
    id = "space_station",
    name = "Space Station",
    default = true,
    rules = {
        bodies = "persistent",
        respawn = "never",
        infinite_vending = false,
        round_logic = true,
    },
}
