-- The first socket: a guest script filtering the lines that cross a
-- tower (docs/files/scriptable-machine.md, docs/diegetic-scripting/
-- attribution.md §11).
--
-- The transceiver declares a host store, a drive that reads nothing but
-- program text, and one socket -- `carry`, the relay stage a line's
-- words pass through (content/machines/transceiver.luau,
-- lib/radio_relay.luau). This spec drives the whole lifecycle the way a
-- crewman would: write a filter on A:, bind it, hear the line come out
-- the other side rewritten; then the drop, the fault, the edit of a
-- RUNNING program, and the delete guard. The corridor fixture is
-- radio_coverage_test.luau's: one keyed tower, a speaker beside it, a
-- listener inside the tower's clear band and outside every local
-- circle, so whatever the listener hears is what the tower settled on.
--
-- The contract under test (lib/radio_relay.luau `carry`): the guest
-- sees `{ content, channel, source, pass }` and its answer is honored
-- as -- a `text`/`channel` pair rewrites, `pass == false` drops the
-- line, and anything else (nil, a fault, a malformed table) passes the
-- words UNCHANGED. Fail-open is the point: delivery matters more than
-- the script, and the fault is on the record either way.

local function said(p, line)
    for _, m in ipairs(t.messages(p)) do
        if m == line then
            return true
        end
    end
    return false
end

local function heard(p, line)
    for _, m in ipairs(t.messages(p)) do
        if m:find(line, 1, true) then
            return true
        end
    end
    return false
end

-- The corridor (distances per lib/radio.luau): speaker (1,1) -> tower
-- (2,1) uplinks; speaker -> listener (20,1) is 19, outside the local
-- circle; tower -> listener is 18, well inside the clear band, so the
-- tower's settled words arrive whole.
t.world([==[(
    name: "socket corridor",
    legend: {
        ' ': (turf: Space),
        '.': (turf: Floor),
        '#': (turf: Wall),
        'G': (turf: Floor, fixture: Some(Generator)),
        'a': (turf: Floor, fixture: Some(Apc)),
        'o': (turf: Floor, fixture: Some(Outlet)),
    },
    rows: [
        "#######################",
        "#.....................#",
        "#Gao..................#",
        "#######################",
    ],
    spawns: [(1, 1), (3, 1), (20, 1)],
    items: [
        (1, 1, "encryption_key.medical"),
        (20, 1, "encryption_key.medical"),
    ],
    machines: [
        (2, 1, "transceiver", { "encryption_1": "encryption_key.medical" }),
    ],
    cables: [
        (1, 2, 2), (2, 2, 3), (3, 2, 1),
    ],
)]==], 0)

local speaker = t.join()
local operator = t.join()
local listener = t.join()
t.run_ticks(20)

-- The speaker and the listener carry the Lifeline key; the operator's
-- hands stay EMPTY, because a held key clicked on the tower is a part
-- gesture, not a panel one.
local function pocket(p)
    local x, y = t.pos(p)
    t.click(p, x, y, t.target_at(x, y, "encryption_key.medical"))
    t.run_ticks(2)
    assert(t.hands(p).held == "encryption_key.medical", "the key is in hand")
end
pocket(speaker)
pocket(listener)

local function drain_all()
    local _ = t.messages(speaker)
    local _ = t.messages(operator)
    local _ = t.messages(listener)
end

