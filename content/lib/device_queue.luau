-- One paced sender per address, bounded independently of guest work.
local device_queue = {}
function device_queue.clear(device)
    device.vars["device_outbox"] = nil
end
function device_queue.send(device, payload)
    local queue = device.vars["device_outbox"] or {}
    if #queue >= 4 then return false end
    table.insert(queue, payload)
    device.vars["device_outbox"] = queue
    if device.vars["device_sending"] then return true end
    device.vars["device_sending"] = true
    sim.spawn_task(device, function()
        while device.alive do
            local pending = device.vars["device_outbox"] or {}
            if #pending == 0 then break end
            local first = table.remove(pending, 1)
            device.vars["device_outbox"] = pending
            sim.link.emit({ subject = device, payload = first })
            -- Six ticks leaves headroom below the four-per-second native cap.
            sim.sleep(sim.ticks(0.3))
        end
        if device.alive then device.vars["device_sending"] = nil end
    end)
    return true
end
local function batch(device, kind, event)
    local queue = device.vars["device_outbox"] or {}
    for _, packet in ipairs(queue) do
        if packet.kind == kind then
            if #packet.events >= 16 then return false end
            table.insert(packet.events, event)
            device.vars["device_outbox"] = queue
            return true
        end
    end
    return device_queue.send(device, { kind = kind, events = { event } })
end
function device_queue.button(device, request)
    return batch(device, "buttons", request)
end
function device_queue.completion(device, event)
    return batch(device, "completions", event)
end
return device_queue
