-- The gas filter: the first machine with THREE mouths, and the first
-- one that cares which gas it is moving.
--
-- Everything the atmospherics kit has done so far moves gas as a bulk:
-- a pump does not know what is in the pipe and a valve does not care.
-- A filter is the machine that separates, so its whole correctness is a
-- question a pressure cannot answer -- did the right gas come out of
-- the right port -- and every assertion here is in MOLES, read the way
-- an analyser reads a line.
--
-- The T. A filter reaches three ways (behind the facing, the facing,
-- and turn(dir, -90), trinary_devices.dm:43-51), so it wants a junction
-- and not a straight run. Each map below lays one: a main running west
-- to east with the machine standing in a gap in it, and a one-length
-- stub dropping south. The engine aims the machine at the only facing
-- whose three mouths all have run to reach -- east -- so the input is
-- the west main, the pass-through is the east main, and the stub is the
-- side port.

-- A length of pipe is tg's 70 L; every device mouth is its 200 L
-- component mixture (components_base.dm:39).
local PIPE_M3 = 0.070
local PORT_M3 = 0.200

local function near(a, b, slack, what)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

local function said(p, want)
    for _, m in ipairs(t.messages(p)) do
        if m == want then
            return true
        end
    end
    return false
end

-- Moles of one gas standing in the run under a tile, or 0.
local function gas(x, y, which)
    local held = t.pipe_gas(x, y)
    return (held and held[which]) or 0.0
end

-- The three tiles every world here reads: input main, side stub,
-- pass-through main.
local IN_X, IN_Y = 2, 1
local SIDE_X, SIDE_Y = 3, 2
local OUT_X, OUT_Y = 4, 1

local JUNCTION = [==[(
    name: "gas filter",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'a': (turf: Plating, fixture: Some(Apc)),
        'g': (turf: Plating, fixture: Some(Generator)),
    },
    rows: [
        "########",
        "#......#",
        "#..a..g#",
        "########",
    ],
    spawns: [(3, 2)],
    items: [(3, 2, "wrench")],
    pipes: [(1, 1, 4), (2, 1, 4), (4, 1, 4), (5, 1, 4), (3, 2, 4)],
    structures: [(3, 1, "%s")],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3), (4, 1, 3), (5, 1, 3), (6, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3), (4, 2, 3), (5, 2, 3), (6, 2, 3),
    ],
)]==]

-- ---------------------------------------------------------------
-- A FILTER SEPARATES, AND LOSES NOTHING DOING IT.
--
-- All three nets open the shift commissioned with the same standard
-- air, so there is oxygen and nitrogen on both sides of the machine
-- before it ever runs. That is deliberate: it means "the oxygen went to
-- the side port" cannot be read off a pressure and has to be read off
-- the books. The side port's NITROGEN is the sharpest number in the
-- file -- nothing in a correct filter can ever add a mole of it, so it
-- must still be exactly what the map handed over.
-- ---------------------------------------------------------------
t.world(JUNCTION:format("gas_filter"), 7)

local p = t.join()
t.tick()

local m = t.structure_at(3, 1)
assert(m ~= nil and m.id == "gas_filter", "the filter is where the map put it")
assert(m.state == "off", "and tg's filter ships off")

-- The run does not pass through the machine: its own length is nobody's
-- and each mouth opens onto a net of its own.
assert(t.pipe_pressure(3, 1) == nil, "no net claims the machine's tile")
assert(t.pipe_pressure(IN_X, IN_Y) > 90.0, "the input main is charged")
assert(t.pipe_pressure(OUT_X, OUT_Y) > 90.0, "so is the pass-through main")
assert(t.pipe_pressure(SIDE_X, SIDE_Y) > 90.0, "and so is the side stub")

-- Each net is 200 L bigger than its lengths, because the mouth in the
-- machine's face belongs to it: two lengths either side, one below.
local IN_M3 = 2 * PIPE_M3 + PORT_M3
local SIDE_M3 = 1 * PIPE_M3 + PORT_M3
near(
    gas(IN_X, IN_Y, "o2") / gas(SIDE_X, SIDE_Y, "o2"),
    IN_M3 / SIDE_M3,
    0.01,
    "two nets at one pressure hold gas in proportion to their volume"
)

local in_o2, in_n2 = gas(IN_X, IN_Y, "o2"), gas(IN_X, IN_Y, "n2")
local side_o2, side_n2 = gas(SIDE_X, SIDE_Y, "o2"), gas(SIDE_X, SIDE_Y, "n2")
local main_o2, main_n2 = gas(OUT_X, OUT_Y, "o2"), gas(OUT_X, OUT_Y, "n2")
assert(in_o2 > 0 and in_n2 > 0, "standard air is two gases: " .. in_o2 .. " / " .. in_n2)
local books_o2 = in_o2 + side_o2 + main_o2
local books_n2 = in_n2 + side_n2 + main_n2

