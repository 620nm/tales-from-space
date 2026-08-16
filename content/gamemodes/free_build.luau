-- Development construction playground: a connection owns one disposable
-- body and supplies never run out. Station round logic stays out of it.
return {
    id = "free_build",
    name = "Free Build",
    rules = {
        bodies = "connection",
        respawn = "critical",
        infinite_vending = true,
        round_logic = false,
        -- Nobody picks a job here, so the sandbox body is issued the
        -- Station Engineer's standard kit — jumpsuit, ID, stocked
        -- toolbelt, metal and tiles. It is the gear, not the job: no
        -- slot is taken and the crew manifest is unchanged. Somebody
        -- who spawns to build should already be holding the tools.
        outfit = "engineer",
    },
}
