-- The default mode (Space Station) answers `round.bootstrap` too. A prepared
-- mode begins into its setup countdown (`preparation_opened`), and
-- `t.bootstrap_world` settles once `sim.round.begin` has opened preparation
-- (content/lib/map_boot.luau, rounds/preparation_test.luau).
t.bootstrap_world({
    host_map = "cold_outpost.ron",
    mode = "space_station",
    seed = 7,
})

assert(#t.ledger_rows("map_instance_installing") == 1, "the host map installs once")
assert(#t.ledger_rows("preparation_opened") == 1, "the begin opens the setup countdown")
assert(#t.ledger_rows("lunatic/tfs:map_boot_failed") == 0, "no boot refusal is ledgered")
