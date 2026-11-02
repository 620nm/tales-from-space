-- The organ condition cold storage holds on a corpse: while held an organ
-- neither heals nor decays. Each organ prototype declares it; a loose organ
-- cannot hold it from a holder, because a condition is set by socket.
local preserved_organ = {}

preserved_organ.condition = "preserved"
preserved_organ.conditions = { { id = preserved_organ.condition, heals = false } }

return preserved_organ
