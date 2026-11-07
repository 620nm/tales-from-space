local network_matter = require("@helpers/network_matter")
local ui_controls = require("@helpers/ui_controls")

-- The portable liquid dewar (structures/atmos/dewar.luau, fixtures/dewar.luau):
--   1. Fastened to a connector port, it equalizes condensed liquid with the
--      pipe run while keeping its gas headspace isolated; a wrench unfastens
--      and re-fastens it on a port and refuses bare floor.
--   2. An open handheld vessel draws liquid out on primary click and pours
--      liquid in on the secondary gesture (`t.use_item(..., "secondary")`).
--   3. Its canister inspector window exposes the drain valve, volumetric rate
--      (`L/s`), port status, and relief pressure; draining loose onto the deck
--      steps its standalone sprite through `dewar` -> `dewar_g2` -> `dewar_g1`
--      -> `dewar_g0` with no overlay stack.
--   4. Its 1200 kPa headspace relief valve vents boil-off gas into the room
--      without dumping the liquid slug, while an extreme overpressure charge
--      past 3000 kPa ruptures it into `broken` (`dewar_broken`), and ordinary
--      gas canisters keep their pressure-regulated release unchanged.

local function near(got: number?, want: number, tol: number, what: string)
    assert(got ~= nil, what .. ": missing reading")
    assert(math.abs(got - want) <= tol, ("%s: wanted %g, got %g"):format(what, want, got))
end