-- ---- the panel: one socket, nothing bound ------------------------------
t.click(operator, 2, 1, t.target_at(2, 1))
t.tick()
local ui = t.ui(operator)
assert(ui, "a bare hand opens the tower's window")
assert(ui.presentation == "panes", "the files module is the panes one")
assert(ui.sockets and #ui.sockets == 1, "one declared socket: " .. tostring(ui.sockets and #ui.sockets))
assert(ui.sockets[1].id == "carry", "named for the stage it filters")
assert(ui.sockets[1].state.id == "sockets.state.unbound", "and it starts empty")
assert(ui.sockets[1].runs == 0 and ui.sockets[1].faults == 0, "with clean counters")

-- The tower reads program text only: the create control offers `disl`
-- on the host store and nothing else (no disk in the slot, and `md`
-- is a word this machine cannot read).
assert(ui.create.host and #ui.create.host == 1 and ui.create.host[1] == "disl",
    "the tower creates program text only")
assert(ui.create.media == nil, "and has no disk side until a disk is in it")

-- ---- write the filter on A: --------------------------------------------
-- The SHOUT filter: every line it touches comes out uppercase.
local SHOUT = "return { text = string.upper(content) }"
t.ui_act(operator, "text", '{"field":"file_create","option":"host:disl:' .. ui.stores[1].binding
    .. '","text":"untitled"}')
t.tick()
ui = t.ui(operator)
assert(ui.open and ui.open.store == "host" and ui.open.ext == "disl",
    "the new program is open on the host store")
local file = "host:" .. string.format("%d", ui.open.uid) .. ":" .. ui.open.binding
local uid = ui.open.uid
t.ui_act(operator, "text", '{"field":"file_save","option":"' .. file
    .. '","text":"' .. SHOUT .. '","revision":0}')
t.tick()
ui = t.ui(operator)
assert(ui.open.body == SHOUT, "the filter's source is on the disk of the tower")
assert(ui.editor and ui.editor.bound == false, "nothing runs it yet")

-- ---- check as you type ----------------------------------------------------
-- A `file_change` carries the WHOLE draft and answers with the native
-- check's markers on the same pane; a `file_revert` drops the draft.
-- Neither act is ledgered and neither touches the saved body.
t.ui_act(operator, "text", '{"field":"file_change","option":"' .. file
    .. '","text":"return {","revision":0}')
t.tick()
ui = t.ui(operator)
assert(ui.editor and #ui.editor.markers == 1, "a broken draft checks as it is typed")
assert(ui.editor.markers[1].line == 1 and #ui.editor.markers[1].message > 0,
    "the marker names a line and a fault: " .. tostring(ui.editor.markers[1].message))
assert(ui.editor.body == "return {", "the editor shows the draft, not the saved body")
assert(ui.open.body == SHOUT, "the saved body is untouched by a draft")

t.ui_act(operator, "toggle", '{"field":"file_revert","option":"' .. file .. '"}')
t.tick()
ui = t.ui(operator)
assert(ui.editor.body == SHOUT and #ui.editor.markers == 0,
    "revert drops the draft and its markers")
assert(ui.open.body == SHOUT, "and the saved body is what remains")

-- ---- bind it ------------------------------------------------------------
t.ui_act(operator, "toggle", '{"field":"socket_load","option":"carry:' .. uid .. ":" .. ui.stores[1].binding .. '"}')
t.tick()
ui = t.ui(operator)
assert(ui.sockets[1].state.id == "sockets.state.bound", "the socket is bound")
assert(ui.sockets[1].file == "untitled.disl", "and names what it runs: "
    .. tostring(ui.sockets[1].file))
assert(ui.sockets[1].uid == uid, "the uid is the binding's identity")
assert(ui.editor.bound == true, "the open file knows a socket is running it")

local loaded = t.ledger_rows("disl_socket_loaded")
assert(#loaded == 1 and loaded[1].socket == "carry" and loaded[1].uid == uid,
    "the load is on the record")
assert(loaded[1].machine == "radio transceiver", "naming the machine: "
    .. tostring(loaded[1].machine))
local compiled = t.ledger_rows("disl_compiled")
assert(#compiled == 1 and compiled[1].source == SHOUT,
    "the load compiled the file's body, VERBATIM on the record")

-- ---- a line crosses it ---------------------------------------------------
drain_all()
t.say(speaker, ";hello there crew")
t.run_ticks(2)
assert(said(listener, "HELLO THERE CREW"), "the tower's words came out filtered: "
    .. table.concat(t.messages(listener), " | "))

local runs = t.ledger_rows("disl_run")
assert(#runs == 1, "one run for one crossing: " .. #runs)
assert(runs[1].socket == "carry" and runs[1].hosting == "radio transceiver",
    "the transcript names its socket and its machine")
-- ScriptValue is externally tagged on the wire: a guest table reads as
-- `{ Map = { <key> = { String = ... } } }`.
assert(runs[1].value.Map.text.String == "HELLO THERE CREW", "and what it answered")

-- ---- a drop suppresses the line ------------------------------------------
-- Editing the RUNNING program is editing the file: the save recompiles
-- in place, and the next line meets the new program (atomic recompile).
t.run_ticks(10) -- the pacing window on text acts (docs/TGUI.md)
local DROP = "return { pass = false }"
t.ui_act(operator, "text", '{"field":"file_save","option":"' .. file
    .. '","text":"' .. DROP .. '","revision":1}')
t.tick()
drain_all()
t.say(speaker, ";the tank room is leaking")
t.run_ticks(2)
assert(said(speaker, "the tank room is leaking"), "the speaker's own copy is local, untouched")
assert(#t.messages(listener) == 0, "a pass=false answer drops the line for the tree")

runs = t.ledger_rows("disl_run")
assert(#runs == 2 and runs[2].value.Map.pass.Bool == false, "the drop is a run like any other")
assert(#t.ledger_rows("disl_fault") == 0, "a drop is not a fault")
t.run_ticks(20) -- the pane republishes on the window cadence, not per line
ui = t.ui(operator)
assert(ui.sockets[1].runs == 2 and ui.sockets[1].faults == 0,
    "the counters belong to the socket and survive the re-save: runs="
        .. tostring(ui.sockets[1].runs) .. " faults=" .. tostring(ui.sockets[1].faults))

-- ---- a fault delivers the line UNCHANGED ---------------------------------
-- Fail-open: a broken script must not silence the radio, and the fault
-- is attack evidence on the record (docs/diegetic-scripting/
-- attribution.md §10).
t.run_ticks(10)
local BROKEN = "error('boom')"
t.ui_act(operator, "text", '{"field":"file_save","option":"' .. file
    .. '","text":"' .. BROKEN .. '","revision":2}')
t.tick()
drain_all()
t.say(speaker, ";anyone copy")
t.run_ticks(2)
assert(said(listener, "anyone copy"), "a faulted filter passes the words as they stand: "
    .. table.concat(t.messages(listener), " | "))
local faults = t.ledger_rows("disl_fault")
assert(#faults == 1 and faults[1].fault == "error",
    "the fault is on the record")
assert(faults[1].socket == "carry" and faults[1].hosting == "radio transceiver",
    "attributed to the socket that ran it")
t.run_ticks(20) -- the window cadence again
ui = t.ui(operator)
assert(ui.sockets[1].runs == 3 and ui.sockets[1].faults == 1,
    "the fault tally is the socket's, not the file's")

-- ---- the edit of a running program takes ----------------------------------
t.run_ticks(10)
local PREFIX = "return { text = 'filtered: ' .. content }"
t.ui_act(operator, "text", '{"field":"file_save","option":"' .. file
    .. '","text":"' .. PREFIX .. '","revision":3}')
t.tick()
drain_all()
t.say(speaker, ";medical to the lab")
t.run_ticks(2)
assert(said(listener, "filtered: medical to the lab"),
    "the save recompiled the running program: " .. table.concat(t.messages(listener), " | "))
assert(#t.ledger_rows("disl_compiled") == 4,
    "every distinct body compiled is its own row, the old ones intact")

-- ---- a bound file cannot be deleted ---------------------------------------
t.ui_act(operator, "toggle", '{"field":"file_delete","option":"' .. file .. '"}')
t.tick()
assert(heard(operator, "unload it first"),
    "deleting what a socket runs refuses and SAYS so: "
        .. table.concat(t.messages(operator), " | "))
assert(#t.ledger_rows("file_deleted") == 0, "and nothing was deleted")
ui = t.ui(operator)
assert(ui.sockets[1].state.id == "sockets.state.bound", "still bound")

-- ---- unload, and the tower is stock again ----------------------------------
t.ui_act(operator, "toggle", '{"field":"socket_unload","option":"carry:' .. ui.stores[1].binding .. '"}')
t.tick()
ui = t.ui(operator)
assert(ui.sockets[1].state.id == "sockets.state.unbound", "unbound")
local unloaded = t.ledger_rows("disl_socket_unloaded")
assert(#unloaded == 1 and unloaded[1].uid == uid, "the unload is on the record")

drain_all()
t.say(speaker, ";stock hardware is honest hardware")
t.run_ticks(2)
assert(said(listener, "stock hardware is honest hardware"),
    "with nothing bound the words pass as they stand")
-- Three successful runs on the record (the faulting one is a
-- `disl_fault` row, not a transcript) and the unload added none.
assert(#t.ledger_rows("disl_run") == 3, "an unbound socket runs nothing")
