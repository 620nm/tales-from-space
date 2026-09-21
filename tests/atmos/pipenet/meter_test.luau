local network_matter = require("@helpers/network_matter")
local network_channels = require("@helpers/network_channels")

local ui_controls = require("@helpers/ui_controls")

-- The flow meter: a dial bolted onto a run.
--
-- tg's `/obj/machinery/meter` (code/modules/atmospherics/machinery/
-- other/meter.dm) is the one machine in atmospherics that does nothing
-- to the gas at all, and this spec is mostly about proving that: the
-- line reads the same with the meter on it as without, because an
-- instrument that changed what it was measuring would be a poor one.

local function r2(n: number): string
    local scaled = n * 100
    local rounded = if scaled >= 0 then math.floor(scaled + 0.5) else math.ceil(scaled - 0.5)
    return tostring(rounded / 100)
end

local function said(p: number, line: string): boolean
    for _, m in ipairs(t.messages(p)) do
        if m == line then
            return true
        end
    end
    return false
end

local function lying_at(x: number, y: number, id: string): boolean
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
t.world(
    [==[(
    name: "meter",
    legend: {
        ' ': (composition: (substrate: Some("space"))),
        '.': (composition: (components: [(component: "station_base")])),
        'o': (composition: (components: [(component: "station_base"), (component: "floor_tiles")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
        'c': (composition: (components: [(component: "station_base")])),
    },
    rows: [
        "######",
        "#c...#",
        "#oo..#",
        "######",
    ],
    items: [(1, 2, "wrench"), (2, 1, "pipe_meter"), (3, 2, "pipe_meter")],
    networks: [
        (x: 2, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
        (x: 3, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
    ],
    blends: {
        // Standard air, deliberately: a recipe is moles PER TILE and the
        // shell is 2 m3, so this fills the bottle to exactly one
        // atmosphere -- and the bottle and the run are one body of gas
        // while fastened, so the needle stop this spec pins is the
        // one-atmosphere stop.
        "canister_air": (rows: [("o2", 8.730437114532117), ("n2", 32.84307295466844)], temperature_k: 293.15, amount: per_tile),
    },
    structures: [
        (1, 2, "player_spawn"),
        (1, 1, "connector_port"),
        (1, 1, "canister", { "blend": "canister_air", "open": true }),
    ],
)]==],
    7
)

local p = t.join()
t.tick()

t.click(p, 1, 2, t.target_at(p, 1, 2, "wrench"))
t.run_ticks(2)
assert(t.hands(p).held == "wrench", "wrench in hand")

-- Let the bottle and the run settle into one body of gas.
t.run_seconds(10)
local charged = assert(network_matter.pressure(2, 1))
assert(charged > 90.0, "the run is live: " .. charged .. " kPa")

-- ---- a gauge needs something to gauge ----
--
-- tg's meter simply finds no candidate pipe and reads nothing forever
-- (`reattach_to_layer`); a refusal at the door is the better version of
-- that, and it is the same `over = "pipe"` rule a connector port takes.
walk(p, "east")
local _ = t.messages(p)
local bare_meter = t.target_at(p, 3, 2, "pipe_meter")
assert(bare_meter ~= nil, "the loose meter is targetable")
t.click(p, 3, 2, bare_meter)
t.run_ticks(2)
assert(said(p, "You can't build that there."), "the installation refusal answers")
assert(t.structure_at(3, 2) == nil, "nothing was bolted to nothing")
assert(lying_at(3, 2, "pipe_meter"), "and the fitting survived the attempt")

-- ---- bolt one onto the run ----
t.click(p, 2, 1, t.target_at(p, 2, 1, "pipe_meter"))
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
    assert(network_matter.pressure(2, 1)) == assert(network_matter.pressure(3, 1)),
    "the meter did not split the run it is measuring"
)
assert(
    math.abs(assert(network_matter.pressure(2, 1)) - charged) < 1.0,
    "nor change what it reads: " .. charged .. " -> " .. assert(network_matter.pressure(2, 1))
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
local drawn = t.layers(p, t.target_at(p, 2, 1, "meter"))
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
    .. r2(assert(network_matter.pressure(2, 1)))
    .. " kPa; 293.15 K (20°C)."

walk(p, "east")
walk(p, "east")
assert(t.pos(p) == 4, "standing off down the deck: " .. t.pos(p))
local look = t.examine(p, 2, 1, t.target_at(p, 2, 1, "meter"))
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
t.click(p, 2, 1, t.target_at(p, 2, 1, "meter"))
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
t.click(p, 2, 1, t.target_at(p, 2, 1, "meter"))
t.run_ticks(2)
local panel = ui_controls.record(t.ui(p))
assert(panel ~= nil, "an attached gauge answers an empty hand with a panel")
assert(
    panel.document == "modules" and panel.presentation == "modules",
    "its declared module document"
)
assert(
    #ui_controls.rows(panel.toggles) == 0 and #ui_controls.rows(panel.setpoints) == 0,
    "and nothing on it to turn"
)

-- What is in the run, itemised: one block under the LINE heading —
-- the composition tg's chat line cannot give (docs/tgui/matter-block.md).
local line = ui_controls.rows(panel.matter or {})[1]
assert(
    line and ui_controls.record(line.section).id == "meter.line",
    "the panel draws the run it is reading"
)
local gas: ui_controls.Record? = nil
for _, st in ipairs(ui_controls.rows(line.states or {})) do
    if st.phase == "gas" then
        gas = st
    end
end
assert(gas, "a charged run holds a gas")
assert(
    math.abs(ui_controls.number(gas.measure) - assert(network_matter.pressure(2, 1))) < 1e-9,
    "the panel reads the run: " .. tostring(gas.measure)
)
assert(
    math.abs(ui_controls.number(line.temperature_k) - 293.15) < 0.05,
    "and how warm it is: " .. tostring(line.temperature_k)
)
local seen: { [string]: unknown } = {}
for _, row in ipairs(ui_controls.rows(gas.rows)) do
    seen[ui_controls.text(row.key)] = row.moles
end
assert(seen.o2 and seen.n2, "and what the pressure is made OF: o2 and n2")
assert(line.sealed == nil, "a run has no lid to report")

-- ---- take it off again ----
--
-- tg's `wrench_act`: forty deciseconds, and `on_deconstruction` mints
-- the fitting back onto the tile (meter.dm:139-147).
t.swap_hands(p)
t.click(p, 2, 1, t.target_at(p, 2, 1, "meter"))
t.run_ticks(1)
assert(not t.ledger_has("StructureStep", "meter", "gone"), "one tick in, still bolted down")
t.run_seconds(4.5)
assert(t.ledger_has("StructureStep", "meter", "gone"), "four seconds in, it is off")
assert(t.structure_at(2, 1) == nil, "no meter here now")
assert(lying_at(2, 1, "pipe_meter"), "and what came up is the fitting it was built from")

-- The line never noticed any of it.
assert(network_channels.at(2, 1, "pipe") == "l3", "the run it was bolted to is untouched")
assert(
    math.abs(assert(network_matter.pressure(2, 1)) - charged) < 1.0,
    "and still at the pressure it was: " .. assert(network_matter.pressure(2, 1))
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
t.world(
    [==[(
    name: "extended main",
    legend: { '.': (composition: (components: [(component: "station_base")])), '#': (composition: (components: [(component: "station_base"), (component: "wall")])) },
    rows: [
        "######",
        "#....#",
        "######",
    ],
    items: [(3, 1, "pipe")],
    networks: [
        (x: 1, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
        (x: 2, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15),
    ],
    structures: [(3, 1, "player_spawn"), (1, 1, "meter")],
)]==],
    7
)

local m = t.join()
t.tick()
t.run_seconds(1.0)

local gauge = t.target_at(m, 1, 1, "meter")
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
local function band_of(face: string): string
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
t.click(m, 3, 1, t.target_at(m, 3, 1, "pipe"))
t.run_ticks(2)
t.click(m, 3, 1, nil, -14, 14)

-- Tick by tick, so that "the tick it happens" means something.
local laid = false
for _ = 1, 60 do
    t.tick()
    if network_channels.at(3, 1, "pipe") ~= "" then
        laid = true
        break
    end
end
assert(laid, "the length went down")
local widened = needle()
assert(
    widened ~= commissioned,
    "and the dial already reads the longer main: "
        .. tostring(commissioned)
        .. " -> "
        .. tostring(widened)
)

assert(lamp() == band_of(widened), "and the lamp moved with it: " .. tostring(lamp()))

-- Which is where it stays: nothing was waiting for an atmos pass to
-- catch the picture up with the world.
t.run_seconds(2.0)
assert(needle() == widened, "the needle settled there and stayed: " .. tostring(needle()))
assert(lamp() == band_of(widened), "and so did its lamp: " .. tostring(lamp()))

-- ---------------------------------------------------------------
-- THE WHOLE DIAL, END TO END.
--
-- The face list is built rather than typed out, and it is TWENTY long:
-- the peg, then three scales of six stops each, then one off the top
-- (content/structures/atmos/meter.luau, `faces`). Nothing a spec may
-- call reads that list, so this bench reads it the way a crewman does
-- -- by putting a pressure on the run and looking at what the needle
-- does about it.
--
-- The bottle is the lever. A canister fastened to a port trades gas
-- with the run under it until both stand at the same density, and it
-- trades BOTH WAYS: an empty 2000 L shell pulls a commissioned length
-- down to nothing, and charging that same shell afterwards walks the
-- same length up through four decades of pressure. Its release valve
-- stays shut the whole way, so the room this stands in is no part of
-- any of it.
-- ---------------------------------------------------------------
t.world(
    [==[(
    name: "dial bench",
    legend: {
        '.': (composition: (components: [(component: "station_base")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    rows: [
        "#####",
        "#...#",
        "#####",
    ],
    networks: [(x: 2, y: 1, network: "pipe", channel: "l3", kind: "standard", facing: 15)],
    structures: [
        (3, 1, "player_spawn"),
        (1, 1, "connector_port"),
        (1, 1, "canister"),
        (2, 1, "meter"),
    ],
)]==],
    7
)

local w = t.join()
t.tick()
-- Long enough for the gauge to bind its run and for the empty bottle to
-- take that run down.
t.run_seconds(2.0)

local dial = assert(t.target_at(w, 2, 1, "meter"), "the bench gauge is there to be read")
local function needle_face(): string
    return t.layers(w, dial)[2]
end
local function needle_lamp(): string
    return t.layers(w, dial)[3]
end

-- Where a face sits in the list content built, 0 through 19: the peg is
-- 0, `meter_p<scale>_<stop>` is the stop'th of six on that scale, and
-- the face off the top is the last. That is `meter.luau`'s own build
-- order, read back one face at a time off the wire -- and a name that
-- fits none of those shapes is not a face this dial draws at all.
local function stop_of(name: string): number
    if name == "meter_p0" then
        return 0
    end
    if name == "meter_p4" then
        return 19
    end
    assert(
        #name == 10 and string.sub(name, 1, 7) == "meter_p" and string.sub(name, 9, 9) == "_",
        "a needle face this dial does not draw: " .. name
    )
    local scale = assert(tonumber(string.sub(name, 8, 8)), "a face names its scale: " .. name)
    local stop = assert(tonumber(string.sub(name, 10, 10)), "and its stop: " .. name)
    assert(scale >= 1 and scale <= 3, "three scales between the ends: " .. name)
    assert(stop >= 1 and stop <= 6, "six stops to a scale: " .. name)
    return (scale - 1) * 6 + stop
end

local ONE_ATM = 101.325

-- ---- the peg ----
--
-- tg's first stop is everything at or under 0.15 atmospheres
-- (meter.dm:82), and a 2000 L bottle with nothing in it leaves a single
-- length of pipe far under that.
local pegged = assert(network_matter.pressure(2, 1))
assert(pegged < 0.15 * ONE_ATM, "the empty bottle pumped the run down: " .. pegged .. " kPa")
assert(needle_face() == "meter_p0", "so the needle is at the peg: " .. needle_face())
assert(needle_lamp() == "meter_l0", "wearing the peg's own lamp: " .. needle_lamp())

-- ---- one known charge, to measure the lever ----
--
-- The bottle's shell and the run's bore are both fixed and the gas is
-- all at one temperature, so the share of a charge that ends up in the
-- run is a constant. Measuring it once is what lets every rung below
-- be aimed at a pressure rather than at a guess.
assert(t.charge_vessel(1, 1, "o2", 20.0), "the bottle takes a charge")
t.run_seconds(1.5)
local calibrated = assert(network_matter.pressure(2, 1))
local share = (calibrated - pegged) / 20.0
assert(share > 0.5, "a charge into the bottle reaches the run it feeds: " .. share)
assert(needle_face() == "meter_p1_1", "and the needle is off the peg: " .. needle_face())

-- ---- and then all the way up ----
--
-- tg's boundaries, in atmospheres (meter.dm:82-94): the peg to 0.15,
-- the low scale to 1.8, the middle to 30, the top to 59, and past 59
-- the needle is off the end. Every rung below sits well inside a scale
-- rather than on one of those edges, and names the part of the face
-- name that scale owns.
local ladder = {
    { kpa = 0.5 * ONE_ATM, scale = "meter_p1_" },
    { kpa = 1.0 * ONE_ATM, scale = "meter_p1_" },
    { kpa = 1.5 * ONE_ATM, scale = "meter_p1_" },
    { kpa = 3.0 * ONE_ATM, scale = "meter_p2_" },
    { kpa = 10.0 * ONE_ATM, scale = "meter_p2_" },
    { kpa = 25.0 * ONE_ATM, scale = "meter_p2_" },
    { kpa = 35.0 * ONE_ATM, scale = "meter_p3_" },
    { kpa = 50.0 * ONE_ATM, scale = "meter_p3_" },
    { kpa = 70.0 * ONE_ATM, scale = "meter_p4" },
}

local climbed = stop_of(needle_face())
local low_faces: { [string]: boolean } = {}
for _, rung in ipairs(ladder) do
    local standing = assert(network_matter.pressure(2, 1))
    assert(t.charge_vessel(1, 1, "o2", (rung.kpa - standing) / share), "the bottle takes more")
    t.run_seconds(1.5)
    local reached = assert(network_matter.pressure(2, 1))
    assert(
        math.abs(reached - rung.kpa) < 0.05 * rung.kpa,
        "the run went where it was sent: " .. reached .. " of " .. rung.kpa .. " kPa"
    )
    local drawn_face = needle_face()
    assert(
        string.sub(drawn_face, 1, #rung.scale) == rung.scale,
        reached .. " kPa reads on " .. rung.scale .. ", not on " .. drawn_face
    )
    local stop = stop_of(drawn_face)
    assert(stop > climbed, "and a rising pressure only ever climbs the dial: " .. drawn_face)
    climbed = stop
    assert(needle_lamp() == band_of(drawn_face), "its lamp rode with it: " .. needle_lamp())
    if string.sub(drawn_face, 1, 9) == "meter_p1_" then
        low_faces[drawn_face] = true
    end
end
assert(climbed == 19, "and the last rung is the far end of the list: " .. needle_face())

-- Three rungs on the low scale drew three DIFFERENT faces, which is
-- what having six stops on a scale means: the range a station actually
-- runs at gets half the dial, not one picture stretched across it.
local low = 0
for _ in pairs(low_faces) do
    low += 1
end
assert(low == 3, "the low scale drew a face per rung, not one for all three: " .. low)