local function last_message(p: number): string
    local msgs = t.messages(p)
    return msgs[#msgs] or ""
end

local function heard(p: number, want: string): boolean
    for _, s in ipairs(t.sounds(p)) do
        if s == want then
            return true
        end
    end
    return false
end

local function dewar_liquid_water(x: number, y: number): number
    local v = assert(t.vessel_at(x, y, "dewar"), "expected dewar at (" .. x .. ", " .. y .. ")")
    local w = v.contents.water
    return if w ~= nil then (w.liquid or 0.0) else 0.0
end

local function room_liquid_water(x: number, y: number): number
    local rl = t.room_liquid(x, y)
    return if rl ~= nil then (rl.water or 0.0) else 0.0
end

local function dewar_gas_n2(x: number, y: number): number
    local v = assert(t.vessel_at(x, y, "dewar"), "expected dewar at (" .. x .. ", " .. y .. ")")
    local n2 = v.contents.n2
    return if n2 ~= nil then (n2.gas or 0.0) else 0.0
end

-- ---------------------------------------------------------------------------
-- World 1: connector-port liquid equalization, gas isolation, wrenching,
-- handheld vessel draw & pour-in, inspector UI, volumetric drain & fill bands.
-- ---------------------------------------------------------------------------
t.world(
    [==[(
    name: "dewar bench",
    environment: (gravity_m_s2: Exact(9.80665)),
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    blends: {
        // 500 L liquid water (27 754.65 mol) plus 50 mol N2 gas headspace.
        "half_water_n2": (rows: [
            ("water", 27754.6489),
            ("n2", 50.0),
        ], temperature_k: 293.15, amount: total),
        // 800 L liquid water (44 407.44 mol, 80% of 1000 L shell -> full band g3).
        "eight_hundred_l_water": (rows: [
            ("water", 44407.4382),
        ], temperature_k: 293.15, amount: total),
    },
    levels: [
        (
            rows: [
                "#######",
                "#.....#",
                "#.....#",
                "#.....#",
                "#######",
            ],
            networks: [
                (x: 2, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
                (x: 3, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
            ],
            structures: [
                (2, 2, "player_spawn"),
                (1, 1, "connector_port"),
                (1, 1, "dewar", { "blend": "half_water_n2" }),
                (4, 1, "connector_port"),
                (4, 1, "dewar"),
                (5, 2, "dewar", { "blend": "eight_hundred_l_water" }),
                (5, 3, "dewar"),
            ],
            items: [
                (2, 2, "wrench"),
                (2, 3, "beaker"),
                (3, 3, "water_bottle"),
            ],
        ),
    ],
)]==],
    0
)

local p = t.join()
t.tick()

-- 1. Fastened connector-port liquid equalization and gas headspace isolation.
local port_dewar_a = assert(t.structure_at(1, 1))
local port_dewar_b = assert(t.structure_at(4, 1))
assert(port_dewar_a.id == "dewar" and port_dewar_a.state == "anchored", "dewar A starts anchored on its port")
assert(port_dewar_a.sprite == "dewar_connected", "anchored dewar wears dewar_connected")
assert(#port_dewar_a.overlays == 0, "dewar uses standalone sprites with no overlay stack")
assert(port_dewar_b.id == "dewar" and port_dewar_b.state == "anchored", "dewar B starts anchored on its port")

local pipe_gas_before = network_matter.gas(2, 1)
local pipe_n2_before = if pipe_gas_before ~= nil then (pipe_gas_before.n2 or 0.0) else 0.0

t.run_seconds(25)

-- 500 L of liquid water equalizes across dewar A (1000 L), two L3 pipe tiles (140 L),
-- and dewar B (1000 L), while the 50 mol N2 gas headspace stays isolated in dewar A.
local liq_a = dewar_liquid_water(1, 1)
local liq_b = dewar_liquid_water(4, 1)
assert(liq_a < 20000.0 and liq_a > 10000.0, "dewar A shared liquid into the pipe run: " .. liq_a)
near(liq_a, liq_b, 50.0, "dewar B received an equal liquid share through the L3 pipe run")
near(dewar_gas_n2(1, 1), 50.0, 0.5, "dewar A kept its N2 gas headspace")
near(dewar_gas_n2(4, 1), 0.0, 1e-4, "dewar B received no N2 gas across the liquid port")
local pipe_gas = network_matter.gas(2, 1)
near(if pipe_gas ~= nil then (pipe_gas.n2 or 0.0) else 0.0, pipe_n2_before, 1e-4, "the L3 pipe run received no N2 gas from the dewar headspace")

-- Wrench unanchor -> displaced (shows fill-band sprite `dewar_g1` for ~23% fill),
-- wrench re-anchor -> `dewar_connected`, wrench on bare floor -> refused.
t.click(p, 2, 2, assert(t.target_at(p, 2, 2, "wrench")))
t.run_ticks(2)
assert(t.hands(p).held == "wrench", "picked up wrench")

t.click(p, 1, 1, assert(t.target_at(p, 1, 1, "dewar")))
t.run_ticks(2)
local unfastened = assert(t.structure_at(1, 1))
assert(unfastened.state == "displaced", "wrench unfastens the dewar from the port")
assert(unfastened.sprite == "dewar_g1", "displaced dewar at ~23% fill wears dewar_g1, got " .. tostring(unfastened.sprite))
assert(#unfastened.overlays == 0, "still no overlay stack when displaced")

t.click(p, 1, 1, assert(t.target_at(p, 1, 1, "dewar")))
t.run_ticks(2)
local refastened = assert(t.structure_at(1, 1))
assert(refastened.state == "anchored" and refastened.sprite == "dewar_connected", "wrench re-fastens the dewar to the port")

-- Loose dewar at (5, 3) stands on bare floor with no connector port.
local _ = t.messages(p)
t.move(p, "east")
t.run_ticks(3)
t.move(p, "east")
t.run_ticks(3)
t.click(p, 5, 3, assert(t.target_at(p, 5, 3, "dewar")))
t.run_ticks(2)
assert(last_message(p) == "There is nothing here to fasten it to.", "bare floor refuses wrench fastening")
assert(assert(t.structure_at(5, 3)).state == "displaced", "loose dewar on bare floor stays displaced")

t.drop(p)
t.run_ticks(2)

-- 2. Handheld vessel draw (primary click) and pour-in (secondary gesture).
local sealed_bottle = assert(t.target_at(p, 3, 3, "water_bottle"))
t.click(p, 3, 3, sealed_bottle)
t.run_ticks(2)
t.click(p, 5, 2, assert(t.target_at(p, 5, 2, "dewar")))
t.tick()
assert(last_message(p) == "Open the bottle before drawing into it.", "sealed bottle refuses drawing from dewar")
local empty_dewar = assert(t.target_at(p, 5, 3, "dewar"))
t.use_item(p, empty_dewar, "secondary")
t.tick()
assert(last_message(p) == "Open the vessel before pouring.", "sealed vessel refuses pour-in")
t.drop(p)
t.run_ticks(2)

t.move(p, "west")
t.run_ticks(3)
local beaker = assert(t.target_at(p, 2, 3, "beaker"))
t.click(p, 2, 3, beaker)
t.run_ticks(2)
assert(t.hands(p).held == "beaker", "beaker in hand")

t.move(p, "east")
t.run_ticks(3)
empty_dewar = assert(t.target_at(p, 5, 3, "dewar"))
t.use_item(p, empty_dewar, "secondary")
t.tick()
assert(
    last_message(p) == "There is no liquid in your hand to pour into the dewar.",
    "empty beaker refuses pour-in"
)

-- Primary click on the full dewar at (5, 2) draws 10 u (0.25 mol) of liquid water into the beaker.
local full_dewar_before = dewar_liquid_water(5, 2)
t.click(p, 5, 2, assert(t.target_at(p, 5, 2, "dewar")))
t.tick()
assert(last_message(p) == "You draw liquid into the beaker.", "primary click draws liquid from dewar")
near(dewar_liquid_water(5, 2), full_dewar_before - 0.25, 1e-3, "dewar lost 0.25 mol to the beaker")

-- Secondary click on the empty dewar at (5, 3) pours the beaker's 0.25 mol into it.
t.use_item(p, empty_dewar, "secondary")
t.tick()
assert(last_message(p) == "You pour liquid into the dewar.", "secondary gesture pours liquid into dewar")
near(dewar_liquid_water(5, 3), 0.25, 1e-3, "receiving dewar gained the poured 0.25 mol")

t.drop(p)
t.run_ticks(2)

-- 3. Inspector UI (valve + rate in L/s), volumetric room drain & fill-band sprites.
assert(assert(t.structure_at(5, 2)).sprite == "dewar", "80% full loose dewar starts at g3 sprite 'dewar'")
t.click(p, 5, 2, assert(t.target_at(p, 5, 2, "dewar")))
t.tick()
local ui = ui_controls.record(assert(t.ui(p), "empty-hand click opens dewar inspector"))
local valve_row = ui_controls.rows(ui.toggles)[1]
assert(valve_row.field == "valve" and valve_row.on == false, "drain valve starts shut")
local rate_row = ui_controls.rows(ui.setpoints)[1]
assert(rate_row.field == "rate" and rate_row.unit == "L/s", "liquid dewar setpoint is rate in L/s")
near(ui_controls.number(rate_row.value), 10.0, 1e-3, "default drain rate is 10 L/s")
near(ui_controls.number(rate_row.max), 50.0, 1e-3, "max drain rate is 50 L/s")

local port_word, relief_word = nil, nil
for _, r in ipairs(ui_controls.rows(ui.readouts)) do
    local label = ui_controls.word(r.label)
    if label == "canister.port" then
        port_word = ui_controls.word(r.value)
    elseif label == "canister.relief" then
        relief_word = ui_controls.word(r.value)
    end
end
assert(port_word == "canister.port.loose", "loose dewar reports loose port status")
assert(relief_word == "1200 kPa", "dewar reports 1200 kPa relief valve: " .. tostring(relief_word))

-- Drain at 50 L/s and step through g2 (40..75%), g1 (10..40%), and g0 (<10% and empty).
ui_controls.set(p, "rate", 50)
ui_controls.toggle(p, "valve")
t.tick()

t.run_seconds(3) -- ~650 L left (65%)
assert(assert(t.structure_at(5, 2)).sprite == "dewar_g2", "at ~65% fill dewar wears dewar_g2")
assert(room_liquid_water(5, 2) > 10.0, "drained liquid water stands on the room tile")

t.run_seconds(7) -- ~300 L left (30%)
assert(assert(t.structure_at(5, 2)).sprite == "dewar_g1", "at ~30% fill dewar wears dewar_g1")

t.run_seconds(5) -- ~50 L left (5%)
assert(assert(t.structure_at(5, 2)).sprite == "dewar_g0", "at ~5% fill dewar wears dewar_g0")

t.run_seconds(3) -- 0 L left (empty)
assert(assert(t.structure_at(5, 2)).sprite == "dewar_g0", "empty dewar stays on dewar_g0")
near(dewar_liquid_water(5, 2), 0.0, 1e-3, "dewar finished draining its liquid charge")

-- ---------------------------------------------------------------------------
-- World 2: headspace boil-off relief (> 1200 kPa, < 3000 kPa), extreme
-- overpressure rupture (> 3000 kPa -> `dewar_broken`), and gas canister check.
-- ---------------------------------------------------------------------------
t.world(
    [==[(
    name: "dewar relief and rupture",
    environment: (gravity_m_s2: Exact(9.80665)),
    legend: {
        '.': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    blends: {
        // 200 L liquid water (11 101.86 mol) + 600 mol N2 in 800 L headspace (~1828 kPa at 293.15 K).
        "pressurized_dewar": (rows: [
            ("water", 11101.8596),
            ("n2", 600.0),
        ], temperature_k: 293.15, amount: total),
        "canister_air": (rows: [
            ("o2", 392.86967015394526),
            ("n2", 1477.93828296008),
        ], temperature_k: 293.15, amount: per_m3),
    },
    levels: [
        (
            rows: [
                "#####",
                "#...#",
                "#...#",
                "#...#",
                "#####",
            ],
            structures: [
                (2, 2, "player_spawn"),
                (1, 1, "dewar", { "blend": "pressurized_dewar" }),
                (3, 1, "connector_port"),
                (3, 1, "canister", { "blend": "canister_air" }),
            ],
            items: [
                (2, 3, "beaker.water"),
            ],
        ),
    ],
)]==],
    0
)

local q = t.join()
t.tick()

-- 4a. Shut dewar above 1200 kPa (below 3000 kPa) vents headspace gas through
-- its relief valve without losing its liquid water slug or taking damage.
local p_start = assert(t.canister_pressure(1, 1))
assert(p_start > 1700.0 and p_start < 2000.0, "headspace starts above 1200 kPa relief: " .. p_start)
local n2_start = dewar_gas_n2(1, 1)
local water_start = dewar_liquid_water(1, 1)
local room_p_start = assert(t.room_pressure(1, 1))

t.run_seconds(10)

local p_relieved = assert(t.canister_pressure(1, 1))
assert(p_relieved < p_start - 300.0, "relief valve vented headspace pressure down: " .. p_start .. " -> " .. p_relieved)
assert(dewar_gas_n2(1, 1) < n2_start - 100.0, "dispersed N2 gas left through the relief valve")
assert(assert(t.room_pressure(1, 1)) > room_p_start + 10.0, "vented headspace gas raised room pressure")
near(dewar_liquid_water(1, 1), water_start, 5.0, "liquid water slug stayed inside the shut dewar during gas relief")
near(room_liquid_water(1, 1), 0.0, 1e-3, "relief valve dumped no liquid onto the floor")
assert(heard(q, "hiss"), "relief valve hissed when opening")
assert(#t.ledger_rows("pressure_damaged") == 0, "relief below 3000 kPa kept the dewar undamaged")

-- 4b. Ordinary gas canister regression in the same world.
local gas_can = assert(t.structure_at(3, 1))
assert(gas_can.id == "canister", "control gas canister is present")
t.click(q, 3, 1, assert(t.target_at(q, 3, 1, "canister")))
t.tick()
local can_ui = ui_controls.record(assert(t.ui(q)))
local can_setpoint = ui_controls.rows(can_ui.setpoints)[1]
assert(can_setpoint.field == "release" and can_setpoint.unit == "kPa", "ordinary gas canister keeps release kPa setpoint")
ui_controls.set(q, "release", 400)
ui_controls.toggle(q, "valve")
t.run_seconds(3)
assert(assert(t.canister_pressure(3, 1)) < 4000.0, "ordinary gas canister still releases gas through its regulator")
t.ui_close(q)
t.tick()

-- Pick up the filled beaker before triggering the overpressure rupture.
t.click(q, 2, 3, assert(t.target_at(q, 2, 3, "beaker.water")))
t.run_ticks(2)

-- 4c. Extreme overpressure (> 3000 kPa overwhelming relief) ruptures the dewar
-- into `broken` (`dewar_broken`) and dumps its liquid slug into the room.
assert(t.charge_vessel(1, 1, "n2", 500000.0), "extreme overpressure charge applied to dewar")
t.run_seconds(5)

assert(#t.ledger_rows("pressure_ruptured") == 1, "dewar ruptured once under extreme overpressure")
local broken_x, broken_y = nil, nil
for y = 1, 3 do
    for x = 1, 3 do
        local st = t.structure_at(x, y)
        if st ~= nil and st.id == "dewar" then
            broken_x, broken_y = x, y
            assert(st.state == "broken", "ruptured dewar is in state broken")
            assert(st.sprite == "dewar_broken", "ruptured dewar wears dewar_broken")
            assert(#st.overlays == 0, "ruptured dewar has no overlays")
        end
    end
end
assert(broken_x ~= nil and broken_y ~= nil, "broken dewar shell remains in the room")
local total_floor_water = 0.0
for y = 1, 3 do
    for x = 1, 3 do
        total_floor_water = total_floor_water + room_liquid_water(x, y)
    end
end
assert(total_floor_water > 100.0, "ruptured dewar dumped its liquid water into the room: " .. total_floor_water)

-- Pouring into a broken dewar is refused with `structures.dewar.broken_refusal`.
local bx, by = assert(broken_x), assert(broken_y)
local qx, qy = t.pos(q)
while math.abs(qx - bx) > 1 or math.abs(qy - by) > 1 do
    if qx < bx then
        t.move(q, "east")
    elseif qx > bx then
        t.move(q, "west")
    end
    if qy < by then
        t.move(q, "south")
    elseif qy > by then
        t.move(q, "north")
    end
    t.run_ticks(3)
    qx, qy = t.pos(q)
end
t.use_item(q, assert(t.target_at(q, bx, by, "dewar")), "secondary")
t.tick()
assert(
    last_message(q) == "The dewar is split open and cannot hold liquid.",
    "broken dewar refuses pour-in: " .. last_message(q)
)
t.click(q, bx, by, assert(t.target_at(q, bx, by, "dewar")))
t.tick()
assert(
    last_message(q) == "That vessel is split open and holds nothing to draw.",
    "broken dewar refuses draw: " .. last_message(q)
)
