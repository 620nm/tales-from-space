-- The steam generator: put water in it, switch it on, and the pipe
-- behind it fills with steam that an injector hands to the room.
--
-- Baystation12's water-only heater
-- (`Baystation12/code/modules/reagents/Chemistry-Sublimator.dm:184-192`)
-- -- "it accepts water, and produces steam. Wow!" -- said with this
-- engine's physics: there is no exchange factor and no output
-- temperature here, only a vessel on a phase curve with a heater under
-- it and a mouth on a run (../lunatic/docs/ATMOS.md §9).
--
-- Everything below is a click or a window act, and every reading is
-- `t.pipe_gas` / `t.room_gas` in MOLES. A pressure cannot say WHICH gas
-- it is, and this whole machine is a claim about which one crosses.

-- A document's words are labels: `{id=…}` for one the engine names,
-- `{text=…}` for one content wrote (docs/tgui/labels.md).
local function word(label)
    if type(label) ~= "table" then return label end
    return label.id or label.text
end

local function near(a, b, slack, what)
    assert(math.abs(a - b) < slack, what .. ": " .. a .. " vs " .. b)
end

local function row(ui, label)
    for _, r in ipairs(ui.readouts) do
        if word(r.label) == label then
            return r
        end
    end
    return nil
end

local function pipe_of(x, y, which)
    local held = t.pipe_gas(x, y)
    return held and held[which] or 0.0
end

local function room_of(x, y, which)
    local held = t.room_gas(x, y)
    return held and held[which] or 0.0
end

local function held_in(handle, key)
    local contents = t.contents(handle)
    assert(contents ~= nil, "that is a vessel")
    return contents[key] or 0.0
end

-- A wired bay: a two-length distribution main with the generator on its
-- east end and an injector on its west, so the steam has somewhere to
-- be made and somewhere to go.
t.world([==[(
    name: "steam bay",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'a': (turf: Plating, fixture: Some(Apc)),
        'g': (turf: Plating, fixture: Some(Generator)),
    },
    rows: [
        "#######",
        "#.....#",
        "#...ag#",
        "#######",
    ],
    spawns: [(3, 1)],
    items: [(3, 1, "beaker.water"), (3, 1, "beaker.ethanol")],
    pipes: [(2, 1, 4), (3, 1, 4)],
    structures: [
        (1, 1, "air_injector", { "pipe": "east" }),
        (4, 1, "steam_generator", { "pipe": "west" }),
    ],
    cables: [
        (1, 1, 3), (2, 1, 3), (3, 1, 3), (4, 1, 3), (5, 1, 3),
        (1, 2, 3), (2, 2, 3), (3, 2, 3), (4, 2, 3), (5, 2, 3),
    ],
)]==], 7)

local p = t.join()
t.tick()

assert(t.structure_at(4, 1).id == "steam_generator", "the map stood one there")
local machine = t.target_at(4, 1, "steam_generator")
assert(machine ~= nil, "and a hand can reach it")

-- ---------------------------------------------------------------
-- AN EMPTY HAND ASKS, AND THE PANEL ANSWERS ABOUT BOTH ENDS.
--
-- The commonest fault on a machine like this is not on the machine: it
-- is the LINE behind it. So the window says what is in the slot and
-- what is in the pipe, which is the room-device panel's whole argument
-- borrowed intact (../lunatic/sim/ui/settings/room_device.rs).
-- ---------------------------------------------------------------
t.click(p, 4, 1, machine)
t.tick()
local ui = t.ui(p)
assert(ui, "an empty hand opens the panel")
assert(row(ui, "dock.vessel").value.id == "dock.vessel.empty", "it says there is nothing in it")
assert(row(ui, "line_dock.line") ~= nil, "and it reads the run behind the machine")
near(ui.setpoints[1].value, 313.15, 1e-9, "the dial opens at Bay's T0C+40")
t.ui_close(p)

-- ---------------------------------------------------------------
-- A BEAKER OF WATER GOES IN, AND THE LINE FILLS WITH STEAM.
-- ---------------------------------------------------------------
local water = t.target_at(3, 1, "beaker.water")
t.click(p, 3, 1, water)
t.tick()
assert(t.hands(p).held == "beaker.water", "the beaker is in hand")
t.click(p, 4, 1, machine)
t.tick()
assert(t.hands(p).held == nil, "clicking the machine with it puts it IN")
assert(t.ledger_has("Docked", "beaker"), "and the dock is on the record")

