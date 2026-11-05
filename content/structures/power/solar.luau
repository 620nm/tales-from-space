-- A photovoltaic panel, standing in vacuum where the sun is.
--
-- Quiet, modest watts, no moving parts, and happy outside the hull --
-- which is why an array stands outside rather than in a room. There
-- is no day/night cycle yet, so a panel is simply a source.
return {
    id = "solar",
    visual_layer = "fixture",
    energy_network = "power",
    name_label = "lunatic/tfs:entity.solar.name",
    name = "solar panel",
    sprite = "solar",
    fixture = "Solar",
    -- The engine's old `SOLAR_W` stand-in, not a tg number.
    output_w = 8000,
    category = "power",
    dense = true,
    examine = {
        flavor = "A dark panel on a short mast, angled at nothing in " .. "particular.",
    },
}
