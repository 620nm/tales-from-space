-- What a wire is doing, before you cut it.
--
-- `sim.segment_live(x, y)` is the read half of the power boundary: the
-- liveness the last electrical pass settled on, per channel, for the
-- cable under a tile. It is the same answer every consumer binds
-- against (power/grid.rs), so a probe and a light fixture cannot
-- disagree about whether a circuit is up.
--
-- Three answers worth telling apart, and the spec is that they are
-- three rather than two: a line carrying something, a line carrying
-- nothing, and NO LINE AT ALL -- which is nil, and which the tool
-- declines rather than reporting as dead. "There is no cable here" and
-- "there is a dead cable here" are the two facts an engineer is
-- actually choosing between at a junction box.
local RED, YELLOW = 1, 2

local function said(p, want)
    for _, m in ipairs(t.messages(p)) do
        if m == want then
            return true
        end
    end
    return false
end

-- Bare plating throughout: cable is subfloor work, and a finished floor
-- is a deck the probe cannot read through. The generator in the corner
-- feeds the yellow line beside it; the red stub in the second row is
-- wired to nothing at all.
t.world([==[(
    name: "junction",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'G': (turf: Plating, fixture: Some(Generator)),
    },
    rows: [
        "#####",
        "#G..#",
        "#...#",
        "#####",
    ],
    spawns: [(2, 1)],
    items: [(2, 1, "multitool")],
    cables: [(1, 1, 2, 0, 4), (2, 1, 2, 4, 8), (3, 1, 2, 0, 8), (2, 2, 1, 0, 1)],
)]==], 7)

local p = t.join()
t.tick()
t.run_seconds(3) -- the electrical pass is 0.5 Hz; let one land

t.click(p, 2, 1, t.target_at(2, 1, "multitool")) -- pick the probe up
t.run_ticks(2)

-- ---- a line with something pushing into it ----------------------------
t.click(p, 3, 1)
t.tick()
assert(
    said(p, "The cable here is carrying equipment and lighting."),
    "the generator's line reads live: " .. table.concat(t.messages(p), " | ")
)

-- ---- a line with nothing pushing into it ------------------------------
-- Same tile family, same probe, one fact different: this stub touches
-- no source, so it is a cable and it is dead. The tool says so rather
-- than saying nothing, because "dead" is the answer that stops an
-- engineer looking for a break that is not there.
t.click(p, 2, 2)
t.tick()
assert(
    said(p, "The cable here is dead."),
    "the orphan stub reads dead: " .. table.concat(t.messages(p), " | ")
)
assert(t.cable_at(2, 2) == RED, "and it really is a cable, on the red line")
assert(t.cable_at(3, 1) == YELLOW, "as the live one is on the yellow")

-- ---- no line at all ---------------------------------------------------
-- The probe declines: nil is the type test every other reader keeps, and
-- a hook that declines falls through to whatever the click would have
-- meant otherwise (docs/LUAU-API.md section 9).
t.click(p, 3, 2)
t.tick()
assert(
    not said(p, "The cable here is dead."),
    "a tile with no cable is not a dead cable: " .. table.concat(t.messages(p), " | ")
)
