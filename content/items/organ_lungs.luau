-- The lungs (docs/BIOLOGY.md §1.2). An organ is an ITEM with an `organ`
-- block: it fits a socket, carries its own pool, and adds its tags to
-- that socket while it is seated. Take it out and the hole it leaves is
-- what every capacity reading its tag sees.
--
-- Pools and decay are STANDARD_ORGAN_THRESHOLD 100 / HEALING 50e-5 /
-- DECAY 111e-5 per second (code/__DEFINES/DNA.dm:137-140)
-- with the thresholds low 10 / high 45
-- (code/modules/surgery/organs/_organ.dm:32-33), unless this file says
-- otherwise below.
--
-- STANDARD_ORGAN_DECAY 111e-5 x 0.9
-- (code/modules/surgery/organs/internal/lungs/_lungs.dm:11).
--
-- THESE LUNGS ARE A CONTAINER, and a driven one (docs/BIOLOGY.md,
-- docs/MATTER.md 5). `volume_ml` makes them a vessel like any other
-- on the station -- the same Mixture in a known shell a beaker is --
-- and `bellows` says that shell is not rigid: one breath constricts it
-- by `tidal_ml`, pushing that share of what was in there into the room,
-- and expanding it again pulls the same volume of the room's air back
-- in. In vacuum there is nothing to pull, which is the whole of why
-- vacuum suffocates.
--
--   * `tidal_ml = 1990` is tg's BREATH_VOLUME verbatim, 1.99 L
--     (code/__DEFINES/atmospherics/atmos_mob_interaction.dm:10). Every
--     breath threshold on the station was calibrated against a parcel
--     this size, so this is the number that keeps them meaning what
--     they meant.
--   * `volume_ml = 6000` is NOT tg's -- tg's lungs have no volume at
--     all, because tg's breath is a parcel and never a place. It is a
--     healthy adult's total lung capacity, ~6 L. What it buys is the
--     residual: 6000 - 1990 = 4010 mL that a stroke cannot reach, which
--     is where the carbon dioxide a breath made waits for the next
--     stroke to push it out. That delay is the reason a crewman's
--     thresholds are judged against the room's air and not against his
--     own exhalation.
--   * The exchange is tg's, and tg takes ALL of it:
--     `breathe_gas_volume(breath, /datum/gas/oxygen,
--     /datum/gas/carbon_dioxide)` with no volume argument removes 100%
--     of the oxygen in the breath and puts the same number of moles of
--     carbon dioxide into what is breathed back out
--     (_lungs.dm:255,712-718). One mole in, one mole out; the carbon
--     comes from the crewman and nothing models where he keeps it.
--
-- The conversion runs only while the body is animate -- a corpse's
-- breath pass never starts (`Sim::resolve_breathing`) -- and scales
-- with the `breathing` capacity, so damaged lungs turn over less air.
return {
    id = "organ_lungs",
    name = "lungs",
    sprite = "organ_lungs",
    volume_ml = 6000,
    bellows = {
        tidal_ml = 1990,
        exchange = {
            { from = "o2", to = "co2" },
        },
    },
    organ = {
        slot = "lungs",
        max_health = 100,
        low = 10,
        high = 45,
        heal_per_s = 0.0005,
        decay_per_s = 0.000999,
        tags = { "lung" },
    },
}
