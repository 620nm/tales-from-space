local helper = {}

function helper.assert_checks(actor: number, x: number, y: number): ()
    if t.hands(actor).held ~= nil then
        t.drop(actor)
        t.tick()
    end
    local probe = assert(t.target_at(actor, x, y, "bio_protection_probe"), "the protection probe is there")
    t.click(actor, x, y, probe)
    t.run_ticks(2)
    assert(t.hands(actor).held == "bio_protection_probe", "the actor holds the protection probe")
    t.use_self(actor)
    t.run_ticks(2)

    local messages = table.concat(t.messages(actor), "\n")
    assert(
        string.find(messages, "Airborne protection gates pass their deterministic checks.", 1, true) ~= nil,
        "the fixture reports completed deterministic protection checks"
    )
end

return helper
