-- TfS exposes the body-shaped client grammar: hands and equipment, jobs,
-- pulling and throwing, vitals, life state and respawn. Body plans alone do
-- not imply this; another pack may use the same native substrate only for
-- non-player actors and leave this declaration absent. `poke` keeps the
-- engine's poke for an empty-handed click on a crewman nothing else claims.
-- `hover` brightens whatever the pointer rests on.
-- The simulation runs at tg's own 20 Hz: TICKLAG 0.5 deciseconds
-- (tgstation/config/config.txt:268-273) mirrors an fps default of 20
-- (tgstation/code/controllers/configuration/entries/general.dm:216-247).
return {
    interactions = {
        body = true,
        poke = true,
        hover = "lift",
    },
    simulation = {
        atmosphere = true,
        power = true,
        wind = true,
        tick_hz = 20,
    },
}
