-- What a roster file does once a consume has landed. `Handle:consume()`
-- is buffered and returns nothing, so only `item.consume.done` knows
-- whether a unit was spent, and a refusal (an exchange's hold) spends
-- nothing (the engine's docs/luau-api/item-consume.md). That completion
-- names the item and nothing else -- not the machine it went into nor
-- the hand that fed it -- so the caller notes those beside the call and
-- takes the note back off the completion:
--
--     consume_followups.expect(refits, tube, { fitting = self, user = user })
--     tube:consume()
--     -- in the item.consume.done handler:
--     local refit = consume_followups.settle(refits, ev.item)
--     if refit ~= nil and ev.outcome == "completed" then ... end
--
-- A book is Lua heap scratch (the engine's
-- docs/scripting/execution-model.md §1.4): it bridges one apply and
-- never holds a fact the world needs. Notes settle oldest first, so two
-- consumes of one item in one batch each find their own; a note no
-- completion claims within a second (its handler raised after the note)
-- ages out, and a full book drops its oldest. Handles match by `==`,
-- which still holds for an item a whole-item spend has retired.

local consume_followups = {}

-- At most this many consumes in flight per book.
local CAPACITY = 16

export type ConsumeFollowups<T> = {
    items: { Handle },
    notes: { T },
    ticks: { number },
}

function consume_followups.new<T>(): ConsumeFollowups<T>
    return { items = {}, notes = {}, ticks = {} }
end

local function forget<T>(book: ConsumeFollowups<T>, index: number): ()
    table.remove(book.items, index)
    table.remove(book.notes, index)
    table.remove(book.ticks, index)
end

local function age_out<T>(book: ConsumeFollowups<T>): ()
    local oldest = sim.tick() - sim.tick_hz()
    while #book.ticks > 0 and book.ticks[1] < oldest do
        forget(book, 1)
    end
end

-- Note what `item`'s next consume should do once it lands. Call it beside
-- the `:consume()` it describes, in the same handler.
function consume_followups.expect<T>(book: ConsumeFollowups<T>, item: Handle, note: T): ()
    age_out(book)
    if #book.items >= CAPACITY then
        forget(book, 1)
    end
    table.insert(book.items, item)
    table.insert(book.notes, note)
    table.insert(book.ticks, sim.tick())
end

-- The oldest note for `item`, removed from the book, or nil when this
-- book expected no consume of it.
function consume_followups.settle<T>(book: ConsumeFollowups<T>, item: Handle): T?
    age_out(book)
    for index, expected in book.items do
        if expected == item then
            local note = book.notes[index]
            forget(book, index)
            return note
        end
    end
    return nil
end

return consume_followups
