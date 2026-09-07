-- THE SOCKET LIBRARY: how a pack runs the guest program bound to one of
-- a machine's declared sockets, in one gesture.
--
-- A socket is pack business (docs/diegetic-scripting/attribution.md
-- §11): the engine owns the binding -- which host-store file a socket
-- runs, the compiled program, the counters -- and this file owns the
-- asking. `socket.run` pulls the LIVE binding (never a cached handle:
-- a save recompiles in place, so the program a line meets is the one
-- the file holds NOW), hands the guest the machine's persistence
-- capsule, and attributes the run to the socket so its transcript and
-- fault rows join the load row that installed it.
--
-- The fail policy is the CALLER's, deliberately: this file answers nil
-- for "nothing ran" -- unbound socket, undeclared id, faulted script --
-- and whether a line then passes, a form is refused or a door stays
-- shut is the socket definition's own sentence (fail-open for the
-- message filter, lib/radio_relay.luau, because delivery matters more
-- than the script).
local socket = {}

-- Run the program bound to `id` on `machine` over `env`, attributed to
-- that socket. Answers the guest's returned value, or nil when there
-- is nothing bound or the run faulted. `env` gets `mem`, the machine's
-- own persistence capsule; the copy-boundary rules apply to the rest
-- (plain data only -- a Handle cannot cross, docs/luau-api/disl.md).
function socket.run(machine, id, env)
    local program = sim.disl.socket_program(machine, id)
    if program == nil then
        return nil
    end
    env.mem = sim.disl.mem(machine)
    local result = sim.disl.run(program, env, {
        socket = { machine = machine, id = id },
    })
    if result.ok then
        return result.value
    end
    return nil
end

return socket
