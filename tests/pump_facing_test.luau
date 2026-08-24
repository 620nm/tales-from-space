-- A wrenched pump keeps the SIGN of its facing -- and shows it.
--
-- The report was "it will not wrench in facing west or south", and the
-- sim was never guilty: the chosen facing survived the wrench on all
-- four cardinals (the second half of pump_socket_test.luau). What lied
-- was the PICTURE. The bake had folded every binary machine onto tg's
-- PIPING_CARDINAL_AUTONORMALIZE rule, and that rule belongs to the
-- valves and adapters alone (valve.dm:14): a pump has a front, tg's
-- .dmi carries four genuinely different frames for it, and a
-- west-facing pump wearing the east frame reads as a machine that
-- refused to turn.
--
-- So this spec pins both halves at once, for every cardinal: the pump
-- MOVES the right way (input drained, output fed -- the fact) and
-- WEARS the right frame (the picture). Both side nets are one length
-- of commissioned pipe plus the pump's own mouth, so the settled
-- numbers are exact: the input net ends empty and the output net holds
-- both charges over pipe-plus-mouth.

local function build(rotations, want_sprite, drained, fed)
    t.world([==[(
        name: "pump sign",
        legend: { '.': (turf: Plating), '#': (turf: Wall) },
        rows: [
            "#####",
            "#...#",
            "#...#",
            "#...#",
            "#####",
        ],
        spawns: [(1, 1)],
        pipes: [(1, 2, 4), (3, 2, 4), (2, 1, 4), (2, 3, 4)],
        items: [(1, 1, "wrench"), (2, 2, "volume_pump_fitting")],
    )]==], 7)
    local q = t.join()
    t.tick()
    local fitting = t.target_at(2, 2, "volume_pump_fitting")
    for _ = 1, rotations do
        t.rotate(q, 2, 2, fitting, true)
    end
    t.click(q, 1, 1, t.target_at(1, 1, "wrench"))
    t.run_ticks(2)
    t.click(q, 2, 2, fitting)
    t.run_seconds(2.5)
    local raised = t.structure_at(2, 2)
    assert(raised ~= nil and raised.id == "volume_pump", "fastened")
    assert(raised.sprite == want_sprite,
        rotations .. " turns: " .. tostring(raised.sprite) .. " is not " .. want_sprite)
    -- An empty hand on the panel; the wrench would unbolt it.
    t.swap_hands(q)
    t.click(q, 2, 2, t.target_at(2, 2, "volume_pump"))
    t.tick()
    t.ui_act(q, "toggle", '{"field":"power"}')
    t.run_seconds(20)
    assert(t.pipe_pressure(drained[1], drained[2]) < 1.0,
        want_sprite .. ": the input net should have emptied")
    assert(t.pipe_pressure(fed[1], fed[2]) > 40.0,
        want_sprite .. ": the output net should hold the gas")
end

-- Alt+left from rest walks south -> west -> north -> east.
build(1, "volpump_off_w", { 3, 2 }, { 1, 2 })
build(2, "volpump_off_n", { 2, 3 }, { 2, 1 })
build(3, "volpump_off_e", { 1, 2 }, { 3, 2 })
build(4, "volpump_off_s", { 2, 1 }, { 2, 3 })
