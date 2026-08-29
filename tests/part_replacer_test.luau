-- THE EXCHANGER: a bag you walk a machine's sockets with, and the one
-- gesture in this pack that upgrades something already standing.
--
-- tg's rapid part exchange device (`part_replacer.dm`,
-- `_machinery.dm`'s `exchange_parts`): click a machine with it and
-- every socket it holds a strictly better part for gets one, while
-- what came out goes back into the bag -- so a tech walks a row of
-- machines without stopping to tidy, and one pass leaves them carrying
-- as many parts as they set out with.
--
-- The whole of "is this an upgrade for that" is two numbers compared
-- (items/part_replacer.luau), so nothing below names a socket word or
-- a machine id from the tool's side. What the spec asserts is the four
-- things a crewman could see: the panel, the bag, the shift record,
-- and the beaker.
local function rows_in(ui, section)
    local out = {}
    for _, r in ipairs(ui.readouts) do
        if r.section == section then
            table.insert(out, r)
        end
    end
    return out
end

local function row(ui, label)
    for _, r in ipairs(ui.readouts) do
        if r.label == label then
            return r
        end
    end
    return nil
end

-- The chamber's one part row, read off a panel opened with a BARE hand
-- -- a click with something in it is that thing being used.
local function socket(p, x, y)
    t.click(p, x, y, t.target_at(x, y))
    t.tick()
    local rows = rows_in(t.ui(p), "parts")
    assert(#rows == 1, "one socket, one row: got " .. #rows)
    t.ui_close(p)
    return rows[1]
end

-- The same bench the reaction chamber's own spec uses, with the tool
-- and its cargo on the deck beside the crewman.
t.world([==[(
    name: "exchange bench",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        'o': (turf: Floor, fixture: Some(Outlet)),
        'a': (turf: Floor, fixture: Some(Apc)),
        'g': (turf: Floor, fixture: Some(Generator)),
    },
    rows: [
        "#######",
        "#o.a#g#",
        "#######",
    ],
    spawns: [(1, 1)],
    machines: [(2, 1, "chem_heater")],
    items: [
        (1, 1, "beaker.libital"),
        (1, 1, "part_replacer"),
        (1, 1, "micro_laser.tier3"),
    ],
    cables: [
        (1, 1, 1, 0, 4), (1, 1, 2, 0, 4), (2, 1, 1, 0, 4), (2, 1, 1, 0, 8),
        (2, 1, 2, 0, 4), (2, 1, 2, 0, 8), (3, 1, 1, 0, 4), (3, 1, 1, 0, 8),
        (3, 1, 2, 0, 4), (3, 1, 2, 0, 8), (4, 1, 1, 4, 8), (4, 1, 2, 4, 8),
        (5, 1, 1, 0, 8), (5, 1, 2, 0, 8),
    ],
)]==], 0)

local p = t.join()
t.run_seconds(1)

local heater = t.target_at(2, 1)
local beaker = t.target_at(1, 1, "beaker.libital")

-- ---------------------------------------------------------------
-- ONE: LOADING THE BAG IS THE ORDINARY GESTURE.
--
-- A container in the off hand takes what the working hand is holding
-- (sim/offhand.rs), which is tg's own flow of holding the toolbox in
-- one hand and the tool in the other. The exchanger is a bag like any
-- other and there is no second road into one.
-- ---------------------------------------------------------------
t.click(p, 1, 1, t.target_at(1, 1, "part_replacer"))
t.run_ticks(2)
assert(t.hands(p).held == "part_replacer", "the exchanger is in hand")
t.swap_hands(p)
t.click(p, 1, 1, t.target_at(1, 1, "micro_laser.tier3"))
t.run_ticks(2)
assert(t.hands(p).held == "micro_laser.tier3", "and a rung three laser in the other")

t.use_on_other(p)
t.run_ticks(2)
assert(t.hands(p).held == nil, "putting one into the other empties the working hand")
t.swap_hands(p)
assert(t.hands(p).held == "part_replacer", "the bag is the thing still held")
assert(t.examine_held_stored(p, 0).title == "ultra-high-power micro-laser",
    "and it is what is in the bag")

-- ---------------------------------------------------------------
-- TWO: THE CHAMBER, BEFORE ANYBODY TOUCHED IT.
--
-- A beaker goes in, the dial goes to 350, and the element runs against
-- the plain rung of the ladder. Everything after this is measured
-- against what it does here.
-- ---------------------------------------------------------------
t.swap_hands(p)
t.click(p, 1, 1, beaker)
t.run_ticks(2)
assert(t.hands(p).held == "beaker.libital", "the beaker is in hand")
t.click(p, 2, 1, heater)
t.run_ticks(2)
assert(t.hands(p).held == nil, "and clicking the chamber with it puts it in")

local before = socket(p, 2, 1)
assert(before.label == "micro-laser", "nobody has upgraded it: " .. before.label)
assert(before.value == "tier 1 · 1.00", "the plain rung, worth the plain part: " .. before.value)

