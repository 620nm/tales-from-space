-- A radio carrier with no tile: alive, tuned in, and standing nowhere.
--
-- A living body shut in a cadaver drawer keeps everything it holds --
-- its Lifeline key included -- and loses its coordinates entirely
-- (cadaver_chamber_test.luau: a stowed thing has no tile at all). The
-- engine still offers that carrier as a `speech.radio` listener row,
-- and the policy's answer is the signal model's one honest sentence
-- about somebody standing nowhere: not heard (lib/radio.luau, the
-- guarded tile read). What this spec is really pinning is the failure
-- mode that MUST NOT happen: one odd carrier erroring the handler,
-- which would quarantine the registration and quietly turn every
-- radio on the station back into a station-wide megaphone. So the
-- proof is double -- the stowed carrier hears nothing, AND the policy
-- demonstrably still ran for everybody else (the far listener's
-- silence: fall-open would have delivered to them).

local function said(p, line)
    for _, m in ipairs(t.messages(p)) do
        if m == line then
            return true
        end
    end
    return false
end

-- The bay: a drawer facing east onto the aisle, its patient's spawn on
-- the tray tile, and two more listeners staked out on the corridor.
-- Distances from the speaker at (1,1): near (6,1) = 5, f = 0.714,
-- whole; far (11,1) = 10, outside LOCAL_RADIUS -- no tower here.
t.world([==[(
    name: "stowed listener",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        'G': (turf: Floor, fixture: Some(Generator)),
        'a': (turf: Floor, fixture: Some(Apc)),
        'o': (turf: Floor, fixture: Some(Outlet)),
    },
    rows: [
        "#############",
        "#...........#",
        "#Gao........#",
        "#############",
    ],
    spawns: [(1, 1), (3, 1), (6, 1), (11, 1)],
    items: [
        (1, 1, "encryption_key.medical"),
        (3, 1, "encryption_key.medical"),
        (6, 1, "encryption_key.medical"),
        (11, 1, "encryption_key.medical"),
    ],
    structures: [(2, 1, "cadaver_chamber", { "dir": "east" })],
    cables: [(1, 2, 2), (2, 2, 3), (3, 2, 1)],
)]==], 0)

local speaker = t.join()
local patient = t.join()
local l_near = t.join()
local l_far = t.join()
t.run_ticks(20)

local function pocket(p)
    local x, y = t.pos(p)
    t.click(p, x, y, t.target_at(x, y, "encryption_key.medical"))
    t.run_ticks(2)
    assert(t.hands(p).held == "encryption_key.medical", "the key is in hand")
end
pocket(speaker)
pocket(patient)
pocket(l_near)
pocket(l_far)

-- Roll the tray out under the patient, lie them on it, shut it: the
-- cadaver chamber's own contract (cadaver_chamber_test.luau). The
-- drawer answers an EMPTY hand, so the key goes down for the
-- doorman's work and comes back after.
t.drop(speaker)
t.run_ticks(2)
local drawer = t.target_at(2, 1, "cadaver_chamber")
assert(drawer ~= nil, "one targetable drawer")
t.click(speaker, 2, 1, drawer)
t.tick()
assert(t.structure_at(2, 1).state == "open", "the tray rolls out")
t.rest(patient)
t.click(speaker, 2, 1, drawer)
t.tick()
assert(t.structure_at(2, 1).state == "closed", "and rolls back in, patient aboard")
assert(t.body_id(patient) ~= nil, "the body still exists; it simply has no tile")
pocket(speaker)

-- ---------------------------------------------------------------
-- THE LINE. The near listener reads it whole, so the policy ran; the
-- far one is past the local circle, so the policy WORKED (fall-open
-- would have delivered the original station-wide); and the stowed
-- carrier, alive and tuned, heard nothing from nowhere.
-- ---------------------------------------------------------------
local _ = t.messages(speaker)
local _ = t.messages(patient)
local _ = t.messages(l_near)
local _ = t.messages(l_far)
t.say(speaker, ";sound off if you can hear me")
t.run_ticks(2)
assert(said(speaker, "sound off if you can hear me"), "the speaker hears themself")
assert(said(l_near, "sound off if you can hear me"),
    "the aisle listener reads the line whole")
assert(#t.messages(l_far) == 0,
    "the far listener is past the circle -- the policy still ran")
assert(#t.messages(patient) == 0,
    "a carrier with no tile is not heard, and costs nobody else anything")
