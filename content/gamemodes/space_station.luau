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
        -- Every word the round flow says, and the one id its objective
        -- is about. The engine keeps the mechanism -- when the draw
        -- happens, that it happens once, and that holding the thing is
        -- checked on the server against hands and ID slot -- and reads
        -- all of this off the mode, so a second game with a different
        -- crime and a different voice needs no engine change.
        round = {
            announcer = "Charter Command",
            -- The same channel word an item's `radio` declares: what a
            -- listener sees the line bracketed with.
            channel = "Common",
            -- One complete sentence, filled with `{objective}` rather
            -- than assembled out of fragments (docs/LOCALIZATION.md §5).
            briefing = "You are the traitor. Objective: {objective}",
            steal_target = "id_engineering",
            steal_objective = "Steal the engineering ID card and hold it when the shift ends.",
            survive_objective = "Survive to the end of the shift.",
            quiet_ending = "The shift is over. Charter Command reports no threats aboard. Good work.",
            revealed_ending = "The shift is over. The traitor was {name}. Objective: {objective} — {verdict}.",
            success = "SUCCESS",
            failure = "FAILURE",
        },
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
