-- A server started without `--playtest` installs no map: the pack answers
-- `round.bootstrap` by instantiating the host's map and begins the round on
-- it (content/lib/map_boot.luau). `t.bootstrap_world` boots that way, so a
-- body that stands in the host map's room proves the whole chain ran:
-- bootstrap, the install settling Ready, and the begin.
t.bootstrap_world({ host_map = "cold_outpost.ron", mode = "free_build", seed = 7 })

local installs = t.ledger_rows("map_instance_installing")
assert(#installs == 1, "the host map installs once, got " .. #installs)
assert(#t.ledger_rows("lunatic/tfs:map_boot_failed") == 0, "no boot refusal is ledgered")

-- Free Build seats a body on connection, at the map's marker, in the
-- engineer's kit its mode issues (rounds/free_build_test.luau).
local builder = t.join()
t.tick()
local worn = t.worn(builder)
assert(
    worn.uniform == "uniform_eng",
    "the round began on the host map, got " .. tostring(worn.uniform)
)
