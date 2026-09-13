-- Shared bounded-paper presentation. The file store remains authoritative;
-- this helper only projects its committed fragments and submits an append.
-- The native writer resolves the exact held tool, style, Mind and charges.
local writing = {}

writing.paper = "paper"
writing.file_uid = 0
writing.max_append = 4096
writing.max_body = 8192
writing.max_fragments = 64

local function read(paper)
    if sim == nil or paper == nil then return nil end
    local ok, document = pcall(sim.documents.read, paper, writing.file_uid)
    if not ok or document == nil then return nil end
    return document
end

function writing.fragments(document)
    local out = {}
    for index, fragment in ipairs(document.fragments or {}) do
        if index > writing.max_fragments then break end
        -- Do not send `document.body` alongside these texts: fragments are
        -- the styled committed projection and duplicate body bytes.
        out[index] = {
            text = fragment.text,
            style = {
                font_family = fragment.style and fragment.style.font,
                color = fragment.style and fragment.style.color,
                weight = fragment.style and fragment.style.weight,
            },
        }
    end
    return out
end

function writing.view(paper, draft)
    local document = read(paper)
    if document == nil then return nil end
    return {
        kind = "paper",
        name = document.name,
        revision = document.revision,
        committed = writing.fragments(document),
        draft = if type(draft) == "string" then draft else "",
    }, document
end

function writing.open(actor, paper, draft, implement)
    local view = writing.view(paper, draft)
    if view == nil then return false end
    local data = view
    local request = {
        viewer = actor,
        owner = paper,
        channel = "writing",
        presentation_key = "writing/paper",
        view = data,
        actions = { write = writing.max_append },
    }
    -- The native writer binding retains this exact held item and validates
    -- its state for every later act; it is omitted for read-only opening.
    if implement ~= nil then request.implement = implement end
    ui.open(request)
    return true
end

function writing.update(actor, paper, draft)
    local view = writing.view(paper, draft)
    if view == nil then return false end
    ui.update({
        viewer = actor,
        owner = paper,
        channel = "writing",
        view = view,
        actions = { write = writing.max_append },
    })
    return true
end

-- A successful commit is one native append. `implement` is supplied by the
-- native proposed-writer/contact binding; no client style or entity id is
-- accepted from the script document.
function writing.append(paper, writer, text)
    if paper == nil or writer == nil or type(text) ~= "string"
        or text == "" or #text > writing.max_append then
        return false
    end
    local document = read(paper)
    if document == nil or document.append_only ~= true
        or type(document.body) ~= "string"
        or #document.body + #text > writing.max_body
        or #(document.fragments or {}) >= writing.max_fragments then
        return false
    end
    sim.documents.append({
        document = paper,
        uid = writing.file_uid,
        expected_revision = document.revision,
        text = text,
        writer = writer,
    })
    return true
end

-- Every held writing item opens the same paper document. Keep this route in
-- the shared library so crayons and the pen cannot drift apart.
function writing.attach(definition)
    definition:handle("interaction.use", { kind = "replace", route = "use" }, function(ev)
        local target = ev.claim and ev.claim.entity
        if target == nil or target.prototype ~= writing.paper then
            return { replaced = false }
        end
        return writing.open(ev.actor, target, "", ev.implement)
    end)
end

return writing
