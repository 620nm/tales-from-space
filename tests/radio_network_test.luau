-- Two towers are worth more joined than standing side by side.
--
-- Reach is per TREE (lib/radio.luau): every tower on one device
-- network stretches every other, radius_for(n) = 10.5 * 1.2^(n-1), so
-- two joined towers reach 12.6 where either alone reaches 10.5. The
-- join is ordinary panel work on the access point (docs/DEVICES.md;
-- network_test.luau owns the panel's own contract), which makes radio
-- coverage something a crew BUILDS -- and cuts.
--
-- The listener stands at 12 tiles from the near tower: outside every
-- lone circle, inside the pair's. The garbled literal is deterministic
-- (radio_coverage_test.luau explains the hash).

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

-- The bench: an access point on the north wall, two Lifeline towers
-- under it on live cord, a speaker beside them and a listener staked
-- out at the exact distance that tells the two radii apart.
-- Distances (Euclidean, lib/radio.luau):
--   speaker (6,2) -> T1 (5,2)  =  1     always uplinked
--   T1 (5,2) -> listener (17,2) = 12    10.5 < 12 <= 12.6
--   T2 (4,2) -> listener        = 13    outside even the pair's reach
--   speaker -> listener         = 11    outside LOCAL_RADIUS
t.world([==[(
    name: "tower chain",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        'G': (turf: Floor, fixture: Some(Generator)),
        'a': (turf: Floor, fixture: Some(Apc)),
        'o': (turf: Floor, fixture: Some(Outlet)),
    },
    rows: [
        "####################",
        "#..................#",
        "#Gao...............#",
        "####################",
    ],
    spawns: [(6, 2), (17, 2)],
    items: [
        (6, 2, "encryption_key.medical"),
        (17, 2, "encryption_key.medical"),
    ],
    machines: [
        (4, 2, "transceiver.medical"),
        (5, 2, "transceiver.medical"),
    ],
    structures: [(4, 1, "access_point")],
    mounts: [(4, 1, North)],
    cables: [(1, 2, 2), (2, 2, 3), (3, 2, 1)],
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

-- ---------------------------------------------------------------
-- 1. SIDE BY SIDE IS NOT A NETWORK. Each tower is a tree of one,
--    reach 10.5, and the listener stands at 12.
-- ---------------------------------------------------------------
local _ = t.messages(speaker)
local _ = t.messages(listener)
t.say(speaker, ";the tower chain is up, check your bands")
t.run_ticks(2)
assert(said(speaker, "the tower chain is up, check your bands"),
    "the speaker hears themself")
assert(#t.messages(listener) == 0,
    "two lone towers reach 10.5 tiles, and the listener stands at 12")

-- ---------------------------------------------------------------
-- 2. THE JOIN. The access point's panel offers both unjoined towers
--    (their cards lend them addresses, docs/DEVICES.md §5a); joining
--    both puts two towers on one tree.
-- ---------------------------------------------------------------
-- Step to the wall box: (6,2) -> (6,1) -> (5,1).
for _, dir in ipairs({ "north", "west" }) do
    t.move(speaker, dir)
    t.run_ticks(6)
end
local sx, sy = t.pos(speaker)
assert(sx == 5 and sy == 1, "standing at the access point: " .. sx .. "," .. sy)

t.click(speaker, 4, 1, t.target_at(4, 1, "access_point"))
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

-- Back to the speaking spot, so the geometry above still holds.
for _, dir in ipairs({ "east", "south" }) do
    t.move(speaker, dir)
    t.run_ticks(6)
end
sx, sy = t.pos(speaker)
assert(sx == 6 and sy == 2, "back on the mark: " .. sx .. "," .. sy)

-- ---------------------------------------------------------------
-- 3. ONE TREE, LONGER ARMS. n = 2 towers on the tree, reach 12.6,
--    listener at 12: heard, garbled -- f = 12/12.6 is past the clear
--    band, and the static is the deterministic literal.
-- ---------------------------------------------------------------
local _ = t.messages(speaker)
local _ = t.messages(listener)
t.say(speaker, ";the tower chain is up, check your bands")
t.run_ticks(2)
local heard = t.messages(listener)
local rim_ok = false
for _, m in ipairs(heard) do
    if m == "~~e ~~~e~ ~h~~~ i~ ~p, ~~e~~ ~o~~ b~~~~" then
        rim_ok = true
    end
end
assert(rim_ok, "joined, the pair reaches the listener: " .. table.concat(heard, " | "))

-- ---------------------------------------------------------------
-- 4. AND CUT. Releasing either tower leaves a tree of one; reach
--    falls back to 10.5 and the listener is outside it again.
-- ---------------------------------------------------------------
for _, dir in ipairs({ "north", "west" }) do
    t.move(speaker, dir)
    t.run_ticks(6)
end
t.click(speaker, 4, 1, t.target_at(4, 1, "access_point"))
t.tick()
local held = rows(t.ui(speaker), "link_drop")
assert(#held == 2, "the panel holds both towers")
t.ui_act(speaker, "toggle", string.format('{"field":"link_drop","option":"%s"}', held[1].option))
t.tick()
assert(#t.ledger_rows("link_released") == 1, "the cut is on the record")
t.ui_close(speaker)
t.tick()
for _, dir in ipairs({ "east", "south" }) do
    t.move(speaker, dir)
    t.run_ticks(6)
end

local _ = t.messages(speaker)
local _ = t.messages(listener)
t.say(speaker, ";still with me on the long band")
t.run_ticks(2)
assert(said(speaker, "still with me on the long band"), "the speaker hears themself")
assert(#t.messages(listener) == 0, "released, the reach falls back and the rim goes quiet")
