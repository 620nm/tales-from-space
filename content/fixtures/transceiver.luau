-- The transceiver's behaviors (machines/transceiver.luau): a sentence
-- for whoever touches it, a lamp that follows its keys, and its three
-- stages of the relay walk. WHO FINALLY HEARS is still the transmitting
-- item's `speech.radio` and never a hook here (lib/radio.luau) -- a
-- second path to "who hears" would be a second answer to it. These
-- stages settle which towers are speaking at all, and the answers
-- themselves live in lib/radio_relay.luau.
local content = {
    id = "transceiver",
}

if sim ~= nil then
    -- Which face the tower shows while powered. The prototype's sprite
    -- table names this var and bounds its values; the engine draws the
    -- dark base by itself whenever the cord dies, so this is only ever
    -- "keyed" or nothing (docs/content-schema/appearance.md).
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

    -- All four stages. Each is a transform because each writes
    -- something back -- `reads`, a reader, the words, `cancelled` --
    -- and a station is where the decision is made, never where state is
    -- recorded (docs/luau-api/radio-relay.md).
    --
    -- `radio.read` is here because a tower joined to nothing IS its own
    -- tree's top, and the tree of one it stands in has to answer the
    -- same question a wall box would: with no key for the word, it
    -- reads nothing and carries nothing. Without it the engine's
    -- fail-open default hands a blank tower the words of every line
    -- spoken beside it.
    script_definition:handle("radio.receive", { kind = "transform", route = "receive" }, radio_relay.receive)
    script_definition:handle("radio.read", { kind = "transform", route = "read" }, radio_relay.read)
    script_definition:handle("radio.carry", { kind = "transform", route = "carry" }, radio_relay.carry)
    script_definition:handle("radio.send", { kind = "transform", route = "send" }, radio_relay.send)
end

return content
