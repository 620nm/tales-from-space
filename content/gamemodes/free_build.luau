-- Development construction playground: a connection owns one disposable
-- body and supplies never run out. Station round logic stays out of it.
return {
    id = "free_build",
    name = "Free Build",
    -- A map posted for a playtest boots into this one: a mapper wants
    -- to walk the station they just drew with the tools to poke at it,
    -- not to queue at a job board for a shift they are not playing.
    playtest = true,
    rules = {
        bodies = "connection",
        respawn = "uncontrollable",
        -- What every crew body spawned under this mode wears
        -- (docs/BIOLOGY.md §1). A job may name its own instead;
        -- without either there would be nothing to spawn.
        body = "human",
        infinite_vending = true,
        round_logic = false,
        -- Nobody picks a job here, so the sandbox body is issued the
        -- Station Engineer's standard kit — jumpsuit, ID, stocked
        -- toolbelt, metal and tiles. It is the gear, not the job: no
        -- slot is taken and the crew manifest is unchanged. Somebody
        -- who spawns to build should already be holding the tools.
        outfit = "engineer",
        -- One sky and no dice: a sandbox that came out sunward some
        -- days and not others would make every temperature reading in
        -- it a question about the weather.
        environment = {
            sink_k = 2.7,
            rolls = {
                { id = "dead_space", name = "dead space", weight = 1, insolation = 0 },
            },
        },
    },
}
