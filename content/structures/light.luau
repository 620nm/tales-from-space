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
    category = "power",
    script = "light",
    examine = {
        flavor = "A tube in a bracket. Somebody has to change these.",
    },
}