local charged = held_in(water, "water")
assert(charged > 0.5, "with the water it shipped with: " .. charged)
near(pipe_of(3, 1, "water"), 0.0, 1e-9, "the run opens dry")

t.click(p, 4, 1, machine)
t.tick()
assert(row(t.ui(p), "dock.vessel").value.text == "beaker (water)", "the panel names what is in it")
assert(t.ui(p).toggles[1].on == false, "and nothing ships switched on")

-- Dialled over water's boiling point, because the dial it opens at is
-- Bay's warm-room number and this spec is about steam.
t.ui_act(p, "set", '{"field":"temperature","value":400}')
t.ui_act(p, "toggle", '{"field":"power"}')
t.run_ticks(2)
assert(t.ui(p).toggles[1].on == true, "the element is on")

t.run_seconds(30)
local steamed = pipe_of(3, 1, "water")
assert(steamed > 1e-4, "thirty seconds and no steam reached the line: " .. steamed)
local left = held_in(water, "water")
near(steamed + left, charged, 1e-6, "and every mole of it is still on the books")

-- ---------------------------------------------------------------
-- ...AND THE INJECTOR ON THE FAR END HANDS IT TO THE ROOM.
--
-- Which is the whole point of plumbing the bench into the station: a
-- beaker boiling on a hotplate humidifies the tile it stands on, and
-- this humidifies wherever the run goes.
-- ---------------------------------------------------------------
t.ui_close(p)
-- Walk to it: a panel is opened by a hand that can reach the casing,
-- and the generator is at the other end of the bay.
t.move(p, "west")
t.run_ticks(5)
t.move(p, "west")
t.run_ticks(5)
local injector = t.target_at(1, 1, "air_injector")
t.click(p, 1, 1, injector)
t.tick()
t.ui_act(p, "toggle", '{"field":"power"}')
t.run_ticks(2)
assert(t.structure_at(1, 1).state == "injecting", "the injector is running")
t.ui_close(p)

t.run_seconds(45)
local damp = room_of(1, 1, "water") + room_of(2, 1, "water") + room_of(3, 1, "water")
assert(damp > 1e-5, "the room never got any of it: " .. damp)

-- ...and back to the bench.
t.move(p, "east")
t.run_ticks(5)
t.move(p, "east")
t.run_ticks(5)

-- ---------------------------------------------------------------
-- AND WHAT IS NOT WATER STAYS IN THE GLASS.
--
-- Bay enforces its `reagent_whitelist` by refusing to run at all -- one
-- unlisted reagent and the machine "pings rapidly and powers down"
-- (`:134-140`), so a badly rinsed beaker stops the machine. Here the
-- roster is a sieve on the mouth, and the claim is therefore about the
-- GAS: ethanol boils at 351.5 K and could perfectly well cross a mouth,
-- and this one will not let it.
-- ---------------------------------------------------------------
t.click(p, 4, 1, machine)
t.tick()
t.ui_act(p, "toggle", '{"field":"eject"}')
t.run_ticks(2)
assert(t.hands(p).held == "beaker.water", "the water comes back out")
-- Put it down rather than clicking the deck with it: a beaker clicked
-- on your own tile is a SWIG (content/lib/vessel.luau), which is a
-- different spec entirely.
t.drop(p)
t.run_ticks(2)

local booze = t.target_at(3, 1, "beaker.ethanol")
t.click(p, 3, 1, booze)
t.tick()
t.click(p, 4, 1, machine)
t.tick()
assert(t.hands(p).held == nil, "the ethanol goes in exactly as the water did")
local spirit = held_in(booze, "ethanol")
local ethanol_0 = pipe_of(3, 1, "ethanol")

t.run_seconds(45)
near(pipe_of(3, 1, "ethanol"), ethanol_0, 1e-9, "and none of it reaches the line")
near(held_in(booze, "ethanol"), spirit, 1e-6, "every drop still in the glass")
