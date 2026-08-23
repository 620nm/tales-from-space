-- A photovoltaic panel, standing in vacuum where the sun is.
--
-- Quiet, modest watts, no moving parts, and happy outside the hull --
-- which is why chillstation's array is north of the rank rather than
-- in a room. There is no day/night cycle yet, so a panel is simply a
-- source.
return {
    id = "solar",
    name = "solar panel",
    sprite = "solar",
    fixture = "Solar",
    category = "power",
    dense = true,
    examine = {
        flavor = "A dark panel on a short mast, angled at nothing in "
            .. "particular.",
    },
}