-- An idle filter is a length of pipe. Give it every chance.
t.run_seconds(10)
near(gas(OUT_X, OUT_Y, "n2"), main_n2, 1e-9, "an off filter moves nothing")
near(gas(SIDE_X, SIDE_Y, "o2"), side_o2, 1e-9, "out of either mouth")

-- ---------------------------------------------------------------
-- The panel. tg's filter has no wheel and no switch on the casing --
-- clicking one is `ui_interact` (filter.dm:123-127) -- so an empty hand
-- opens the window rather than working the machine.
-- ---------------------------------------------------------------
t.click(p, 3, 1, t.target_at(3, 1, "gas_filter"))
t.tick()
local ui = t.ui(p)
assert(ui, "clicking a gas filter opens its window")
assert(ui.document == "modules" and ui.presentation == "modules",
    "the generic module document")

assert(ui.toggles[1].field == "power", "the first switch is the power")
assert(ui.toggles[1].on == false)
assert(ui.setpoints[1].field == "rate", "the one knob is the transfer rate")
near(ui.setpoints[1].value, 200.0, 0.001, "at tg's MAX_TRANSFER_RATE")
near(ui.setpoints[1].max, 200.0, 0.001, "which is also the top of the dial")

-- The roster: a field carrying a LIST, one toggle per substance the
-- matter registry gives a GAS PHASE to, each naming its own option.
-- Nothing selected out of the box, which is tg's empty `filter_type`.
-- Water and chlorine are on it because both stand in a pipe as gas
-- whenever the run is hot or thin enough; only a reagent with no
-- modelled gas phase at all is left off, because its button could
-- never divert anything.
local roster = {}
for _, sw in ipairs(ui.toggles) do
    if sw.field == "filter" then
        roster[sw.option] = sw.on
    end
end
assert(roster.o2 == false, "oxygen is offered, and starts unselected")
assert(roster.n2 == false, "so is nitrogen")
assert(roster.plasma == false, "and every other gas the registry knows")
assert(roster.water == false, "water has a gas phase, so it has a button")
assert(roster.salt == nil, "and salt has none, so it does not")

-- ---------------------------------------------------------------
-- Switch it on and set it to divert oxygen. Two clicks, both through
-- the window the player has open.
-- ---------------------------------------------------------------
t.ui_act(p, "toggle", '{"field":"power"}')
t.ui_act(p, "toggle", '{"field":"filter","option":"o2"}')
t.tick()
assert(t.ui(p).toggles[1].on == true, "the panel reports the machine running")
assert(t.structure_at(3, 1).state == "running", "and the machine wears it")
for _, sw in ipairs(t.ui(p).toggles) do
    if sw.field == "filter" and sw.option == "o2" then
        assert(sw.on == true, "oxygen is selected")
    end
    if sw.field == "filter" and sw.option == "n2" then
        assert(sw.on == false, "and nitrogen is not")
    end
end

t.run_seconds(30)

-- The headline. Oxygen left by the side port; nitrogen carried on.
assert(
    gas(SIDE_X, SIDE_Y, "o2") > side_o2 + 1.0,
    "the side port collected the oxygen: " .. side_o2 .. " -> " .. gas(SIDE_X, SIDE_Y, "o2")
)
assert(
    gas(OUT_X, OUT_Y, "n2") > main_n2 + 1.0,
    "and the nitrogen carried straight on: " .. main_n2 .. " -> " .. gas(OUT_X, OUT_Y, "n2")
)

-- And the two numbers a wrong filter would move. Nothing in this
-- machine can put nitrogen out of the side port or oxygen out of the
-- front, so both are still exactly what the map handed over.
near(gas(SIDE_X, SIDE_Y, "n2"), side_n2, 1e-9, "no nitrogen ever reached the side port")
near(gas(OUT_X, OUT_Y, "o2"), main_o2, 1e-9, "no oxygen ever reached the pass-through")

-- The input paid for all of it, and the books balance to the mole.
assert(
    t.pipe_pressure(IN_X, IN_Y) < 5.0,
    "the input main is drained: " .. t.pipe_pressure(IN_X, IN_Y)
)
near(
    gas(IN_X, IN_Y, "o2") + gas(SIDE_X, SIDE_Y, "o2") + gas(OUT_X, OUT_Y, "o2"),
    books_o2,
    1e-6,
    "every mole of oxygen is still somewhere"
)
near(
    gas(IN_X, IN_Y, "n2") + gas(SIDE_X, SIDE_Y, "n2") + gas(OUT_X, OUT_Y, "n2"),
    books_n2,
    1e-6,
    "and so is every mole of nitrogen"
)

