-- End-to-end fax coverage through the player, UI, and native network seams.
-- Two access-point branches share one router; the third branch has its own
-- root and must stay out of the directory.
local function control(player, channel, suffix)
    local address = assert(t.ui_document(player, channel), "document address is available")
    return "doc/" .. address.document .. "/" .. address.generation .. suffix
end

local function data(player, channel)
    local panel = assert(t.ui(player, channel), "a document panel is open")
    return panel.script and panel.script.data or panel.data
end

local function assert_no_script_errors(label)
    local errors = t.ledger_rows("script_error")
    local first = errors[1]
    assert(#errors == 0, label .. ": " .. tostring(first and (first.why or first.file) or "unknown script error"))
end

local function advertise(player, x, y, name)
    local fax = assert(t.target_at(player, x, y, "fax"), "fax is present")
    t.click(player, x, y, fax)
    t.run_ticks(2)
    assert(t.ui(player, "fax"), "fax panel opened")
    t.ui_edit(player, control(player, "fax", "/controls/name"), name)
    t.ui_press(player, control(player, "fax", "/controls/name/set"))
    t.run_ticks(2)
    t.ui_press(player, control(player, "fax", "/controls/advertise"))
    t.run_ticks(3)
    local state = data(player, "fax")
    assert(state.name == name, "advertisement commits its requested name")
    assert(state.advertised == true, "advertisement commits enabled state")
    assert(state.powered == true, "advertised fax is powered")
    assert(type(state.address) == "string" and #state.address > 0, "advertised fax has a native address")
    assert(type(state.network) == "string" and #state.network > 0, "advertised fax has a connected network")
    assert_no_script_errors("advertisement")
    return fax
end

t.world([==[ (
    name: "fax network",
    legend: {
        '.': (turf: Floor), '#': (turf: Wall),
        'G': (turf: Floor, fixture: Some(Generator)),
        'a': (turf: Floor, fixture: Some(Apc)),
        'o': (turf: Floor, fixture: Some(Outlet)),
    },
    rows: [
        "#######################",
        "#Gao.......o.....o....#",
        "#.....................#",
        "#.....................#",
        "#######################",
    ],
    structures: [
        (3, 2, "player_spawn", { "jobs": "assistant" }),
        (13, 2, "player_spawn", { "jobs": "medic" }),
        (19, 2, "player_spawn", { "jobs": "engineer" }),
        (5, 1, "access_point", { "network_1": "network_card", "mount": "north" }),
        (10, 1, "access_point", { "network_1": "network_card", "mount": "north" }),
        (16, 1, "access_point", { "network_1": "network_card", "mount": "north" }),
    ],
    machines: [
        (4, 1, "network_router", { "network_1": "network_card" }),
        (15, 1, "network_router", { "network_1": "network_card" }),
        (4, 2, "fax", { "network_1": "network_card" }),
        (12, 2, "fax", { "network_1": "network_card" }),
        (18, 2, "fax", { "network_1": "network_card" }),
    ],
    links: [
        (4, 1, 5, 1), (4, 1, 10, 1),
        (5, 1, 4, 2), (10, 1, 12, 2),
        (15, 1, 16, 1), (16, 1, 18, 2),
    ],
    items: [(3, 2, "paper"), (2, 2, "four_color_pen"),
        (12, 2, "paper_bin"), (12, 2, "toner_cartridge")],
    cables: [
        (1, 1, 2), (2, 1, 3), (3, 1, 1), (4, 1, 1),
        (5, 1, 1), (6, 1, 1), (7, 1, 1), (8, 1, 1),
        (9, 1, 1), (10, 1, 1), (11, 1, 1), (12, 1, 1),
        (13, 1, 1), (14, 1, 1), (15, 1, 1), (16, 1, 1),
        (17, 1, 1),
    ],
) ]==], 0)

local sender = t.join("assistant")
local receiver = t.join("medic")
local isolated = t.join("engineer")
t.run_ticks(10)

-- Write one source sheet through the actual writer binding.
local paper = assert(t.target_at(sender, 3, 2, "paper"), "source paper is present")
t.click(sender, 3, 2, paper)
t.run_ticks(2)
-- Close the read-only sheet window before selecting the writing tool; the
-- player seam treats an open document as modal for pointer clicks.
t.ui_close(sender)
local pen = assert(t.target_at(sender, 2, 2, "four_color_pen"), "source pen is present")
t.click(sender, 2, 2, pen)
t.run_ticks(2)
assert(t.hands(sender).held == "four_color_pen" or t.hands(sender)[1] == "four_color_pen" or t.hands(sender)[2] == "four_color_pen",
    "source pen is held")
if t.hands(sender).held ~= "four_color_pen" then t.swap_hands(sender); t.run_ticks(1) end
t.use_on_other(sender)
t.run_ticks(2)
local paper_document = assert(t.ui_document(sender, "writing"), "paper document address is available")
local paper_prefix = "doc/" .. paper_document.document .. "/" .. paper_document.generation .. "/paper"
t.ui_edit(sender, paper_prefix .. "/draft", "hello from the shared fax tree")
t.ui_press(sender, paper_prefix .. "/commit")
t.run_ticks(2)
t.swap_hands(sender)
t.run_ticks(1)

-- Both names are enabled independently. The isolated root is excluded from
-- the sender's directory even though its endpoint is advertised.
advertise(receiver, 12, 2, "Medical Fax")
advertise(isolated, 18, 2, "Isolated Fax")
t.ui_close(isolated, "fax")

-- Loading the source sheet reserves the exact item. An empty-hand click then
-- opens the endpoint panel, as it does in the browser.
local sender_fax = assert(t.target_at(sender, 4, 2, "fax"), "sender fax is present")
t.drop(sender)
t.run_ticks(1)
t.click(sender, 4, 2, sender_fax)
t.run_ticks(2)
assert(t.ui(sender, "fax"), "sender fax panel opens empty")
local source_on_floor = assert(t.target_at(sender, 3, 2, "paper"), "source sheet remains available")
t.click(sender, 3, 2, source_on_floor)
t.run_ticks(1)
t.click(sender, 4, 2, sender_fax)
t.run_ticks(2)
assert(t.hands(sender).held == nil, "loading a fax consumes the held source sheet")
    local sender_data = data(sender, "fax")
assert(sender_data.kind == "fax" and sender_data.directory ~= nil,
    "the sender panel exposes its native directory")
assert(#sender_data.directory == 1 and sender_data.directory[1].name == "Medical Fax",
    "same-router discovery excludes the isolated fax; rows=" .. tostring(#sender_data.directory))

-- Selection and send require the viewer-specific confirmation step.
t.ui_press(sender, control(sender, "fax", "/directory/entry/0/target"))
t.run_ticks(1)
t.ui_press(sender, control(sender, "fax", "/confirm/send"))
t.run_ticks(2)
assert_no_script_errors("directory selection and confirmation")
local sending_data = data(sender, "fax")
assert(sending_data.busy == true, "the fax exposes its native busy reservation after admission")

-- The source remains in the machine until the native 40-tick deadline.
assert(#t.items_at(4, 2) == 0, "the source is held during the fax scan")
t.run_ticks(37)
assert(#t.items_at(4, 2) == 0, "the source remains held before the 40-tick deadline")
t.run_ticks(1)
assert(t.items_at(4, 2)[1] == "paper", "the source sheet ejects onto sender ground at tick 40")
assert(t.items_at(12, 2)[1] == "paper", "one fresh recipient sheet arrives at tick 40")

-- Read the received sheet through the ordinary paper window. The native
-- monochrome transform changes the copied fragment colour while preserving
-- the bounded body and source presentation metadata.
local output = assert(t.target_at(receiver, 12, 2, "paper"), "recipient output is readable")
t.click(receiver, 12, 2, output)
t.run_ticks(2)
local output_window = assert(t.ui(receiver, "writing"), "recipient paper opens for reading")
local output_data = output_window.script and output_window.script.data or output_window.data
assert(#output_data.committed == 1, "recipient output has one committed fragment")
assert(output_data.committed[1].text == "hello from the shared fax tree", "recipient output preserves the source text")
assert(output_data.committed[1].style.color == "#000000", "recipient output is monochrome")

-- The output is a real paper item, so put it down before inspecting the
-- recipient machine's post-job stock.
t.ui_close(receiver, "writing")
t.drop(receiver)
t.run_ticks(1)
local receiver_fax = assert(t.target_at(receiver, 12, 2, "fax"), "recipient fax remains available")
t.click(receiver, 12, 2, receiver_fax)
t.run_ticks(2)
local receiver_data = data(receiver, "fax")
assert(receiver_data.paper == 29 and receiver_data.toner == 29,
    "recipient stock charges one paper and toner for the received page")
assert(receiver_data.busy ~= true, "the recipient reservation clears at the 40-tick deadline")

-- Refill each stock through the player-facing containers. The machine starts
-- one unit short, while each container retains the unused remainder.
t.ui_close(receiver, "fax")
local paper_bin = assert(t.target_at(receiver, 12, 2, "paper_bin"), "paper bin is available")
t.click(receiver, 12, 2, paper_bin)
t.run_ticks(1)
assert(t.hands(receiver).held == "paper_bin", "paper bin is held")
t.click(receiver, 12, 2, receiver_fax)
t.run_ticks(2)
assert(t.hands(receiver).held == "paper_bin", "refilling retains the source container")
t.drop(receiver)
t.run_ticks(1)
t.ui_close(receiver, "fax")
t.click(receiver, 12, 2, receiver_fax)
t.run_ticks(2)
receiver_data = data(receiver, "fax")
assert(receiver_data.paper == 30, "paper bin restores the missing sheet")

local toner = assert(t.target_at(receiver, 12, 2, "toner_cartridge"), "toner cartridge is available")
t.click(receiver, 12, 2, toner)
t.run_ticks(1)
assert(t.hands(receiver).held == "toner_cartridge", "toner cartridge is held")
t.click(receiver, 12, 2, receiver_fax)
t.run_ticks(2)
assert(t.hands(receiver).held == "toner_cartridge", "refilling retains the source container")
t.drop(receiver)
t.run_ticks(1)
t.ui_close(receiver, "fax")
t.click(receiver, 12, 2, receiver_fax)
t.run_ticks(2)
receiver_data = data(receiver, "fax")
assert(receiver_data.toner == 30, "toner cartridge restores the missing unit")
