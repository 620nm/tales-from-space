-- The gas analyzer, and the three things worth pointing it at.
--
-- tg's `atmos_scan` (code/game/objects/items/devices/scanners/
-- gas_analyzer.dm:185-230) prints one line per fact about whatever atom
-- you clicked. This spec asserts those lines EXACTLY -- and it does not
-- pin magic numbers to do it: every number is cross-checked against the
-- same reading the spec API takes off the sim, so a readout that
-- silently drifted from the world it claims to describe fails here.

local function r2(n)
    local scaled = n * 100
    local rounded = if scaled >= 0 then math.floor(scaled + 0.5) else math.ceil(scaled - 0.5)
    return tostring(rounded / 100)
end

local function has(lines, want)
    for _, m in ipairs(lines) do
        if m == want then
            return true
        end
    end
    return false
end

local function matching(lines, prefix, suffix)
    for _, m in ipairs(lines) do
        if string.sub(m, 1, #prefix) == prefix and string.sub(m, -#suffix) == suffix then
            return m
        end
    end
    return nil
end

local function walk(p, dir)
    t.move(p, dir)
    t.run_ticks(5)
end

-- ---------------------------------------------------------------
-- A sealed room, a two-length run under an open deck with a canister
-- plumbed into it, and a stretch of bare plating out east with nothing
-- buried under it yet.
-- ---------------------------------------------------------------
t.world([==[(
    name: "analyzer",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        'o': (turf: Floor),
        '#': (turf: Wall),
        'c': (turf: Plating),
    },
    rows: [
        "#######",
        "#c..###",
        "#oo...#",
        "#######",
    ],
    spawns: [(1, 2)],
    items: [(1, 2, "analyzer"), (2, 2, "pipe")],
    pipes: [(2, 1, 5), (3, 1, 4)],
    air_presets: {
        "canister_air": (gases: [("o2", 392.86967015394526), ("n2", 1477.93828296008)], temperature_k: 293.15),
    },
    structures: [
        (1, 1, "connector_port"),
        (1, 1, "canister", { "air": "canister_air", "open": true }),
    ],
)]==], 7)

local p = t.join()
t.tick()

t.click(p, 1, 2, t.target_at(1, 2, "analyzer"))
t.run_ticks(2)
assert(t.hands(p).held == "analyzer", "analyzer in hand")

-- Let the bottle bring the run up to its release setpoint.
t.run_seconds(10)

-- ---- the air ----
--
-- A turf click is the ground: tg falls back to `get_turf(...)` for
-- anything with no gas mixture of its own, and open deck is that.
local _ = t.messages(p)
t.click(p, 2, 2)
t.run_ticks(2)
local air = t.messages(p)
assert(has(air, "Results of analysis of the air."), "the header names what was read")
assert(has(air, "Moles: " .. r2(0) .. " mol") == false, "and it is not empty")
assert(
    has(air, "Pressure: " .. r2(t.room_pressure(2, 2)) .. " kPa"),
    "the pressure it prints is the pressure the room is at"
)
-- One room cell is one cubic metre of station.
assert(has(air, "Volume: 1000 L"), "a tile of room is a thousand litres")
assert(
    has(air, "Temperature: 20 °C (293.15 K)"),
    "room temperature, in both scales, tg's T0C apart"
)
-- Standard air, and the readout says so in tg's own shape: moles, then
-- the share of the whole. Sorted by substance id, so nitrogen leads.
assert(matching(air, "Nitrogen: ", " mol (79 %)"), "four fifths nitrogen")
assert(matching(air, "Oxygen: ", " mol (21 %)"), "one fifth oxygen")

-- ---- the runs ----
--
-- A click cannot land on one pipe out of five, so a click on open
-- plating reads EVERYTHING under and over it, each mixture named: the
-- air, then every buried run by its layer. Two layers are laid here so
-- the ambiguity the labels exist for is actually on the tile.
local _ = t.messages(p)
t.click(p, 2, 1)
t.run_ticks(2)
local pipe = t.messages(p)
assert(has(pipe, "Results of analysis of the air."), "the turf is read first")
assert(has(pipe, "Results of analysis of the layer 3 pipe."), "the run, by name")
assert(
    has(pipe, "Pressure: " .. r2(t.pipe_pressure(2, 1)) .. " kPa"),
    "and the number an engineer would read off a meter there"
)
-- Two lengths of tg's UNARY_PIPE_VOLUME * 2, which is 70 L each.
assert(has(pipe, "Volume: 140 L"), "two lengths of pipe, and not the room")
-- The second layer answers separately, and answers for itself: one
-- lone length holding the boot air it was commissioned with, 70 L --
-- not the canister-fed pressure the run beside it carries.
assert(has(pipe, "Results of analysis of the layer 1 pipe."), "the other run, by name")
assert(has(pipe, "Volume: 70 L"), "one length, not the run beside it")

-- ---- the bottle ----
--
-- tg reads the ATOM you pointed at when it has air of its own
-- (`return_analyzable_air`), and a canister does.
local _ = t.messages(p)
t.click(p, 1, 1, t.target_at(1, 1, "canister"))
t.run_ticks(2)
local can = t.messages(p)
assert(has(can, "Results of analysis of the gas canister."), "the bottle answers for itself")
assert(
    has(can, "Pressure: " .. r2(t.canister_pressure(1, 1)) .. " kPa"),
    "at the pressure its own gauge lamps are a coarse picture of"
)
-- tg's canister is 2000 L.
assert(has(can, "Volume: 2000 L"), "and it is a two thousand litre bottle")

-- ---- an empty run ----
--
-- What you build, you fill yourself: a length wrenched down this shift
-- is not commissioned, so it holds nothing at all. tg prints the volume
-- for an empty mixture and nothing else, deliberately.
t.swap_hands(p)
t.click(p, 2, 2, t.target_at(2, 2, "pipe"))
t.run_ticks(2)
assert(t.hands(p).held == "pipe", "a length of pipe in the off hand")

walk(p, "east")
walk(p, "east")
walk(p, "east")
t.click(p, 5, 2)
t.run_seconds(1.5)
assert(t.pipe(5, 2) == 4, "a fresh length on the distribution layer")

t.swap_hands(p)
local _ = t.messages(p)
t.click(p, 5, 2)
t.run_ticks(2)
local fresh = t.messages(p)
assert(has(fresh, "Results of analysis of the layer 3 pipe."), "it is a pipe, named by layer")
assert(has(fresh, "The layer 3 pipe is empty!"), "and nobody has filled it")
assert(has(fresh, "Volume: 70 L"), "one length, and the volume still prints")
assert(has(fresh, "Results of analysis of the air."), "the turf still answers beside it")

-- ---- and it is an instrument, not a tool ----
--
-- Everything above is a query. The analyzer moved no gas, so the run it
-- read is at the pressure it was, and the ledger has nothing to say
-- about any of it.
assert(t.pipe_pressure(5, 2) == 0.0, "reading an empty pipe leaves it empty")
assert(not t.ledger_has("PipePainted"), "an analyzer paints nothing")
assert(not t.ledger_has("ScriptError"), "and asked the engine nothing it refused")
