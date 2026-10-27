-- `captain` masks every permission. `stale = "allow"` keeps doors open for a holder
-- whose derive failed; a lockdown that must hold is a latch (`bolted`), not access.
return {
    id = "station",
    permissions = { "engineering", "medical", "security", "command" },
    masks = { captain = { "engineering", "medical", "security", "command" } },
    stale = "allow",
}
