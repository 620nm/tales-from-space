-- THE PROGRAM SLOT LIBRARY: how a pack runs the guest program loaded in
-- one of a machine's declared program slots, in one gesture.
--
-- A program slot is pack business (docs/diegetic-scripting/attribution.md
-- §11): the engine owns the binding -- which host-store file a slot
-- runs, the compiled program, the counters -- and this file owns the
-- asking. `program_slot.run` pulls the LIVE binding (never a cached
-- handle: a save recompiles in place, so the program a line meets is the
-- one the file holds NOW), hands the guest the machine's persistence
-- capsule, and attributes the run to the slot so its transcript and
-- fault rows join the load row that installed it.
--
-- The fail policy is the CALLER's, deliberately: this file answers nil
-- for "nothing ran" -- empty slot, undeclared id, faulted script --
-- and whether a line then passes, a form is refused or a door stays
-- shut is the slot definition's own sentence (fail-open for the
-- message filter, lib/radio_relay.luau, because delivery matters more
-- than the script).
local program_slot = {}

-- Run the program loaded in slot `id` on `machine` over `env`,
-- attributed to that slot. Answers the guest's returned value, or nil
-- when the slot is empty or the run faulted. `env` gets `mem`, the
-- machine's own persistence capsule; the copy-boundary rules apply to
-- the rest (plain data only -- a Handle cannot cross, docs/luau-api/disl.md).
function program_slot.run(machine, id, env)
    local program = sim.disl.slot_program(machine, id)
    if program == nil then
        return nil
    end
    env.mem = sim.disl.mem(machine)
    local result = sim.disl.run(program, env, {
        program_slot = { machine = machine, id = id },
    })
    if result.ok then
        return result.value
    end
    return nil
end

return program_slot
