local load_classes = require("@lib/load_classes")
local netmsg = require("@lib/netmsg")
local network = require("@lib/network")

-- The APC, and the three things about it that are not mechanism.
--
-- Everything a player DOES to one is native: the store, the master
-- breaker, the ports and their reserve flags, and the `link` module's
-- address, roster and candidates -- and a press on any of those rows
-- goes through the same helper a script's gesture would
-- (docs/TGUI.md). There is deliberately no handler here that throws the
-- master, joins or releases anything; a second path to those would be
-- a second answer to who may.
--
-- What is left is a SENTENCE, a LADDER and a FLAG.
--
-- The sentence is `lib/network.luau`'s, said with this box's nouns. A
-- crewman who touches a panel gets its window and one line about what
-- it is carrying, because "online" and "suspended" are the engine's
-- words and nobody says them out loud. The access point and the router
-- are the other callers and differ in exactly two words
-- (fixtures/access_point.luau, fixtures/network_router.luau). "Fitting"
-- rather than "device" because what hangs off a panel is what the
-- panel feeds -- the tubes, the fans, whatever is on a cord -- and a
-- crewman reading the line knows what is plugged in without being told
-- there is a network at all.
--
-- The ladder is tg's autoset (docs/POWER.md): the engine hands this
-- file the cell's charge every pass, and this file alone throws the
-- panel's load-class gates. The window shows them and never throws
-- one, so the ladder is the only answer to which classes a room gets.
--
-- The flag is the one thing a panel knows that nothing else on the
-- station does: whether the room is running off its own cell. The
-- engine raises `flow.reserve.done` on the crossing and only on the
-- crossing, so this is one emission when the mains die and one when
-- they come back, never a per-pass drumbeat. What the lights do with
-- it is theirs (fixtures/light.luau); all this says is that it
-- happened.
--
-- The use handler rides `interaction.use.done` rather than
-- `interaction.use` for the access point's reason: the decision anchor
-- is where a handler REPLACES the click, and replacing this one would
-- eat both the panel and the crowbar.
local content = {
    id = "apc",
}

local NOUN = "APC"
local MEMBER = "fitting"

-- tg's autoset, one rung per load class in percent of the cell: a
-- class keeps delivering while the cell is at or over its rung and
-- holds anything at all -- equipment to 30, lighting to 15, the room's
-- air until it is empty (apc_main.dm:11, :13, :637-664).
local RUNGS: { [string]: number } = { equipment = 30, lighting = 15, environment = 0 }
-- The power alarm goes up with the first shed and clears only above 75
-- (:15, :672-673).
local ALARM_CLEAR_ABOVE = 75
-- On the panel, in the shift record: `sight` so what a crewman at the
-- box could be shown is what a spec can read (t.structure_at).
local ALARM = "lunatic/tfs:power_alarm"

-- The rungs against lib/load_classes.luau, once at load: a class with
-- no rung would never be thrown and a rung naming no class is a line
-- nothing reads, so either refuses the file. Returns the first shed.
local function checked_first_shed(): number
    local first = 0
    for _, class in ipairs(load_classes.power) do
        local rung = RUNGS[class]
        if rung == nil then
            error("fixtures/apc.luau: load class " .. class .. " has no ladder rung")
        end
        first = math.max(first, rung)
    end
    for class in pairs(RUNGS) do
        if table.find(load_classes.power, class) == nil then
            error("fixtures/apc.luau: ladder rung " .. class .. " names no load class")
        end
    end
    return first
end
local FIRST_SHED = checked_first_shed()

-- Which classes a cell at this charge keeps delivering.
local function wanted(charge_j: number, percent: number): { [string]: boolean }
    local want = {}
    for _, class in ipairs(load_classes.power) do
        want[class] = charge_j > 0 and percent >= RUNGS[class]
    end
    return want
end

if sim ~= nil then
    sim.define("script_var", ALARM, { replicate = "sight" })
    local script_definition =
        sim.define("behavior", "lunatic/tfs:" .. content.id, { prototype = content.id })

    script_definition:handle(
        "interaction.use.done",
        { kind = "react", route = "interact" },
        function(ev)
            -- An empty hand, and a use that actually resolved: `implement`
            -- is absent for the crewman reading the box and present for the
            -- one taking it off the wall, and both arrive here.
            if ev.implement ~= nil or ev.outcome ~= "completed" then
                return
            end
            local said = network.line(ev.subject, NOUN, MEMBER)
                or sim.msg("lunatic/tfs:lib.network.no_card", {})
            sim.message.send({ recipient = ev.actor, message = said })
        end
    )

    -- THE LADDER, once a pass per panel. Completions reach every
    -- handler of the anchor, so a bank's report is somebody else's. A
    -- gate is thrown only when it disagrees with the ladder, class by
    -- class in the network's own order, so a steady cell writes
    -- nothing and a falling one writes the same rows every shift.
    script_definition:handle("flow.store.done", { kind = "react" }, function(ev: FlowStoreDonePayload)
        if ev.subject.prototype ~= content.id then
            return
        end
        local store = sim.flow.store(ev.subject)
        local gates = store and store.gates
        if gates == nil then
            return
        end
        local percent = 100 * ev.level
        local want = wanted(ev.charge_j, percent)
        for _, class in ipairs(load_classes.power) do
            if gates[class] ~= want[class] then
                sim.flow.set_gate({ subject = ev.subject, class = class, on = want[class] })
            end
        end
        -- A tripped network delivers nothing whatever the cell holds,
        -- so the panel calls that too, and keeps calling it until the
        -- breaker is back and the cell is above the clear line.
        local alarmed = ev.subject.vars[ALARM] == true
        if not alarmed and (ev.tripped or percent < FIRST_SHED) then
            ev.subject.vars[ALARM] = true
        elseif alarmed and not ev.tripped and percent > ALARM_CLEAR_ABOVE then
            ev.subject.vars[ALARM] = nil
        end
    end)

    -- ON AND OFF THE RESERVE. `ev.subject` is the panel that crossed,
    -- and it is the panel that has to be the subject of the emission --
    -- a message put on the network by anything else would reach the
    -- wrong half of the forest. `ev.on` is which way it crossed, and
    -- the two directions are one set and one clear of the same named
    -- flag.
    script_definition:handle("flow.reserve.done", { kind = "react" }, function(ev: FlowReserveDonePayload)
        if ev.subject.prototype ~= content.id then
            return
        end
        sim.link.emit({
            subject = ev.subject,
            payload = netmsg.light_flag(ev.on and "set" or "clear", "low_power"),
        })
    end)
end

return content
