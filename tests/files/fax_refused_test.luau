local bench = require("@helpers/fax_bench")
local clock = require("@helpers/clock")

-- Two faxes each scan a sheet toward the other in the same tick. Each is busy
-- scanning when the other's page arrives, so each recipient refuses: neither
-- prints, both sheets still eject when their scans end, and each sender hears
-- the refusal, not a success.
bench.world([[(3, 2, "paper"), (13, 2, "paper")]])

local assistant = t.join("assistant")
local medic = t.join("medic")
t.run_seconds(0.5)

bench.advertise(medic, 12, 2, "Medical Fax")
bench.advertise(assistant, 4, 2, "Assistant Fax")
bench.load_sheet(assistant, 4, 2, 3, 2)
bench.load_sheet(medic, 12, 2, 13, 2)
bench.select(assistant, "Medical Fax")
bench.select(medic, "Assistant Fax")

bench.confirm(assistant)
bench.confirm(medic)
t.run_ticks(2)
assert(bench.data(assistant, "fax").busy == true, "the assistant's fax scans")
assert(bench.data(medic, "fax").busy == true, "the medic's fax scans")
assert(#t.items_at(4, 2) == 0 and #t.items_at(12, 2) == 0, "both sheets are held")

t.run_ticks(clock.deadline_ticks(2.0) - 3)
assert(#t.items_at(4, 2) == 0 and #t.items_at(12, 2) == 0, "both stay held until the deadline")
t.run_ticks(1)
assert(#t.items_at(4, 2) == 1, "the assistant's sheet ejects at the deadline")
assert(#t.items_at(12, 2) == 1, "the medic's sheet ejects at the deadline")

t.run_ticks(clock.deadline_ticks(0.5))
for _, player in ipairs({ assistant, medic }) do
    assert(bench.heard(player, "The fax could not be sent."), "each sender hears the refusal")
    assert(not bench.heard(player, "The fax is sent."), "and hears no success")
end
assert(#t.items_at(4, 2) == 1 and #t.items_at(12, 2) == 1, "nothing was printed")

t.click(assistant, 4, 2, assert(t.target_at(assistant, 4, 2, "fax")))
t.run_ticks(2)
local data = bench.data(assistant, "fax")
assert(data.paper == 30 and data.toner == 30 and data.busy ~= true, "nothing was spent")
bench.assert_no_script_errors("refused fax")
