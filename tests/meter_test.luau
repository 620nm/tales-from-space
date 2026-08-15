-- The gas flow meter: a dial bolted onto a run.
--
-- tg's `/obj/machinery/meter` (code/modules/atmospherics/machinery/
-- other/meter.dm) is the one machine in atmospherics that does nothing
-- to the gas at all, and this spec is mostly about proving that: the
-- line reads the same with the meter on it as without, because an
-- instrument that changed what it was measuring would be a poor one.

local function r2(n)
    local scaled = n * 100
    local rounded = if scaled >= 0 then math.floor(scaled + 0.5) else math.ceil(scaled - 0.5)
    return tostring(rounded / 100)
end

local function said(p, line)
    for _, m in ipairs(t.messages(p)) do
        if m == line then
            return true
        end
    end
    return false
end

local function lying_at(x, y, id)
    for _, item in ipairs(t.items_at(x, y)) do
        if item == id then
            return true
        end
    end
    return false
end

local function walk(p, dir)
    t.move(p, dir)
    t.run_ticks(5)
end

-- ---------------------------------------------------------------
-- A short run under an open deck with a canister plumbed into it, a
-- meter fitting lying on the pipe waiting to be wrenched down, and a
-- second one out on bare plating that never can be.
-- ---------------------------------------------------------------
t.world([==[(
    name: "meter",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        'o': (turf: Floor),
        '#': (turf: Wall),
        'c': (turf: Plating, fixture: Some(Canister)),
    },
    rows: [
        "######",
        "#c...#",
        "#oo..#",
        "######",
    ],
    spawns: [(1, 2)],
    items: [(1, 2, "wrench"), (2, 1, "pipe_meter"), (3, 2, "pipe_meter")],
    pipes: [(2, 1, 4), (3, 1, 4)],
    structures: [(1, 1, "connector_port")],
)]==], 7)

local p = t.join()
t.tick()

t.click(p, 1, 2, t.target_at(1, 2, "wrench"))
t.run_ticks(2)
assert(t.hands(p).held == "wrench", "wrench in hand")

-- Let the bottle bring the run up to its release setpoint.
t.run_seconds(10)
local charged = t.pipe_pressure(2, 1)
assert(charged > 90.0, "the run is live: " .. charged .. " kPa")

-- ---- a gauge needs something to gauge ----
--
-- tg's meter simply finds no candidate pipe and reads nothing forever
-- (`reattach_to_layer`); a refusal at the door is the better version of
-- that, and it is the same `over = "pipe"` rule a connector port takes.
walk(p, "east")
local _ = t.messages(p)
t.click(p, 3, 2, t.target_at(3, 2, "pipe_meter"))
t.run_ticks(2)
assert(
    said(p, "There is no pipe under the floor here."),
    "the refusal names the rule that stopped it"
)
assert(t.structure_at(3, 2) == nil, "nothing was bolted to nothing")
assert(lying_at(3, 2, "pipe_meter"), "and the fitting survived the attempt")

-- ---- bolt one onto the run ----
t.click(p, 2, 1, t.target_at(2, 1, "pipe_meter"))
t.run_ticks(1)
assert(not t.ledger_has("StructureStep", "meter", "built"), "one tick in, still a fitting")
t.run_seconds(2.5)
assert(t.ledger_has("StructureStep", "meter", "built"), "and two seconds in, it is a meter")

local bolted = t.structure_at(2, 1)
assert(bolted ~= nil and bolted.id == "meter", "a meter stands on the run")
assert(bolted.state == "attached", "attached, the only state a meter has")
assert(not lying_at(2, 1, "pipe_meter"), "the fitting was spent into it")

-- ---- **the point**: it does nothing to the line ----
--
-- A binary device takes its tile out of the network and holds 200 L at
-- each port. A meter does neither: it is not IN the run, it reads one.
-- So the two ends of this two-length line are still one body of gas,
-- and the line is at the pressure it was before anyone bolted anything
-- to it.
t.run_seconds(5)
assert(
    t.pipe_pressure(2, 1) == t.pipe_pressure(3, 1),
    "the meter did not split the run it is measuring"
)
assert(
    math.abs(t.pipe_pressure(2, 1) - charged) < 1.0,
    "nor change what it reads: " .. charged .. " -> " .. t.pipe_pressure(2, 1)
)

-- ---- the needle reaches the wire ----
--
-- The housing is the base sprite and the needle is an overlay above it,
-- which is how tg's greyscale config composes one. A distribution main
-- at one atmosphere sits at tg's fourth stop of twenty (meter.dm:82-94)
-- -- the low scale gets half the dial, because that is the range a
-- station actually runs at.
local drawn = t.layers(p, t.target_at(2, 1, "meter"))
assert(drawn[1] == "meter_base", "the housing")
assert(drawn[2] == "meter_p1_3", "and the needle at one atmosphere: " .. tostring(drawn[2]))
assert(#drawn == 2, "and nothing else")

-- ---- and it answers when you look at it ----
--
-- tg's `status()` (meter.dm:123-131), word for word -- except that
-- every word is in the content file and only the numbers are the
-- engine's. An empty hand, because a wrench means something else here.
t.swap_hands(p)
local _ = t.messages(p)
t.click(p, 2, 1, t.target_at(2, 1, "meter"))
t.run_ticks(2)
assert(
    said(p, "The pressure gauge reads " .. r2(t.pipe_pressure(2, 1)) .. " kPa; 293.15 K (20°C)."),
    "the gauge reads what the line is actually at"
)

-- ---- take it off again ----
--
-- tg's `wrench_act`: forty deciseconds, and `on_deconstruction` mints
-- the fitting back onto the tile (meter.dm:139-147).
t.swap_hands(p)
t.click(p, 2, 1, t.target_at(2, 1, "meter"))
t.run_ticks(1)
assert(not t.ledger_has("StructureStep", "meter", "gone"), "one tick in, still bolted down")
t.run_seconds(4.5)
assert(t.ledger_has("StructureStep", "meter", "gone"), "four seconds in, it is off")
assert(t.structure_at(2, 1) == nil, "no meter here now")
assert(lying_at(2, 1, "pipe_meter"), "and what came up is the fitting it was built from")

-- The line never noticed any of it.
assert(t.pipe(2, 1) == 4, "the run it was bolted to is untouched")
assert(
    math.abs(t.pipe_pressure(2, 1) - charged) < 1.0,
    "and still at the pressure it was: " .. t.pipe_pressure(2, 1)
)