t.click(p, 2, 1, heater)
t.tick()
assert(row(t.ui(p), "vessel").value == "beaker (libital)", "with the beaker docked")
t.ui_act(p, "set", '{"field":"temperature","value":350}')
t.ui_act(p, "toggle", '{"field":"power"}')
t.run_ticks(2)
t.ui_close(p)

-- tg's element closes a fixed FRACTION of the remaining gap every pass
-- (chem_heater.dm:172), so what a window of time measures is not a
-- rate of kelvin but a rate of CLOSING: the gap at the end of a window
-- over the gap at its start. That fraction is the one thing the laser
-- moves, and the two windows below are the same length and both
-- measured with nothing else happening in them.
local function gap()
    return 350.0 - t.holder_k(beaker)
end

local WINDOW_S = 6
local plain_open = gap()
t.run_seconds(WINDOW_S)
local plain_shut = gap()
assert(plain_shut < plain_open,
    "the plain chamber is climbing: " .. plain_open .. " -> " .. plain_shut)

-- ---------------------------------------------------------------
-- THREE: ONE CLICK, AND THE SOCKET IS SOMEBODY ELSE'S PART.
-- ---------------------------------------------------------------
t.swap_hands(p)
assert(t.hands(p).held == "part_replacer", "the exchanger comes back out")
local _ = t.messages(p)
t.click(p, 2, 1, heater)
t.run_ticks(2)
assert(table.concat(t.messages(p), " | "):find("swap out 1", 1, true) ~= nil,
    "the tool says what it did: " .. table.concat(t.messages(p), " | "))

local swaps = t.ledger_rows("part_swapped")
assert(#swaps == 1, "one socket changed, so one row: " .. #swaps)
assert(swaps[1].slot == 1, "and it names the socket, counting from one: " .. swaps[1].slot)
assert(swaps[1].from == "micro_laser", "what came out: " .. swaps[1].from)
assert(swaps[1].to == "micro_laser.tier3", "and what went in: " .. swaps[1].to)

-- What came out went back into the bag it came out of, which is what
-- makes one pass leave a tech carrying what they set out with.
assert(t.examine_held_stored(p, 0).title == "micro-laser",
    "the displaced part is in the bag now")

t.swap_hands(p)
local after = socket(p, 2, 1)
assert(after.label == "ultra-high-power micro-laser",
    "and the panel names what is in there now: " .. after.label)
assert(after.value == "tier 3 · 2.00",
    "against its rung and what it is worth: " .. after.value)

-- ---------------------------------------------------------------
-- FOUR: AND A SECOND CLICK IS NOTHING AT ALL.
--
-- The bag now holds the part that came out, which is worse than what
-- is in the socket. Strictly better is the whole rule, so nothing
-- moves and the tool says so.
-- ---------------------------------------------------------------
t.swap_hands(p)
local _ = t.messages(p)
t.click(p, 2, 1, heater)
t.run_ticks(2)
assert(#t.ledger_rows("part_swapped") == 1, "still one swap on the record")
assert(table.concat(t.messages(p), " | "):find("any better", 1, true) ~= nil,
    "and the refusal is the tool's own line")
t.swap_hands(p)
assert(socket(p, 2, 1).value == "tier 3 · 2.00", "the socket is where it was")

-- ---------------------------------------------------------------
-- FIVE: THE BEAKER AGREES WITH THE PANEL.
--
-- Same beaker, same dial, same six seconds -- and the gap closes at
-- the LADDER's ratio. Rung three is worth 2.00 against the plain
-- part's 1.00 (lib/stock_parts.luau), and a law that closes a fixed
-- fraction of the gap per pass turns a doubled coefficient into a
-- doubled LOGARITHM of what is left: the ratio of the two windows'
-- log-closings is the ratio of the two parts.
--
-- A little over 2 rather than exactly 2, and by an amount the law
-- names: a pass closes `coeff * dt` of the gap and not `coeff` of it
-- continuously, so the honest prediction is
-- `ln(1 - 2f) / ln(1 - f)` at `f = 0.05` -- 2.054, not 2.000. A
-- fifteenth either way covers that and the open beaker's own latent
-- loss, and is nowhere near wide enough to admit the rung above
-- (3.00) or the rung below (1.50).
-- ---------------------------------------------------------------
local upgraded_open = gap()
t.run_seconds(WINDOW_S)
local upgraded_shut = gap()
assert(upgraded_shut < upgraded_open,
    "the upgraded chamber is still climbing: " .. upgraded_open .. " -> " .. upgraded_shut)

local ratio = math.log(upgraded_shut / upgraded_open) / math.log(plain_shut / plain_open)
assert(math.abs(ratio - 2.0) < 0.15,
    "a rung three laser closes the gap at twice the plain rate: " .. ratio)
