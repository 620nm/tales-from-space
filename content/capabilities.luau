-- TfS exposes the body-shaped client grammar: hands and equipment, jobs,
-- pulling and throwing, vitals, life state and respawn. Body plans alone do
-- not imply this; another pack may use the same native substrate only for
-- non-player actors and leave this declaration absent. `poke` keeps the
-- engine's poke for an empty-handed click on a crewman nothing else claims.
return {
    interactions = {
        body = true,
        poke = true,
    },
}
