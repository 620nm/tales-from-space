-- Both reusable components are constructed through the ordinary player seam.
t.world([==[(
    name: "controller fittings bench",
    legend: { '.': (turf: Plating), '#': (turf: Wall) },
    rows: ["#######", "#.....#", "#.....#", "#######"],
    spawns: [(2, 1)],
    items: [(2, 1, "airlock_button_fitting"), (2, 1, "screwdriver"),
        (2, 1, "wrench"), (3, 1, "dual_port_vent_fitting")],
    pipes: [(3, 0, 2), (3, 2, 8)],
)]==], 0)
local p = t.join()
t.run_ticks(2)
t.click(p, 2, 1, t.target_at(2, 1, "airlock_button_fitting"))
t.run_ticks(2)
t.click(p, 2, 0)
t.run_ticks(45)
assert(t.structure_at(2, 1) and t.structure_at(2, 1).id == "airlock_button", "button build: " .. table.concat(t.messages(p), " | "))
assert(t.count_items("airlock_button_fitting") == 0, "assembly consumes its fitting")
t.click(p, 2, 1, t.target_at(2, 1, "wrench"))
t.run_ticks(2)
t.click(p, 3, 1, t.target_at(3, 1, "dual_port_vent_fitting"))
t.run_ticks(45)
assert(t.structure_at(3, 1).id == "dual_port_vent", "the floor fitting becomes the two-port machine")
assert(t.count_items("dual_port_vent_fitting") == 0, "the vent fitting is consumed")
t.click(p, 3, 1, t.target_at(3, 1, "dual_port_vent"))
t.run_ticks(45)
assert(t.structure_at(3, 1) == nil and t.count_items("dual_port_vent_fitting") == 1,
    "the reusable vent comes back off the deck as its fitting")
t.drop(p)
t.run_ticks(2)
t.click(p, 2, 1, t.target_at(2, 1, "screwdriver"))
t.run_ticks(2)
t.click(p, 2, 1, t.target_at(2, 1, "airlock_button"))
t.run_ticks(45)
assert(t.structure_at(2, 1) == nil and t.count_items("airlock_button_fitting") == 1,
    "the mounted button comes back as its fitting")
