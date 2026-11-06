-- A gas turbine mapped running (the core rotor's `running` placement knob):
-- the line links as it stands up and its first run starts with no hand on a
-- console, while the same line mapped without the knob stays shut. The
-- running line keeps turning past its first passes, so the start was a
-- real run, not a state painted on at boot.
t.world(
    [==[(
    name: "turbine hall",
    environment: (gravity_m_s2: Exact(9.80665)),
    legend: {
        '.': (composition: (components: [(component: "station_base")])),
        '#': (composition: (components: [(component: "station_base"), (component: "wall")])),
    },
    levels: [
        (
            rows: [
                "#######",
                "#.....#",
                "#.....#",
                "#.....#",
                "#######",
            ],
            structures: [
                (1, 2, "player_spawn"),
                (2, 1, "inlet_compressor", "closed", { "dir": "east" }),
                (3, 1, "core_rotor", "closed", { "dir": "east", "running": true }),
                (4, 1, "turbine_outlet", "closed", { "dir": "east" }),
                (2, 3, "inlet_compressor", "closed", { "dir": "east" }),
                (3, 3, "core_rotor", "closed", { "dir": "east" }),
                (4, 3, "turbine_outlet", "closed", { "dir": "east" }),
            ],
            painted: [
                (1, 1, "room_air"), (5, 1, "room_air"), (1, 2, "room_air"), (2, 2, "room_air"),
                (3, 2, "room_air"), (4, 2, "room_air"), (5, 2, "room_air"), (1, 3, "room_air"),
                (5, 3, "room_air"),
            ],
        ),
    ],
    blends: {
        "room_air": (rows: [("n2", 32.9), ("o2", 8.7)], temperature_k: 293.15, amount: per_m3),
    },
)]==],
    0
)

local _ = t.join()
t.tick()

local function line_in(y: number, state: string): boolean
    for x = 2, 4 do
        if assert(t.structure_at(x, y), "a section stands at " .. x .. "," .. y).state ~= state then
            return false
        end
    end
    return true
end

t.run_seconds(0.5)
assert(line_in(1, "running"), "the line mapped running turns from the start")
assert(line_in(3, "closed"), "the line mapped without the knob stays shut")

-- Past a few passes (one every 2 s), the run is still turning: its rotor's
-- checks found the line whole and powered rather than halting it.
t.run_seconds(6)
assert(line_in(1, "running"), "the mapped run keeps turning past its first passes")
assert(line_in(3, "closed"), "the unmapped line never started")
assert(#t.script_errors() == 0, "no handler threw")
