local controls = require("@helpers/ui_controls")

local function rejects(check: (unknown) -> unknown, value: unknown): ()
    assert(not pcall(check, value), "invalid disclosed data must fail its reader")
end

rejects(controls.rows, nil)
rejects(controls.rows, { false })
rejects(controls.rows, { [1] = {}, [3] = {} })
rejects(controls.rows, { unexpected = {} })
rejects(controls.texts, { "valid", false })
assert(#controls.rows({}) == 0, "an explicitly empty array is valid")
assert(#controls.rows(nil or {}) == 0, "optional arrays need an explicit fallback")

local record = { value = 42 }
assert(controls.rows({ record })[1] == record, "row validation retains the record")
local values = controls.array({ false, 0, "" })
assert(#values == 3 and values[1] == false, "false values are valid array entries")
