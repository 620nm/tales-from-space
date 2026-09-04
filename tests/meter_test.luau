-- The flow meter: a dial bolted onto a run.
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
        'c': (turf: Plating),
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
    blends: {
        // Standard air, deliberately: a recipe is moles PER TILE and the
        // shell is 2 m3, so this fills the bottle to exactly one
        // atmosphere -- and the bottle and the run are one body of gas
        // while fastened, so the needle stop this spec pins is the
        // one-atmosphere stop.
        "canister_air": (rows: [("o2", 8.730437114532117), ("n2", 32.84307295466844)], temperature_k: 293.15, amount: per_tile),
    },
    structures: [
        (1, 1, "connector_port"),
        (1, 1, "canister", { "blend": "canister_air", "open": true }),
    ],
)]==], 7)

local p = t.join()
t.tick()

t.click(p, 1, 2, t.target_at(1, 2, "wrench"))
t.run_ticks(2)
assert(t.hands(p).held == "wrench", "wrench in hand")

-- Let the bottle and the run settle into one body of gas.
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
-- The housing is the base sprite, the needle is an overlay above it and
-- the lit button panel an overlay above that, which is how tg's
-- greyscale config composes one (three layers, `meter.json`). A
-- distribution main at one atmosphere sits at tg's fourth stop of
-- twenty (meter.dm:82-94) -- the low scale gets half the dial, because
-- that is the range a station actually runs at, and every stop of that
-- scale wears tg's `buttons1`.
local drawn = t.layers(p, t.target_at(2, 1, "meter"))
assert(drawn[1] == "meter_base", "the housing")
assert(drawn[2] == "meter_p1_3", "and the needle at one atmosphere: " .. tostring(drawn[2]))
assert(drawn[3] == "meter_l1", "and the lamp for that band: " .. tostring(drawn[3]))
assert(#drawn == 3, "and nothing else")

-- ---- and it answers a look, from anywhere you can see it ----
--
-- tg's `status()` (meter.dm:123-131), word for word -- except that
-- every word is in the content file and only the numbers are the
-- engine's. tg appends it to `examine()` (meter.dm:123-135), which is
-- a VIEW-range gesture: the whole point of bolting a dial to a run is
-- reading it without walking over. Two tiles east is past arm's length
-- and well inside the room.
local reading = "The pressure gauge reads "
    .. r2(t.pipe_pressure(2, 1))
    .. " kPa; 293.15 K (20°C)."

walk(p, "east")
walk(p, "east")
assert(t.pos(p) == 4, "standing off down the deck: " .. t.pos(p))
local look = t.examine(p, 2, 1, t.target_at(2, 1, "meter"))
assert(look ~= nil, "a gauge in view answers a look")
local read_at_range = false
for _, line in ipairs(look.lines) do
    if line == reading then
        read_at_range = true
    end
end
assert(read_at_range, "the look carries the reading: " .. table.concat(look.lines, " | "))

-- ...and a click on it from there reaches nothing at all, because a
-- look is done with the eyes and a hand is still a hand.
local _ = t.messages(p)
t.click(p, 2, 1, t.target_at(2, 1, "meter"))
t.run_ticks(2)
assert(t.ui(p) == nil, "no panel opens from across the room")

-- ---- and it opens a panel when you reach it ----
--
-- tg pushes the same sentence into chat on `interact()`
-- (meter.dm:152-156). Here the numbers are live -- they move while you
-- stand there watching them -- so they go on the surface this game
-- repushes for that, which is a settings panel. An empty hand, because
-- a wrench means something else here.
walk(p, "west")
walk(p, "west")
t.swap_hands(p)
t.click(p, 2, 1, t.target_at(2, 1, "meter"))
t.run_ticks(2)
local panel = t.ui(p)
assert(panel ~= nil, "an attached gauge answers an empty hand with a panel")
assert(panel.document == "modules" and panel.presentation == "modules",
    "its declared module document")
assert(#panel.toggles == 0 and #panel.setpoints == 0, "and nothing on it to turn")

local shown = {}
for _, r in ipairs(panel.readouts) do
    shown[r.label] = r.value
end
assert(
    shown.pressure == string.format("%.1f kPa", t.pipe_pressure(2, 1)),
    "the panel reads the run: " .. tostring(shown.pressure)
)
assert(shown.temperature == "293.2 K", "and how warm it is: " .. tostring(shown.temperature))

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

-- ---------------------------------------------------------------
-- The needle answers the run AS IT STANDS THIS TICK.
--
-- A meter reads on the atmos cadence, but the plumbing under it
-- changes whenever a player says so: laying a length onto a charged
-- main gives the same moles more pipe to fill, and the pressure falls
-- the moment the two are one network. The dial has to fall with it. A
-- gauge that waits for the next pass is a gauge reporting a station
-- that stopped existing half a second ago -- and this is a dial whose
-- entire job is to be believed.
-- ---------------------------------------------------------------
t.world([==[(
    name: "extended main",
    legend: { '.': (turf: Plating), '#': (turf: Wall) },
    rows: [
        "######",
        "#....#",
        "######",
    ],
    spawns: [(3, 1)],
    items: [(3, 1, "pipe")],
    pipes: [(1, 1, 4), (2, 1, 4)],
    structures: [(1, 1, "meter")],
)]==], 7)

local m = t.join()
t.tick()
t.run_seconds(1.0)

local gauge = t.target_at(1, 1, "meter")
-- Housing, needle, lamp: the needle is the MIDDLE layer, never the last
-- one, because tg draws its button panel over the top of the dial.
local function needle()
    local drawn = t.layers(m, gauge)
    return drawn[2]
end
local function lamp()
    local drawn = t.layers(m, gauge)
    return drawn[3]
end
-- The lamp tg pairs with a needle face: `pressureN_M` -> `buttonsN`
-- (datums/greyscale/json_configs/meter.json).
local function band_of(face)
    return "meter_l" .. string.sub(face, 8, 8)
end

local commissioned = needle()
assert(
    commissioned ~= nil and string.sub(commissioned, 1, 7) == "meter_p",
    "the mapped main reads on the dial: " .. tostring(commissioned)
)
assert(
    lamp() == band_of(commissioned),
    "and the lamp is the one for its band: " .. tostring(lamp())
)

-- Pick the length up and lay it on the end of the main.
t.click(m, 3, 1, t.target_at(3, 1, "pipe"))
t.run_ticks(2)
t.click(m, 3, 1)

-- Tick by tick, so that "the tick it happens" means something.
local laid = false
for _ = 1, 60 do
    t.tick()
    if t.pipe(3, 1) ~= 0 then
        laid = true
        break
    end
end
assert(laid, "the length went down")
local widened = needle()
assert(
    widened ~= commissioned,
    "and the dial already reads the longer main: "
        .. tostring(commissioned) .. " -> " .. tostring(widened)
)

assert(
    lamp() == band_of(widened),
    "and the lamp moved with it: " .. tostring(lamp())
)

-- Which is where it stays: nothing was waiting for an atmos pass to
-- catch the picture up with the world.
t.run_seconds(2.0)
assert(needle() == widened, "the needle settled there and stayed: " .. tostring(needle()))
assert(lamp() == band_of(widened), "and so did its lamp: " .. tostring(lamp()))
