-- Diethylamine: the amine leg. tg feeds it to plants and puts it in
-- atropine and epinephrine; here it is epinephrine's third leg
-- (reactions/epinephrine.luau), made out of liquid ammonia and ethanol
-- in a bottle (reactions/diethylamine.luau).
--
-- A RECIPE rather than a button, for the same reason acetone is: it
-- sits on tg's upgrade tier (chem_dispenser.dm:85) and this pack's
-- shelf carries the presses a recipe needs rather than the products a
-- recipe makes.
--
-- Real molar mass (C4H11N) and real density -- the density decides how
-- much of it a bottle can hold, because geometry caps a reaction by the
-- free shell volume (D16, docs/MATTER.md 5), and two of these come out
-- for every one of each leg that goes in. `cv = 100` is the shelf's
-- flat convention (D2, docs/CHEMISTRY.md) and the `unmodeled` rest
-- phase is the same decision: diethylamine boils at 329 K, which is
-- inside the chamber's range and outside anything a rule here reads.
-- tg: /datum/reagent/diethylamine (other_reagents.dm:1645).
return {
    id = "diethylamine",
    name = "diethylamine",
    molar_mass = 73.14,
    cv = 100.0,
    phase = { unmodeled = "liquid" },
    -- Real diethylamine, 0.706 g/mL.
    density = { liquid = 0.706 },
    -- What it looks like through glass (tg: other_reagents.dm:1648).
    color = "#604030",
}
