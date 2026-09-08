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
    name_label = "lunatic/tfs:entity.light.name",
    name = "light fixture",
    sprite = "light_on",
    fixture = "Light",
    mount = true,
    -- WHAT THE TUBE THROWS. tg's two numbers for the same fitting are
    -- `brightness` 8 and `bulb_power` 1 (light.dm:24-26), and the
    -- second is copied verbatim. The first is not: the falloff these
    -- tiles are lit by is this engine's own, and 6 is the radius every
    -- pool on the shipped station was tuned against -- so taking tg's
    -- 8 would move the light in every room for no reason anybody asked
    -- for. Six here, and tg's curve nowhere.
    --
    -- They are also what a lit fitting COSTS, and that product is tg's
    -- own (docs/power/pass.md). A flag that dims a tube therefore
    -- makes it cheaper as well as darker, which is most of the point
    -- of a station running off its cells.
    light = { range = 6, power = 1.0 },
    -- ON THE ROOM'S NETWORK, and never by anybody's hand. A fitting is
    -- a device with nothing to set and no panel to open: what it is
    -- FOR on a network is HEARING -- the room's alarm saying the air
    -- has gone, the panel saying the mains have. So it is an endpoint,
    -- and `hardwired_only` says the only edge it will ever wear is the
    -- one the electrical pass makes to the panel feeding it
    -- (docs/content-schema/link.md). No engineer joins a light to
    -- anything, no hub offers one as a candidate, and a tube is on a
    -- room's network because it is screwed into that room's ceiling.
    --
    -- The class word is spelled out here rather than shared for the
    -- vent's reason: `lib/` is not published into the structure
    -- registry's sandbox, so a structure reading a shared table reads
    -- nil at prototype time (structures/vent.luau,
    -- structures/air_alarm.luau).
    link = {
        network_interface = true,
        role = "endpoint",
        class = "light",
        hardwired_only = true,
    },
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
