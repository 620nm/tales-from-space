-- The transceiver's two behaviors, and deliberately no third
-- (machines/transceiver.luau): a sentence for whoever touches it, and
-- a lamp that follows its keys. Delivery itself is the transmitting
-- item's `speech.radio` and never a hook on the tower
-- (lib/radio.luau) -- a second path to "who hears" would be a second
-- answer to it.
local content = {
    id = "transceiver",
}

if sim ~= nil then
    -- Which face the tower shows while powered. The prototype's sprite
    -- table names this var and bounds its values; the engine draws the
    -- dark base by itself whenever the cord dies, so this is only ever
    -- "keyed" or nothing (docs/CONTENT-SCHEMA.md §1.3).
    sim.define("script_var", "lunatic/tfs:transceiver_look", { replicate = "sight" })
    local script_definition = sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })

    -- AN EMPTY HAND, and a use that actually resolved -- the access
    -- point's contract exactly (fixtures/access_point.luau): the
    -- panel and the crowbar both arrive here too, and both already
    -- did their own work on the way past.
    script_definition:handle("interaction.use.done", { kind = "react", route = "interact" }, function(ev)
        if ev.implement ~= nil or ev.outcome ~= "completed" then
            return
        end
        sim.message.send({ recipient = ev.actor, message = radio.status_line(ev.subject) })
    end)

    -- The lamp follows the SETTLED sockets: `parts.refresh.done` fires
    -- whenever a roster settles -- boot, a finished frame, a swap --
    -- and the completion's subject answers what is in them now
    -- (fixtures/chem_heater.luau, the same seam).
    script_definition:handle("parts.refresh.done", { kind = "react", route = "parts" }, function(ev)
        local keyed = radio.keyed_words(ev.subject) ~= nil
        ev.subject.vars["transceiver_look"] = if keyed then "transceiver_on" else nil
    end)
end

return content
