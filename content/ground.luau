-- What a map may need of the ground it stands on (the engine's
-- docs/gamemodes/environment.md). A map lists the needs it has; a round
-- rolls only an environment whose `meets` covers all of them.
--
-- `gravity`: the environment pulls a body down with no gravity generator
-- running, as a planet does; a space sky gives weight only to a deck a
-- generator drives.
return {
    needs = {
        { id = "gravity", label = "lunatic/tfs:ground.need.gravity" },
    },
}
