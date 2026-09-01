-- The digital clock: four blue digits on a wall bracket, showing time
-- elapsed since the shift began. tg updates every clock once a second
-- (`code/controllers/subsystem/processing/digital_clock.dm:1-5`) and
-- builds HH:MM out of four digit overlays and a separator
-- (`code/game/machinery/digital_clock.dm:108-153`). The atlas display
-- declaration does both from the sim tick; no script runs on a cadence.
return {
    id = "digital_clock",
    name = "digital clock",
    sprite = "digital_clock",
    mount = true,
    appearance = {
        mounted = {
            north = "digital_clock_n", south = "digital_clock_s",
            east = "digital_clock_e", west = "digital_clock_w",
        },
    },
    examine = {
        flavor = "A sleek digital clock counting out the shift in blue light.",
    },
}
