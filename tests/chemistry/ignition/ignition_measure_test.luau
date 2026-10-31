local ignition_room = require("@helpers/ignition_room")

-- TEMPORARY MEASUREMENT, not a spec: prints the numbers B3-spark.md §2
-- asks for and asserts only that the fire lights. Dropped once the
-- rule is tuned.
--
-- M1: 2 L of ethanol in a sealed 3 m3 tile, a spark at 30 s; T, ethanol
--     vapour and liquid at +30/60/120/300 s after it.
-- M2: IgnitionAt and ExtinguishedAt rows across that fire (printed with
--     every M1 sample, and last).
-- M3: a spill across three tiles; tiles alight per sample.
local TILE = { x = 1, y = 1 }

local function counts(): string
    return string.format(
        "IgnitionAt=%d ExtinguishedAt=%d",
        #t.ledger_rows("IgnitionAt"),
        #t.ledger_rows("ExtinguishedAt")
    )
end

-- ---------------------------------------------------------------
-- M1 and M2.
-- ---------------------------------------------------------------
do
    local p = ignition_room.build({
        rows = { "###", "#.#", "###" },
        spawn = TILE,
        items = '(1, 1, "burner"),',
        spills = { { x = TILE.x, y = TILE.y, ethanol_mol = ignition_room.POOL_MOL } },
    })
    t.run_seconds(30)
    print(
        string.format(
            "M1 before-spark T=%.2f gas=%.3f liq_ml=%.1f %s",
            t.room_temperature(TILE.x, TILE.y) or 0.0,
            ignition_room.ethanol_gas(TILE.x, TILE.y),
            ignition_room.ethanol_liquid_ml(TILE.x, TILE.y),
            counts()
        )
    )
    ignition_room.take_lit_burner(p, TILE.x, TILE.y)
    ignition_room.touch(p, TILE.x, TILE.y)

    local elapsed = 0.0
    for _, target in ipairs({ 1, 5, 30, 60, 120, 300 }) do
        t.run_seconds(target - elapsed)
        elapsed = target
        print(
            string.format(
                "M1 +%3ds T=%.2f gas=%.3f liq_ml=%.1f o2=%.3f %s",
                target,
                t.room_temperature(TILE.x, TILE.y) or 0.0,
                ignition_room.ethanol_gas(TILE.x, TILE.y),
                ignition_room.ethanol_liquid_ml(TILE.x, TILE.y),
                ignition_room.oxygen_gas(TILE.x, TILE.y),
                counts()
            )
        )
    end
    print("M2 " .. counts())
    assert(#t.ledger_rows("IgnitionAt") >= 1, "the spark lit the pool")
end

-- ---------------------------------------------------------------
-- M3.
-- ---------------------------------------------------------------
do
    local per_tile = ignition_room.POOL_MOL / 3
    local p = ignition_room.build({
        rows = { "#####", "#...#", "#####" },
        spawn = { x = 2, y = 1 },
        items = '(2, 1, "burner"),',
        spills = {
            { x = 1, y = 1, ethanol_mol = per_tile },
            { x = 2, y = 1, ethanol_mol = per_tile },
            { x = 3, y = 1, ethanol_mol = per_tile },
        },
    })
    t.run_seconds(30)
    ignition_room.take_lit_burner(p, 2, 1)
    ignition_room.touch(p, 1, 1)
    -- Snuffed, so the click is the only source and the spread is the fire's own.
    t.use_self(p)
    t.tick()

    local elapsed = 0.0
    local reached_all = false
    for _, target in ipairs({ 1, 2, 3, 5, 8, 12, 20, 30, 60, 120 }) do
        t.run_seconds(target - elapsed)
        elapsed = target
        local alight = ignition_room.count(ignition_room.latched_tiles())
        reached_all = reached_all or alight == 3
        print(
            string.format(
                "M3 +%3ds tiles_alight=%d T=%.2f,%.2f,%.2f %s",
                target,
                alight,
                t.room_temperature(1, 1) or 0.0,
                t.room_temperature(2, 1) or 0.0,
                t.room_temperature(3, 1) or 0.0,
                counts()
            )
        )
    end
    assert(#t.ledger_rows("IgnitionAt") >= 1, "the spill lit")
    print("M3 reached_all=" .. tostring(reached_all))
end
