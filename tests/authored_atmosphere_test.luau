-- Map air fixes the outdoor mix; an omitted mix leaves the cold profile free.
local MAP = [==[(
    name: "Authored surroundings", tags: ["terrestrial"],
    environment: (atmosphere: Exact(true), %s),
    legend: { 'e': (turf: Empty), '#': (turf: Wall), '.': (turf: Floor) },
    rows: ["eeeee", "e###e", "e#.#e", "e###e", "eeeee"],
    spawns: [(2, 2)],
    blends: { "%s": (
        rows: [("co2", 35.0)], temperature_k: 310.0, amount: per_tile,
    ), "room_air": (
        rows: [("n2", 20.0)], temperature_k: 280.0, amount: per_tile,
    ) },
    painted: [(2, 2, "room_air")],
)]==]

t.world(string.format(MAP, 'atmosphere_blend: Some("map_air")', "map_air"), 7, "free_build")
local fixed = t.environment()
assert(fixed.id == "cold_outdoors", "the map mix does not reject the cold profile")
assert(fixed.profile.atmosphere.blend == "map_air")
assert(fixed.profile.atmosphere.air_half_life_s == 60)
assert(fixed.profile.atmosphere.heat_half_life_s == 120)
assert(t.turf(0, 0) == "ground", "absent turf inherits the selected terrain")
assert(math.abs(t.room_temperature(0, 0) - 310.0) < 0.01)
local outside = t.room_gas(0, 0)
assert(math.abs((outside.co2 or 0) - 35) < 1e-6)
assert((outside.o2 or 0) == 0, "the profile cannot replace authored carbon dioxide with breathable air")
assert(math.abs(t.room_temperature(2, 2) - 280.0) < 0.01)
assert(math.abs((t.room_gas(2, 2).n2 or 0) - 20) < 1e-6, "painted room air stays independent")
t.foul_room(0, 0, "n2", 10.0)
local added = t.room_gas(0, 0).n2
t.run_ticks(120)
outside = t.room_gas(0, 0)
assert((outside.co2 or 0) > 0)
assert((outside.n2 or 0) < added, "outdoor air clears the added nitrogen")
assert((outside.o2 or 0) == 0, "outdoor recovery keeps the authored mix")

t.world(string.format(MAP, "", "map_air"), 7, "free_build")
assert(t.environment().profile.atmosphere.blend == "refrigerated_air")
assert(math.abs(t.room_temperature(0, 0) - 259.15) < 0.01)
assert((t.room_gas(0, 0).o2 or 0) > 0, "the game fills an unspecified mix")

t.world(string.format(MAP, "", "refrigerated_air"), 7, "free_build")
assert((t.room_gas(0, 0).o2 or 0) > 0, "a local recipe is not ambient until explicitly selected")
t.world(string.format(MAP, 'atmosphere_blend: Some("refrigerated_air")', "refrigerated_air"), 7, "free_build")
assert(math.abs(t.room_temperature(0, 0) - 310.0) < 0.01)
assert((t.room_gas(0, 0).o2 or 0) == 0, "the selected map recipe wins a pack ID collision")
