-- What a radio line actually reaches, in tiles.
--
-- The engine's own delivery is station-wide; this pack's `speech.radio`
-- transform (lib/radio.luau, registered on every radio-declaring item)
-- makes it a SIGNAL: LOCAL_RADIUS on its own, TRANSCEIVER_RADIUS
-- through a powered tower keyed to the channel, words dropping out
-- past CLEAR_FRACTION of either circle. Every number asserted here is
-- that file's; the garbled string is a LITERAL because the static is
-- deterministic by design -- djb2 of the line, no RNG -- so the same
-- words at the same fraction read the same on every server
-- (docs/LUAU-API.md §4 is the anchor's contract).

local function said(p, line)
    for _, m in ipairs(t.messages(p)) do
        if m == line then
            return true
        end
    end
    return false
end

-- The corridor: a tower mid-hall with its cord in reach of the second
-- outlet, a speaker at the west end, and three listeners staked out at
-- the fractions that matter. Distances (lib/radio.luau's Euclidean):
--   speaker (2,1) -> tower (10,1)  =  8    inside 10.5: uplinked
--   speaker -> every listener      >  7    outside the local circle
--   tower -> l_clear (14,1)        =  4    f = 0.38, inside 0.75: whole
--   tower -> l_rim   (20,1)        = 10    f = 0.952: garbled
--   tower -> l_out   (21,1)        = 11    f > 1: silence
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
        "########################",
        "#......................#",
        "#Gao.....o.............#",
        "########################",
    ],
    spawns: [(2, 1), (14, 1), (20, 1), (21, 1)],
    items: [
        (2, 1, "encryption_key.medical"),
        (14, 1, "encryption_key.medical"),
        (20, 1, "encryption_key.medical"),
        (21, 1, "encryption_key.medical"),
    ],
    machines: [
        (10, 1, "transceiver", { "encryption_1": "encryption_key.medical" }),
    ],
    cables: [
        (1, 2, 2), (2, 2, 3), (3, 2, 1), (4, 2, 1), (5, 2, 1),
        (6, 2, 1), (7, 2, 1), (8, 2, 1), (9, 2, 1),
    ],
)]==], 0)

local speaker = t.join()
local l_clear = t.join()
local l_rim = t.join()
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
pocket(l_out)

local function drain_all()
    local _ = t.messages(speaker)
    local _ = t.messages(l_clear)
    local _ = t.messages(l_rim)
    local _ = t.messages(l_out)
end

-- ---------------------------------------------------------------
-- 1. THROUGH THE TOWER. The clear listener reads the line whole; the
--    one at the rim reads exactly what the deterministic static
--    leaves; one tile further there is nothing at all.
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
    if m == "~~y~~~ c~~~, ~~~ ~~~ i~ ~~~ ~~ ~~~~~~" then
        rim_ok = true
    end
end
assert(rim_ok,
    "at the rim, exactly the static the hash decides: "
        .. table.concat(rim_heard, " | "))
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
assert(#t.messages(l_out) == 0, "and past it stays past it")

-- ---------------------------------------------------------------
-- 3. THE WRONG KEY IN THE TOWER. A Wrench-keyed tower carries no
--    Lifeline whatever its power is doing -- but the local circle
--    still works, because a handheld never needed the tower at all.
--    Distances: speaker (2,1) -> near (5,1) = 3, f = 0.43, whole;
--    speaker -> far (14,1) = 12, outside LOCAL_RADIUS entirely.
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
        "########################",
        "#......................#",
        "#Gao.....o.............#",
        "########################",
    ],
    spawns: [(2, 1), (5, 1), (14, 1)],
    items: [
        (2, 1, "encryption_key.medical"),
        (5, 1, "encryption_key.medical"),
        (14, 1, "encryption_key.medical"),
    ],
    machines: [
        (10, 1, "transceiver", { "encryption_1": "encryption_key.engineering" }),
    ],
    cables: [
        (1, 2, 2), (2, 2, 3), (3, 2, 1), (4, 2, 1), (5, 2, 1),
        (6, 2, 1), (7, 2, 1), (8, 2, 1), (9, 2, 1),
    ],
)]==], 0)

speaker = t.join()
local l_near = t.join()
local l_far = t.join()
t.run_ticks(20)
pocket(speaker)
pocket(l_near)
pocket(l_far)

local _ = t.messages(speaker)
local _ = t.messages(l_near)
local _ = t.messages(l_far)
t.say(speaker, ";lifeline check")
t.run_ticks(2)
assert(said(l_near, "lifeline check"),
    "inside the local circle a handheld needs no tower")
assert(#t.messages(l_far) == 0,
    "past it, a tower keyed to another word carries nothing")
