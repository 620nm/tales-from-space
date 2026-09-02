-- Nothing at all: a chamber somebody pumped down, a sealed void, a
-- room the shift is meant to start empty.
--
-- No row list, because a blend for nothing is nothing -- the engine
-- deposits what it is told and is told nothing, which leaves an empty
-- INTERIOR cell the neighbours flow into. That is the difference
-- between this and space, which is a boundary they flow into forever
-- (docs/ATMOS.md 11).
--
-- The temperature is still real: it is the floor the cell sits at
-- until air reaches it. tg: TCMB = 2.7, the microwave background
-- (code/__DEFINES/atmospherics/atmos_core.dm:27), which is also what
-- its own AIRLESS_ATMOS = "TEMP=2.7" spells
-- (code/__DEFINES/atmospherics/atmos_mapping_helpers.dm:14).
--
-- The id is the one the engine migrates an old zero-pressure map entry
-- onto (lunatic_core::map::blend), so a map written before blends
-- existed lands on this file rather than on one nobody named.
return {
    id = "vacuum",
    name = "Vacuum",
    temperature_k = 2.7,
    amount = "per_tile",
}
