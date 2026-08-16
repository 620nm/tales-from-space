-- The stationary pressure tank: what a map put in one, where it goes,
-- and what the glass in its side says about it.
--
-- tg's tank is a 2500 L reservoir with a mouth on each cardinal and no
-- valve anywhere (tank.dm). It does not pump -- `custom_reconcilation`
-- folds its contents into every pipeline its ports reach and the lot
-- settles as ONE body of gas, split by volume. So the assertions here
-- are about a thing that has no controls at all: it holds what the map
-- said, it shares with whatever it is welded to, and it can be read.
--
-- The map fill is the mechanism this spec exists for. `("o2", 23000.0)`
-- on the placement is how a station says what is in THIS tank, and it
-- replaces tg's twenty named subtypes (/tank/oxygen, /tank/nitrogen,
-- ...) with a fact about a station rather than twenty prototypes.
-- 23 000 kPa is tg's own `starting_pressure_percent = 0.5` of the
-- 46 000 kPa rating.

t.world([==[(
    name: "tank bay",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "########",
        "#......#",
        "#......#",
        "#......#",
        "########",
    ],
    spawns: [(2, 2)],
    structures: [
        (3, 2, "stationary_tank", "anchored", ("o2", 23000.0)),
    ],
    pipes: [(4, 2, 4), (5, 2, 4), (6, 2, 4)],
)]==], 7)

local p = t.join()

local function readout(panel, label)
    for _, r in ipairs(panel.readouts) do
        if r.label == label then
            return r.value
        end
    end
    return nil
end

local function moles(panel, label)
    local row = readout(panel, label)
    return row and tonumber(string.match(row, "[%d%.]+")) or 0.0
end

-- ---------------------------------------------------------------
-- What the map authored is what stands there, before a single atmos
-- pass has had a chance to move it.
-- ---------------------------------------------------------------
local filled = t.tank_pressure(3, 2)
assert(filled, "a tank stands where the map placed one")
assert(math.abs(filled - 23000.0) < 50.0,
    "filled to the authored pressure by the ideal gas law: " .. filled)

local standing = t.structure_at(3, 2)
assert(standing.id == "stationary_tank", "and it is the tank: " .. standing.id)
assert(standing.state == "anchored", "bolted down: " .. tostring(standing.state))

-- ---------------------------------------------------------------
-- The contents window. tg has no interface for this machine at all --
-- it has a pane of glass with the gas visibly swirling behind it --
-- so this is that reading, itemised: one row per gas present, and no
-- controls, because the ports are the valves.
-- ---------------------------------------------------------------
t.tick()
t.click(p, 3, 2, t.target_at(3, 2))
t.tick()
local ui = t.ui(p)
assert(ui, "clicking the tank opens its window")
assert(ui.native == "settings", "the generic settings panel: " .. tostring(ui.native))
assert(ui.kind == "tank", "kind: " .. tostring(ui.kind))
assert(#ui.toggles == 0, "a tank has no switch")
assert(#ui.setpoints == 0, "and no dial -- its ports are its valves")
assert(ui.gauge and ui.gauge > 0.0 and ui.gauge < 100.0,
    "the gauge reads against the 46 000 kPa sticker: " .. tostring(ui.gauge))

assert(readout(ui, "oxygen"), "one row PER GAS PRESENT, named by the gas")
assert(readout(ui, "nitrogen") == nil, "and no row for a gas that is not in there")
assert(readout(ui, "pressure"), "a pressure row")
assert(readout(ui, "temperature"), "a temperature row")
assert(readout(ui, "volume"), "and the vessel's own size and rating")

local tank_o2 = moles(ui, "oxygen")
assert(tank_o2 > 20000.0, "a full 2500 L vessel is tens of thousands of moles: " .. tank_o2)
local pipe_o2 = t.pipe_gas(5, 2).o2

-- ---------------------------------------------------------------
-- It free-flows into the run its east mouth reaches, and the books
-- balance: every mole the pipe gained came out of the tank.
--
-- A run opens the shift holding one atmosphere of ordinary station
-- air, so the nitrogen already in it is not something the tank put
-- there -- it is diluted, not removed. A tank is not a filter.
-- ---------------------------------------------------------------
t.run_seconds(5)

local piped = t.pipe_gas(5, 2)
assert(piped, "the run under the deck is bound to the tank")
assert(piped.o2 > pipe_o2 + 1000.0, "and it is now full of the tank's gas: " .. piped.o2)
assert(piped.o2 > 100.0 * (piped.n2 or 0.0),
    "overwhelmingly the tank's gas, not the air it started with")

local settled = t.tank_pressure(3, 2)
local pipe_kpa = t.pipe_pressure(5, 2)
assert(settled < filled - 500.0,
    "the tank is what paid for it: " .. filled .. " -> " .. settled)
-- One body of gas, split by volume, means one PRESSURE. tg equalises
-- completely in a pass and so does this; if the two ever disagreed the
-- tank would be acting like a pump, which it is not.
assert(math.abs(settled - pipe_kpa) < 50.0,
    "vessel and run settle to one pressure: " .. settled .. " vs " .. pipe_kpa)

-- The window is LIVE, not a snapshot taken when it opened: the same
-- panel, re-read after the gas moved, reports the vessel it is
-- standing in front of.
local tank_now = moles(t.ui(p), "oxygen")
assert(tank_now < tank_o2 - 1000.0,
    "the window tracks the vessel: " .. tank_o2 .. " -> " .. tank_now)

-- Nothing was conjured and nothing was destroyed. This is the whole
-- point of the transfer being a draw rather than a written pressure.
local before_total = tank_o2 + pipe_o2
local after_total = tank_now + piped.o2
assert(math.abs(after_total - before_total) < before_total * 0.001,
    "the books balance: " .. before_total .. " -> " .. after_total)

-- ---------------------------------------------------------------
-- NEGATIVE: the window a machine is showing IS the whitelist, and
-- this one shows nothing. A client inventing the canister's valve or
-- the pump's dial moves neither.
-- ---------------------------------------------------------------
t.ui_act(p, "toggle", '{"field":"valve"}')
t.ui_act(p, "set", '{"field":"target","value":0}')
t.ui_act(p, "set", '{"field":"release","value":0}')
t.run_ticks(2)
assert(#t.ui(p).toggles == 0 and #t.ui(p).setpoints == 0,
    "no invented control appears on the panel")
