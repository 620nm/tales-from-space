-- Two towers are worth more joined than standing side by side -- and
-- the HARDWARE is the amplifier.
--
-- Reach is per TREE (lib/radio.luau): every POWERED tower on one
-- device network stretches every other, radius_for(n) = 10.5 *
-- 1.2^(n-1), keys notwithstanding -- a blank-keyed tower still buffs
-- the tree, an unpowered one contributes nothing, and keys decide only
-- which channels a tower carries. The join is ordinary panel work on
-- the access point (docs/DEVICES.md; network_test.luau owns the
-- panel's own contract), which makes radio coverage something a crew
-- BUILDS, cuts, and sabotages at the breaker.
--
-- The listener stands 12 tiles from the keyed tower: outside every
-- lone 10.5 circle, inside the pair's 12.6. The garbled literal is
-- deterministic (radio_coverage_test.luau explains the hash, and why a
-- literal pins change rather than correctness).

local function said(p, line)
    for _, m in ipairs(t.messages(p)) do
        if m == line then
            return true
        end
    end
    return false
end

local function rows(ui, field)
    local out = {}
    for _, row in ipairs(ui.toggles or {}) do
        if row.field == field then
            out[#out + 1] = row
        end
    end
    return out
end

-- The bench: an access point on the north wall, a Lifeline tower and a
-- BLANK one under it, a speaker beside them and a listener staked out
-- at the exact distance that tells the two radii apart. The deck is
-- bare plating so the blank tower's own cable spur can be snipped.
-- Distances (Euclidean, lib/radio.luau):
--   speaker (6,2) -> keyed T (5,2)   =  1     always uplinked
--   keyed T (5,2) -> listener (17,2) = 12     10.5 < 12 <= 12.6
--   blank T (10,2) -> listener       =  7     but blank: never a gate
--   speaker -> listener              = 11     outside LOCAL_RADIUS
-- Power: the keyed tower cords to the outlet at (3,2); the blank one
-- is seven tiles from it -- past cord range -- and hangs off its own
-- outlet at (9,2), fed through the l1 run, so one snip at (7,2) kills
-- the blank tower and nothing else.
t.world([==[(
    name: "tower chain",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Plating),
        '#': (turf: Wall),
        'G': (turf: Plating, fixture: Some(Generator)),
        'a': (turf: Plating, fixture: Some(Apc)),
        'o': (turf: Plating, fixture: Some(Outlet)),
    },
    rows: [
        "####################",
        "#..................#",
        "#Gao.....o.........#",
        "####################",
    ],
    spawns: [(6, 2), (17, 2)],
    items: [
        (6, 2, "encryption_key.medical"),
        (6, 2, "wirecutters"),
        (17, 2, "encryption_key.medical"),
    ],
    machines: [
        (5, 2, "transceiver.medical"),
        (10, 2, "transceiver"),
    ],
    structures: [(8, 1, "access_point")],
    mounts: [(8, 1, North)],
    cables: [
        (1, 2, 2), (2, 2, 3), (3, 2, 1), (4, 2, 1), (5, 2, 1),
        (6, 2, 1), (7, 2, 1), (8, 2, 1), (9, 2, 1),
    ],
)]==], 0)

local speaker = t.join()
local listener = t.join()
t.run_ticks(20)

local function pocket(p)
    local x, y = t.pos(p)
    t.click(p, x, y, t.target_at(x, y, "encryption_key.medical"))
    t.run_ticks(2)
    assert(t.hands(p).held == "encryption_key.medical", "the key is in hand")
end
pocket(speaker)
pocket(listener)

-- The two marks the speaker shuttles between: the speaking spot at
-- (6,2), and (7,1) beside the access point.
local function to_panel()
    for _, dir in ipairs({ "north", "east" }) do
        t.move(speaker, dir)
        t.run_ticks(6)
    end
    local x, y = t.pos(speaker)
    assert(x == 7 and y == 1, "standing at the access point: " .. x .. "," .. y)
end
local function to_mark()
    for _, dir in ipairs({ "west", "south" }) do
        t.move(speaker, dir)
        t.run_ticks(6)
    end
    local x, y = t.pos(speaker)
    assert(x == 6 and y == 2, "back on the mark: " .. x .. "," .. y)
end

local function say_and_read(line)
    local _ = t.messages(speaker)
    local _ = t.messages(listener)
    t.say(speaker, ";" .. line)
    t.run_ticks(2)
    assert(said(speaker, line), "the speaker hears themself")
    return t.messages(listener)
end

-- ---------------------------------------------------------------
-- 1. SIDE BY SIDE IS NOT A NETWORK. Each tower is a tree of one,
--    reach 10.5, and the listener stands at 12.
-- ---------------------------------------------------------------
assert(#say_and_read("the tower chain is up, check your bands") == 0,
    "two lone towers reach 10.5 tiles, and the listener stands at 12")

