-- What a radio line actually reaches, in tiles.
--
-- The engine's own delivery is station-wide; this pack's `speech.radio`
-- transform (lib/radio.luau, registered on every radio-declaring item)
-- makes it a SIGNAL: LOCAL_RADIUS on its own, TRANSCEIVER_RADIUS
-- through a powered tower keyed to the channel, words dropping out
-- past CLEAR_FRACTION of either circle. Every number asserted here is
-- that file's. The garbled strings are LITERALS: the static is
-- deterministic by design (djb2 of the line, no RNG), so the same
-- words at the same fraction read the same on every server. A literal
-- pins CHANGE, not correctness -- edit the hash and these strings
-- move, and re-deriving them from the new hash is the intended fix
-- (docs/LUAU-API.md §4 is the anchor's contract).

-- The clear boundary falls at 7.5 and 22.5 tiles. The local case stakes
-- its adjacent integer tiles; both exact f == 1 rims are staked below.

local function said(p, line)
    for _, m in ipairs(t.messages(p)) do
        if m == line then
            return true
        end
    end
    return false
end

-- The corridor: a tower beside its powered outlet, a speaker beside
-- it, and four listeners staked out at
-- the fractions that matter. Distances (lib/radio.luau's Euclidean):
--   speaker (1,1) -> tower (2,1)   =  1    uplinked
--   speaker -> every listener      > 10    outside the local circle
--   tower -> l_clear (24,1)        = 22    f < 0.75: whole
--   tower -> l_rim   (31,1)        = 29    f > 0.75: garbled
--   tower -> l_edge  (32,1)        = 30    f = 1: heard
--   tower -> l_out   (33,1)        = 31    f > 1: silence
t.world([==[(
    name: "radio corridor",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        'G': (turf: Floor, fixture: Some(Generator)),
        'a': (turf: Floor, fixture: Some(Apc)),
        'o': (turf: Floor, fixture: Some(Outlet)),
    },
    rows: [
        "###################################",
        "#.................................#",
        "#Gao..............................#",
        "###################################",
    ],
    spawns: [(1, 1), (24, 1), (31, 1), (32, 1), (33, 1)],
    items: [
        (1, 1, "encryption_key.medical"),
        (24, 1, "encryption_key.medical"),
        (31, 1, "encryption_key.medical"),
        (32, 1, "encryption_key.medical"),
        (33, 1, "encryption_key.medical"),
    ],
    machines: [
        (2, 1, "transceiver", { "encryption_1": "encryption_key.medical" }),
    ],
    cables: [
        (1, 2, 2), (2, 2, 3), (3, 2, 1),
    ],
)]==], 0)

local speaker = t.join()
local l_clear = t.join()
local l_rim = t.join()
local l_edge = t.join()
local l_out = t.join()
t.run_ticks(20)

-- Everyone pockets the key at their feet: a carried key IS a Lifeline
-- radio, transmit and receive both (items/encryption_key.luau).
local function pocket(p)
    local x, y = t.pos(p)
    t.click(p, x, y, t.target_at(x, y, "encryption_key.medical"))
    t.run_ticks(2)
    assert(t.hands(p).held == "encryption_key.medical", "the key is in hand")
end
pocket(speaker)
pocket(l_clear)
pocket(l_rim)
pocket(l_edge)
pocket(l_out)

local function drain_all()
    local _ = t.messages(speaker)
    local _ = t.messages(l_clear)
    local _ = t.messages(l_rim)
    local _ = t.messages(l_edge)
    local _ = t.messages(l_out)
end

-- ---------------------------------------------------------------
-- 1. THROUGH THE TOWER. The clear listener reads the line whole; the
--    one near the rim reads exactly what the deterministic static
--    leaves; the exact rim is heard, and one tile further is silent.
-- ---------------------------------------------------------------
drain_all()
t.say(speaker, ";anyone copy, the lab is out of iodine")
t.run_ticks(2)
assert(said(speaker, "anyone copy, the lab is out of iodine"),
    "the speaker's own copy is always clean")
assert(said(l_clear, "anyone copy, the lab is out of iodine"),
    "inside the clear band the words arrive whole")
local rim_heard = t.messages(l_rim)
local rim_ok = false
for _, m in ipairs(rim_heard) do
    if m == "~~y~~~ c~~~, ~~~ ~~~ ~~ ~~~ ~~ ~~~~~~" then
        rim_ok = true
    end
end
assert(rim_ok,
    "near the rim, exactly the static the hash decides: "
        .. table.concat(rim_heard, " | "))
local edge_heard = t.messages(l_edge)
local edge_ok = false
for _, m in ipairs(edge_heard) do
    if m == "~~~~~~ ~~~~~ ~~~ ~~~ ~~ ~~~ ~~ ~~~~~~" then
        edge_ok = true
    end
end
assert(edge_ok, "f == 1 exactly is heard at the tower rim: "
    .. table.concat(edge_heard, " | "))
assert(#t.messages(l_out) == 0,
    "one tile past the circle there is nothing at all")

-- ---------------------------------------------------------------
-- 2. THE BREAKER TRIPS. A dead tower is no tower
--    (sim.is_powered gates the roster), and nobody here stands inside
--    LOCAL_RADIUS of the speaker.
-- ---------------------------------------------------------------
t.outage()
t.run_ticks(60)
drain_all()
t.say(speaker, ";say again, say again")
t.run_ticks(2)
assert(said(speaker, "say again, say again"), "the speaker still hears themself")
assert(#t.messages(l_clear) == 0, "the clear listener lost the tower with the power")
assert(#t.messages(l_rim) == 0, "so did the rim")
assert(#t.messages(l_edge) == 0, "the exact edge lost the tower too")
assert(#t.messages(l_out) == 0, "and past it stays past it")

-- ---------------------------------------------------------------
-- 3. THE WRONG KEY IN THE TOWER. A Wrench-keyed tower carries no
--    Lifeline whatever its power is doing -- but the local circle
--    still works, because a handheld never needed the tower at all.
--    Distances: speaker (1,1) -> near (8,1) = 7, f = 0.7, whole;
--    -> (9,1) = 8, f = 0.8, the outer-quarter static;
--    -> (11,1) = 10, f = 1 EXACTLY, heard as pure tildes (<= is the
--    contract: the rim itself is inside);
--    -> far (12,1) = 11, outside LOCAL_RADIUS entirely.
-- ---------------------------------------------------------------
t.world([==[(
    name: "wrong key",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        'G': (turf: Floor, fixture: Some(Generator)),
        'a': (turf: Floor, fixture: Some(Apc)),
        'o': (turf: Floor, fixture: Some(Outlet)),
    },
    rows: [
        "##############",
        "#............#",
        "#Gao.........#",
        "##############",
    ],
    spawns: [(1, 1), (8, 1), (9, 1), (11, 1), (12, 1)],
    items: [
        (1, 1, "encryption_key.medical"),
        (8, 1, "encryption_key.medical"),
        (9, 1, "encryption_key.medical"),
        (11, 1, "encryption_key.medical"),
        (12, 1, "encryption_key.medical"),
    ],
    machines: [
        (2, 1, "transceiver", { "encryption_1": "encryption_key.engineering" }),
    ],
    cables: [
        (1, 2, 2), (2, 2, 3), (3, 2, 1),
    ],
)]==], 0)

speaker = t.join()
local l_near = t.join()
local l_quarter = t.join()
local l_edge = t.join()
local l_far = t.join()
t.run_ticks(20)
pocket(speaker)
pocket(l_near)
pocket(l_quarter)
pocket(l_edge)
pocket(l_far)

local _ = t.messages(speaker)
local _ = t.messages(l_near)
local _ = t.messages(l_quarter)
local _ = t.messages(l_edge)
local _ = t.messages(l_far)
t.say(speaker, ";local radius boundary check")
t.run_ticks(2)
assert(said(l_near, "local radius boundary check"),
    "inside the local circle a handheld needs no tower")
local quarter_heard = t.messages(l_quarter)
assert(quarter_heard[1] == "loc~l r~~ius ~oun~ary check",
    "the outer quarter of the local circle garbles too: "
        .. table.concat(quarter_heard, " | "))
local local_edge_heard = t.messages(l_edge)
assert(local_edge_heard[1] == "~~~~~ ~~~~~~ ~~~~~~~~ ~~~~~",
    "f == 1 exactly is HEARD -- the rim is inside -- as pure static: "
        .. table.concat(local_edge_heard, " | "))
assert(#t.messages(l_far) == 0,
    "past it, a tower keyed to another word carries nothing")

-- ---------------------------------------------------------------
-- 4. THE COMMON HEADSET. It registers its own `speech.radio` handler,
--    separate from the loose department keys used above. With no tower,
--    a listener at 10 tiles hears the exact rim and one at 11 does not.
-- ---------------------------------------------------------------
t.world([==[(
    name: "headset boundary",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
    },
    rows: [
        "##############",
        "#............#",
        "#............#",
        "##############",
    ],
    spawns: [(1, 1), (11, 1), (12, 1)],
    items: [
        (1, 1, "headset"),
        (11, 1, "headset"),
        (12, 1, "headset"),
    ],
)]==], 0)

speaker = t.join()
local headset_edge = t.join()
local headset_out = t.join()
t.run_ticks(20)

local function take_headset(p)
    local x, y = t.pos(p)
    t.click(p, x, y, t.target_at(x, y, "headset"))
    t.run_ticks(2)
    assert(t.hands(p).held == "headset", "the Common headset is in hand")
end
take_headset(speaker)
take_headset(headset_edge)
take_headset(headset_out)

local _ = t.messages(speaker)
local _ = t.messages(headset_edge)
local _ = t.messages(headset_out)
t.say(speaker, ";headset boundary")
t.run_ticks(2)
assert(said(speaker, "headset boundary"), "the headset speaker hears themself")
local headset_edge_heard = t.messages(headset_edge)
assert(headset_edge_heard[1] == "~~~~~~~ ~~~~~~~~",
    "the Common headset reaches its exact ten-tile rim: "
        .. table.concat(headset_edge_heard, " | "))
assert(#t.messages(headset_out) == 0,
    "the Common headset reaches no listener eleven tiles away")