-- Both acts are on the record, against the PLAYER, and the roster act
-- says WHICH gas -- which is what the settings contract's `option`
-- carries (docs/TGUI.md).
assert(t.ledger_has("MachineToggled", "power", "Player"), "switching it on is an attributed act")
assert(t.ledger_has("MachineToggled", "filter", "o2", "Player"), "so is selecting a gas")

-- ---------------------------------------------------------------
-- NEGATIVE: the window a machine is showing IS the whitelist.
--
-- A gas the registry does not define, a substance that is not a gas at
-- all, and a rate past the dial: none of them is a knob this panel
-- offered, so none of them moves anything.
-- ---------------------------------------------------------------
local function selected(which)
    for _, sw in ipairs(t.ui(p).toggles) do
        if sw.field == "filter" and sw.option == which then
            return sw.on
        end
    end
    return nil
end

t.ui_act(p, "toggle", '{"field":"filter","option":"tabasco"}')
t.ui_act(p, "toggle", '{"field":"filter","option":"water"}')
t.ui_act(p, "toggle", '{"field":"power","option":"o2"}')
t.tick()
assert(selected("o2") == true, "an invented gas selects nothing")
assert(selected("n2") == false, "and unselects nothing")
assert(t.ui(p).toggles[1].on == true, "and the power switch is not a roster")

t.ui_act(p, "set", '{"field":"rate","value":9000}')
t.tick()
near(t.ui(p).setpoints[1].value, 200.0, 0.001, "a client cannot dial past MAX_TRANSFER_RATE")
t.ui_act(p, "set", '{"field":"rate","value":-40}')
t.tick()
near(t.ui(p).setpoints[1].value, 0.0, 0.001, "nor below nothing at all")

-- ---------------------------------------------------------------
-- AN EMPTY ROSTER PASSES EVERYTHING.
--
-- tg's own comment: "If no filter is set, we just try to forward
-- everything to air3 to avoid gas being outright lost"
-- (filter.dm:96-97). A filter with nothing selected is a length of pipe
-- with a rate limit, not a wall -- and the side port stays exactly
-- where it was.
-- ---------------------------------------------------------------
t.world(JUNCTION:format("gas_filter"), 7)

local q = t.join()
t.tick()
local was_side_o2, was_side_n2 = gas(SIDE_X, SIDE_Y, "o2"), gas(SIDE_X, SIDE_Y, "n2")
local was_main = gas(OUT_X, OUT_Y, "o2") + gas(OUT_X, OUT_Y, "n2")

t.click(q, 3, 1, t.target_at(3, 1, "gas_filter"))
t.tick()
t.ui_act(q, "toggle", '{"field":"power"}')
t.run_seconds(30)

assert(
    gas(OUT_X, OUT_Y, "o2") + gas(OUT_X, OUT_Y, "n2") > was_main + 2.0,
    "with nothing selected, everything went straight through"
)
near(gas(SIDE_X, SIDE_Y, "o2"), was_side_o2, 1e-9, "and the side port took no oxygen")
near(gas(SIDE_X, SIDE_Y, "n2"), was_side_n2, 1e-9, "and no nitrogen either")
assert(t.pipe_pressure(IN_X, IN_Y) < 5.0, "the input still emptied: nothing was lost")

-- ---------------------------------------------------------------
-- THE ROUND TRIP, AND THE REFUSAL IN FRONT OF IT.
--
-- tg's `can_unwrench` will not let you take a running filter off the
-- line ("turn off!", filter.dm:176-180). Here that is not a rule in the
-- engine: the wrench row belongs to the machine's OFF state, so a
-- running one has no wrench row at all and is told which state it
-- wants.
-- ---------------------------------------------------------------
t.world(JUNCTION:format("gas_filter"), 7)

local r = t.join()
t.tick()

-- Switch it on first, so the refusal has something to refuse.
t.click(r, 3, 1, t.target_at(3, 1, "gas_filter"))
t.tick()
t.ui_act(r, "toggle", '{"field":"power"}')
t.run_ticks(2)
assert(t.structure_at(3, 1).state == "running", "running")
t.ui_close(r)

t.click(r, 3, 2, t.target_at(3, 2, "wrench"))
t.run_ticks(2)
assert(t.hands(r).held == "wrench", "wrench in hand")

local _ = t.messages(r)
t.click(r, 3, 1, t.target_at(3, 1, "gas_filter"))
t.run_seconds(2.5)
assert(
    said(r, "The gas filter must be off first."),
    "a running filter is not something you unbolt"
)
assert(t.structure_at(3, 1) ~= nil, "and it is still on the line")