-- ---------------------------------------------------------------
-- 2. THE JOIN. The access point's panel offers both unjoined towers
--    (their cards lend them addresses, docs/DEVICES.md §5a); joining
--    both puts two POWERED towers on one tree, blank one included.
-- ---------------------------------------------------------------
to_panel()
t.click(speaker, 8, 1, t.target_at(8, 1, "access_point"))
t.tick()
local panel = t.ui(speaker)
assert(panel ~= nil, "the access point wears its panel")
-- Placed with no `access` word: a lock with no key opens for whoever
-- is standing at it (network_test.luau, the router's case).
t.ui_act(speaker, "toggle", '{"field":"link_lock"}')
t.tick()
panel = t.ui(speaker)
assert(rows(panel, "link_lock")[1].on, "it opens for whoever is standing at it")
local offered = rows(panel, "link_join")
assert(#offered == 2, "both towers are on offer: " .. #offered)
for _ = 1, 2 do
    local offer = rows(t.ui(speaker), "link_join")[1]
    t.ui_act(speaker, "toggle", string.format('{"field":"link_join","option":"%s"}', offer.option))
    t.tick()
end
assert(#t.ledger_rows("link_accepted") == 2, "two joins on the record")
t.ui_close(speaker)
t.tick()
to_mark()

-- The tower's own sentence now reports the relay: joined under the
-- access point and carrying traffic, so the status line grows its
-- network clause (lib/radio.luau's status_line; the empty hand is the
-- fixture's gate, so the key goes down for a moment).
t.drop(speaker)
t.run_ticks(2)
local _ = t.messages(speaker)
t.click(speaker, 5, 2, t.target_at(5, 2))
t.tick()
assert(
    said(speaker, "The transceiver is on the air, carrying Lifeline, relayed through its network."),
    "a joined tower says it is relayed, got: " .. table.concat(t.messages(speaker), " | ")
)
t.ui_close(speaker)
t.tick()
pocket(speaker)

-- ---------------------------------------------------------------
-- 3. ONE TREE, LONGER ARMS -- OFF A BLANK AMPLIFIER. n counts POWERED
--    towers, so the keyless one stretches the keyed one to 12.6, and
--    the listener at 12 hears the deterministic static of f = 12/12.6.
-- ---------------------------------------------------------------
local heard = say_and_read("the tower chain is up, check your bands")
local rim_ok = false
for _, m in ipairs(heard) do
    if m == "~~e ~~~e~ ~h~~~ i~ ~p, ~~e~~ ~o~~ b~~~~" then
        rim_ok = true
    end
end
assert(rim_ok, "a blank tower on the tree still amplifies: " .. table.concat(heard, " | "))

-- ---------------------------------------------------------------
-- 4. RELEASE ONE TOWER and the arms shorten: membership is what
--    counts, and a cut edge is a deliberate panel act on the record.
--    Whichever row goes, a tree of one tower reaches nobody at 12.
-- ---------------------------------------------------------------
to_panel()
t.click(speaker, 8, 1, t.target_at(8, 1, "access_point"))
t.tick()
local held = rows(t.ui(speaker), "link_drop")
assert(#held == 2, "the panel holds both towers")
t.ui_act(speaker, "toggle", string.format('{"field":"link_drop","option":"%s"}', held[2].option))
t.tick()
assert(#t.ledger_rows("link_released") == 1, "the cut is on the record")
t.ui_close(speaker)
t.tick()
to_mark()

assert(#say_and_read("still with me on the long band") == 0,
    "released, the reach falls back and the rim goes quiet")

-- Rejoin whichever tower came off, so the pair is whole again.
to_panel()
t.click(speaker, 8, 1, t.target_at(8, 1, "access_point"))
t.tick()
local offer = rows(t.ui(speaker), "link_join")[1]
assert(offer ~= nil, "the released tower is offerable again")
t.ui_act(speaker, "toggle", string.format('{"field":"link_join","option":"%s"}', offer.option))
t.tick()
t.ui_close(speaker)
t.tick()
to_mark()
assert(#say_and_read("the tower chain is up, check your bands") == 1,
    "rejoined, the pair reaches the rim again")

-- ---------------------------------------------------------------
-- 5. UNPOWER THE BLANK TOWER and the arms shorten the same way: a
--    dead amplifier is no amplifier, though the tree still holds it.
--    One snip on its own cable spur -- the keyed tower cords to the
--    other outlet and stays up.
-- ---------------------------------------------------------------
t.swap_hands(speaker)
t.tick()
t.click(speaker, 6, 2, t.target_at(6, 2, "wirecutters"))
t.run_ticks(2)
assert(t.hands(speaker).held == "wirecutters", "the cutters are in hand")
t.click_subfloor(speaker, 7, 2, "cable", 1)
t.run_seconds(1.5)
assert(t.cable_at(7, 2) == 0, "the spur is parted")
assert(t.ledger_has("CableCut"), "sabotage is attributable")
t.run_ticks(60)

assert(#say_and_read("say again, the band went short") == 0,
    "an unpowered tower amplifies nothing, and the reach falls back to 10.5")
