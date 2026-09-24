-- Seeds 31..40 of the sky roll's forty-seed sweep (the replay half is
-- `space_environment_test.luau`). Different seeds really do differ: a roll
-- that ignored the roster and always answered "dead space" would pass the
-- replay forever, so each slice of the sweep lands on more than one sky.
local space_environment = require("@helpers/space_environment")

local distinct = space_environment.roll_seeds(31, 40)
assert(distinct > 1, "and ten shifts are not all parked in the same place")
