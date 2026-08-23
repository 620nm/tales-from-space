-- A ceiling tube in its fitting. The one thing on the station whose
-- whole job is to be looked at.
--
-- The colour is per PLACEMENT, because a colour is a property of the
-- tube somebody screwed in rather than of the fitting on the wall:
-- cool white in the corridors, a tungsten bulb over the middle of the
-- Commons that nobody has replaced.
--
--   (16, 13, "light", { "color": "#FFD6AA" })
--
-- `script` names the file whose hooks answer for this thing
-- (fixtures/light.luau) -- which is how a shattered tube can be swept
-- up and a new one fitted without the engine learning what a light is.
return {
    id = "light",
    name = "light fixture",
    sprite = "light_on",
    fixture = "Light",
    appearance = {
        states = {
            on = { sprite = "light_on", mounted = {
                north = "light_on_n", south = "light_on_s",
                east = "light_on_e", west = "light_on_w",
            } },
            off = { sprite = "light_off", mounted = {
                north = "light_off_n", south = "light_off_s",
                east = "light_off_e", west = "light_off_w",
            } },
            broken = { sprite = "light_broken", mounted = {
                north = "light_broken_n", south = "light_broken_s",
                east = "light_broken_e", west = "light_broken_w",
            } },
            empty = { sprite = "light_empty", mounted = {
                north = "light_empty_n", south = "light_empty_s",
                east = "light_empty_e", west = "light_empty_w",
            } },
            burned = { sprite = "light_burned", mounted = {
                north = "light_burned_n", south = "light_burned_s",
                east = "light_burned_e", west = "light_burned_w",
            } },
        },
    },
    category = "power",
    script = "light",
    examine = {
        flavor = "A tube in a bracket. Somebody has to change these.",
    },
}
