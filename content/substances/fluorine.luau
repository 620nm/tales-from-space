-- Fluorine: F2, the most reactive element there is, and the fourth
-- permanent gas. NOT on the dispenser shelf and never will be: it
-- rests as a gas at every temperature a nozzle reaches, so every press
-- over an open beaker would be refused and every press into a sealed
-- one would be a worse way of doing what a connector port already does
-- (D19, docs/BENCH.md 4). It comes to chemistry off a canister,
-- the way oxygen, nitrogen and hydrogen do.
--
-- `gas_only` rather than `unmodeled`: fluorine condenses at 85 K, which
-- is not a temperature this station has, and the two spellings are
-- physically different -- a `gas_only` substance has no saturation line
-- at all, so nothing ever condenses it (docs/MATTER.md 5). That is the
-- honest claim for the atmos column.
--
-- Real molar mass. `cv = 31` is the real molar heat capacity of F2 gas,
-- carried in the same units tg's gas column uses.
-- tg: /datum/reagent/fluorine (other_reagents.dm:1111).
return {
    id = "fluorine",
    name = "fluorine",
    molar_mass = 38.00,
    cv = 31.0,
    phase = "gas_only",
    -- What it looks like through glass (tg: other_reagents.dm:1114,
    -- COLOR_GRAY).
    color = "#808080",
    -- A thing the station is built to keep away from itself.
    dangerous = true,
    -- This file's own `dangerous`: a thing the station is built to keep
    -- away from itself.
    group = "poison",
}