-- Switch it off with the other hand, and the same click works.
t.swap_hands(r)
t.click(r, 3, 1, t.target_at(3, 1, "gas_filter"))
t.tick()
t.ui_act(r, "toggle", '{"field":"power"}')
t.run_ticks(2)
assert(t.structure_at(3, 1).state == "off", "off")
t.ui_close(r)
t.swap_hands(r)

t.click(r, 3, 1, t.target_at(3, 1, "gas_filter"))
t.run_seconds(2.5)
assert(t.structure_at(3, 1) == nil, "the filter comes up off the pipe")
-- `yields` mint on the TARGET's tile (docs/CONSTRUCTION.md): what came
-- off the line lands where the machine stood, not at the feet of
-- whoever took it off.
local lying = false
for _, id in ipairs(t.items_at(3, 1)) do
    if id == "gas_filter_fitting" then
        lying = true
    end
end
assert(lying, "and what came up is a fitting lying on the deck")

-- ---------------------------------------------------------------
-- A PRESET ARRIVES SET UP.
--
-- tg ships eighteen of these (filter.dm:224-241) so a mapper laying a
-- waste loop does not have to open eighteen panels. The nitrogen filter
-- runs from the moment the map hands it over, and it diverts nitrogen
-- without anybody touching it.
-- ---------------------------------------------------------------
t.world(JUNCTION:format("gas_filter.n2"), 7)

local s = t.join()
t.tick()
assert(t.structure_at(3, 1).state == "running", "a preset filter opens the shift running")
local pre_side_o2 = gas(SIDE_X, SIDE_Y, "o2")
local pre_main_n2 = gas(OUT_X, OUT_Y, "n2")

-- The file's `filter = { "n2" }` reached the machine's roster, not just
-- its behaviour: the panel shows nitrogen already selected.
t.click(s, 3, 1, t.target_at(3, 1, "gas_filter.n2"))
t.tick()
for _, sw in ipairs(t.ui(s).toggles) do
    if sw.field == "filter" then
        assert(
            sw.on == (sw.option == "n2"),
            "the preset selected nitrogen and only nitrogen, not " .. tostring(sw.option)
        )
    end
end
t.ui_close(s)

t.run_seconds(30)
assert(
    gas(SIDE_X, SIDE_Y, "n2") > pre_main_n2 * 0.5,
    "it diverted nitrogen with nobody touching it: " .. gas(SIDE_X, SIDE_Y, "n2")
)
near(gas(SIDE_X, SIDE_Y, "o2"), pre_side_o2, 1e-9, "and only nitrogen")
near(gas(OUT_X, OUT_Y, "n2"), pre_main_n2, 1e-9, "none of which reached the pass-through")
assert(t.pipe_pressure(IN_X, IN_Y) < 5.0, "and the input emptied into the pair")

-- ---------------------------------------------------------------
-- ...AND THE PRESET IS ONLY A SHORTHAND.
--
-- `gas_filter.n2` is a VARIANT of gas_filter.luau, which means the two
-- lines it carries -- `on` and `filter` -- are the same two properties
-- any placement may write on a bare machine (docs/CONTENT-SCHEMA.md
-- §1.1a). If that were not true the variant would be a second
-- prototype wearing a dotted name, and a mapper who wanted argon
-- instead would be back to asking for a new file.
--
-- So: the plain machine, told the same two things by the map, is the
-- preset.
-- ---------------------------------------------------------------
local BY_HAND = JUNCTION:gsub(
    '%(3, 1, "%%s"%)',
    '(3, 1, "gas_filter", { "on": true, "filter": "n2" })'
)
t.world(BY_HAND, 7)

local h = t.join()
t.tick()
local hand = t.structure_at(3, 1)
assert(hand.id == "gas_filter", "a bare filter, with the map's own words on it")
assert(hand.state == "running", "which is running, because the placement said so")
local hand_side_o2 = gas(SIDE_X, SIDE_Y, "o2")
local hand_main_n2 = gas(OUT_X, OUT_Y, "n2")
t.click(h, 3, 1, t.target_at(3, 1, "gas_filter"))
t.tick()
for _, sw in ipairs(t.ui(h).toggles) do
    if sw.field == "filter" then
        assert(
            sw.on == (sw.option == "n2"),
            "with nitrogen selected and nothing else, not " .. tostring(sw.option)
        )
    end
end
t.ui_close(h)
t.run_seconds(30)
assert(
    gas(SIDE_X, SIDE_Y, "n2") > hand_main_n2 * 0.5,
    "and it separates exactly as the preset did"
)
near(gas(SIDE_X, SIDE_Y, "o2"), hand_side_o2, 1e-9, "and only nitrogen")
