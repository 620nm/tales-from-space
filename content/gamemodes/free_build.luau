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
    },
}
