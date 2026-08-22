-- The full station round: persistent characters, finite supplies, and
-- the tg-derived antagonist/objective/round-end flow.
return {
    id = "space_station",
    name = "Space Station",
    default = true,
    rules = {
        bodies = "persistent",
        respawn = "never",
        -- What every crew body spawned under this mode wears
        -- (docs/BIOLOGY.md §1). A job may name its own instead;
        -- without either there would be nothing to spawn.
        body = "human",
        infinite_vending = false,
        round_logic = true,
        -- Where the station is parked this shift, rolled once at boot.
        -- Dead space only ever takes heat away; a close solar orbit
        -- cooks the hull through the same faces it radiates from, and
        -- the engineers find out which they got by watching the
        -- thermometers.
        environment = {
            sink_k = 2.7,
            rolls = {
                { id = "dead_space", name = "dead space", weight = 4, insolation = 0 },
                { id = "orbit", name = "orbit", weight = 3, insolation = 1361 },
                { id = "sunward", name = "close solar orbit", weight = 1, insolation = 2700 },
            },
        },
    },
}
