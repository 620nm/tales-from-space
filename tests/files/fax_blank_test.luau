local bench = require("@helpers/fax_bench")
local clock = require("@helpers/clock")

-- A sheet nobody wrote on faxes like any other: it scans for the fax time,
-- ejects onto the sender's tile, and the recipient prints one blank sheet
-- and charges its own paper and toner for it.
bench.world([[(3, 2, "paper")]])

local sender = t.join("assistant")
local receiver = t.join("medic")
t.run_seconds(0.5)

bench.advertise(receiver, 12, 2, "Medical Fax")
bench.load_sheet(sender, 4, 2, 3, 2)
bench.send(sender, "Medical Fax")
t.run_ticks(2)
assert(bench.data(sender, "fax").busy == true, "the blank scan holds the sender busy")
assert(#t.items_at(4, 2) == 0, "the blank sheet is held during the scan")

t.run_ticks(clock.deadline_ticks(2.0) - 3)
assert(#t.items_at(4, 2) == 0, "the blank sheet stays held until the 2 s deadline")
assert(#t.items_at(12, 2) == 0, "nothing prints before the deadline")
t.run_ticks(1)
assert(t.items_at(4, 2)[1] == "paper", "the blank sheet ejects at the deadline")
assert(t.items_at(12, 2)[1] == "paper", "one blank sheet arrives at the recipient")

-- The recipient's page result is the sender's verdict.
t.run_ticks(clock.deadline_ticks(0.5))
assert(bench.heard(sender, "The fax is sent."), "the sender hears the page landed")
assert(not bench.heard(sender, "could not be sent"), "and hears no failure")
local sender_data = bench.data(sender, "fax")
assert(sender_data.busy ~= true, "the sender is idle again")

t.click(receiver, 12, 2, assert(t.target_at(receiver, 12, 2, "fax")))
t.run_ticks(2)
local receiver_data = bench.data(receiver, "fax")
assert(
    receiver_data.paper == 29 and receiver_data.toner == 29,
    "the recipient charged one paper and toner for the blank page"
)
assert(receiver_data.busy ~= true, "the recipient is idle again")
bench.assert_no_script_errors("blank fax")
