-- AIRLOCK: learns home by tasting air, never by place.
-- Runs per knock, press, door, pressure.
-- event is the report; devices the joined gear.
-- local names a value; { ... } groups them.
local function permitted(request)
 -- Next line to: return request.engineering
 return true
end
local cmds = {}
local result = { commands = cmds }
-- mem: one arg reads, two save.
local st = mem("cy")
local sv = mem("sv")
-- Queue one bid. mac is the address.
local function send(mac, op, settings)
 local ins = settings or {}
 ins.mac, ins.op, ins.id = mac, op, st.id .. ":" .. st.phase
 table.insert(cmds, ins)
end
local function save()
 mem("cy", st)
 return result
end
-- Halt the fan; never trust a stuck leaf.
local function fault()
 for _, d in ipairs(devices) do
  if d.kind == "vent" then
   send(d.mac, "vent", { on = false })
  end
 end
 st.phase = "fault"
 result.status = "fault"
 result.timer = false
 return save()
end
-- Home: 85 heavy, 16 rich, 253-323 warm, no harm.
local function home(r)
 return type(r) == "table" and r.hazard == "none" and (r.kpa or 0) >= 85
  and (r.breathKpa or 0) >= 16 and (r.tempK or 0) >= 253.15 and (r.tempK or 0) <= 323.15
end
-- Leaf: 0 lost, 1 out, 2 home. Thin, foul, cold read out.
local function side(leaf)
 if type(leaf) ~= "table" or type(leaf.air) ~= "table" then
  return 0
 end
 local a, live, found = leaf.air, false, false
 for _, k in ipairs({ "n", "s", "e", "w" }) do
  local s = a[k]
  if s ~= nil then
   live = true
   if home(s) then
    found = true
   end
  end
 end
 if not live then
  return 0
 end
 return found and 2 or 1
end
-- Read the room. ipairs walks; #counts. Both out seals.
local function look(btn)
 local v, ds, bs, hit = nil, {}, 0, btn == nil
 for _, d in ipairs(devices) do
  if d.kind == "vent" then
   if v ~= nil or d.class ~= "atmos" then
    return nil
   end
   v = d
  elseif d.kind == "door" then
   if d.class ~= "atmos" or type(d.door) ~= "table" then
    return nil
   end
   table.insert(ds, d)
  elseif d.kind == "button" then
   if d.class ~= "control_button" then
    return nil
   end
   bs += 1
   if d.mac == btn then
    hit = true
   end
  else
   return nil
  end
 end
 if v == nil or #ds ~= 2 or bs ~= 2 or not hit then
  return nil
 end
 local x, y = side(ds[1]), side(ds[2])
 if x == 0 or y == 0 then
  return nil
 end
 if x == 1 and y == 1 then
  return { mode = "sealed" }
 end
 if x == 2 and y == 2 then
  table.sort(ds, function(p, q)
   return p.mac < q.mac
  end)
  return { mode = "interlock", vent = v, a = ds[1], b = ds[2] }
 end
 if x == 2 then
  return { mode = "pump", vent = v, station = ds[1], other = ds[2] }
 end
 return { mode = "pump", vent = v, station = ds[2], other = ds[1] }
end
-- Bid both shut and latch; the latch is the failsafe.
local function seal()
 for _, d in ipairs(devices) do
  if d.kind == "door" then
   send(d.mac, "bolt", { bolted = false })
   send(d.mac, "close")
   send(d.mac, "emergency", { emergency = true })
  end
 end
 sv = { mode = "sealed" }
 mem("sv", sv)
 st.phase = "sealed"
 result.status = "failsafe"
 result.replace = true
 result.timer = false
 return save()
end
-- FIRST KNOCK: learn now, or on first press.
if event.kind == "boot" then
 if event.origin ~= "map" and event.origin ~= "built" then
  return result
 end
 st = st or { id = "boot", phase = "idle" }
 local f = look()
 if f == nil then
  return result
 end
 if f.mode == "sealed" then
  return seal()
 end
 sv = f.mode == "pump" and { mode = "pump", station = f.station.mac, other = f.other.mac }
  or { mode = "interlock", a = f.a.mac, b = f.b.mac }
 mem("sv", sv)
 st.phase = "idle"
 result.status = "idle"
 result.timer = false
 return save()
end
-- Sealed hears engineers.
if sv ~= nil and sv.mode == "sealed" then
 if event.kind ~= "button" then
  return result
 end
 if look(event.mac) == nil then
  return result
 end
 if not event.engineering or not permitted(event) then
  return { commands = {}, status = "denied", accepted = false }
 end
 -- Idle, timerless: stray reports answer nothing.
 st = { id = "reset", phase = "idle" }
 for _, d in ipairs(devices) do
  if d.kind == "door" then
   send(d.mac, "emergency", { emergency = false })
  end
 end
 mem("sv", nil)
 sv = nil
 result.status = "working"
 result.replace = true
 result.accepted = true
 result.timer = false
 return save()
end
-- BUTTON PRESS: shut far, open near.
if event.kind == "button" then
 if not permitted(event) then
  return { commands = {}, status = "denied", accepted = false }
 end
 local n = (mem("gen") or 0) + 1
 mem("gen", n)
 st = { id = tostring(n), phase = "close" }
 local f = look(event.mac)
 if f == nil then
  return fault()
 end
 if f.mode == "sealed" then
  return seal()
 end
 -- Kept: a full room tastes home. Seal reads fresh.
 if sv == nil then
  sv = f.mode == "pump" and { mode = "pump", station = f.station.mac, other = f.other.mac }
   or { mode = "interlock", a = f.a.mac, b = f.b.mac }
  mem("sv", sv)
 end
 -- First in; next the other way.
 local inward = mem("last") ~= true
 mem("last", inward)
 local cm, om = sv.station, sv.other
 if sv.mode ~= "pump" then
  cm, om = sv.a, sv.b
 end
 if inward then
  cm, om = om, cm
 end
 local closing = (f.mode == "pump" and ((cm == f.station.mac) and f.station or f.other))
  or ((cm == f.a.mac) and f.a or f.b)
 st.vent, st.close, st.open = f.vent.mac, cm, om
 st.inward, st.mode = inward, sv.mode
 send(st.vent, "vent", { on = false })
 if closing.door.moving then
  st.phase = "wait_close"
 else
  send(st.close, "bolt", { bolted = false })
  send(st.close, "close")
 end
 result.status = "working"
 result.replace = true
 result.accepted = true
 result.timer = { id = st.id, ticks = 600 }
 return save()
end
if not st then
 return result
end
if event.kind == "timeout" then
 if event.id == st.id then
  return fault()
 end
 return result
end
-- Press mid-swing waits, then shuts.
if st.phase == "wait_close" and event.kind == "door" and event.mac == st.close then
 for _, d in ipairs(devices) do
  if d.mac == st.close and not d.door.moving then
   st.phase = "close"
   send(st.close, "bolt", { bolted = false })
   send(st.close, "close")
   return save()
  end
 end
 return result
end
-- This cycle and step only; strangers fault.
if event.kind == "door" or event.kind == "pressure" then
 local known = false
 for _, d in ipairs(devices) do
  if d.mac == event.mac then
   known = true
  end
 end
 if not known then
  return fault()
 end
end
if event.id ~= st.id .. ":" .. st.phase then
 return result
end
if st.phase == "fault" or st.phase == "idle" or st.phase == "sealed" then
 return result
end
if event.kind == "door" then
 local want = "set_bolted"
 if st.phase == "close" or st.phase == "open" then
  want = st.phase
  if event.operation == "set_bolted" then
   return result
  end
 end
 if event.operation ~= want then
  return fault()
 end
end
if not event.success then
 return fault()
end
local want_mac = st.close
if st.phase == "pressure" then
 want_mac = st.vent
elseif st.phase == "open" or st.phase == "bolt_open" then
 want_mac = st.open
end
if event.mac ~= want_mac then
 return fault()
end
-- STEPS: shut, secure, fill or drain, open, secure.
-- elseif takes first true. Both-breathing skips pumping.
if st.phase == "close" then
 st.phase = "bolt_close"
 send(st.close, "bolt", { bolted = true })
elseif st.phase == "bolt_close" then
 if st.mode == "interlock" then
  st.phase = "open"
  send(st.open, "bolt", { bolted = false })
  send(st.open, "open")
 else
  st.phase = "pressure"
  local dir, tgt, safe, cmp = "drain", 0, 10, "below"
  if st.inward then
   dir, tgt, safe, cmp = "fill", 101.325, 100, "at_least"
  end
  -- kPa. The watch calls when safe.
  send(st.vent, "vent", { on = true, direction = dir, target = tgt })
  send(st.vent, "watch", { target = safe, comparison = cmp, ticks = 500 })
 end
elseif st.phase == "pressure" then
 st.phase = "open"
 send(st.vent, "vent", { on = false })
 send(st.open, "bolt", { bolted = false })
 send(st.open, "open")
elseif st.phase == "open" then
 st.phase = "bolt_open"
 send(st.open, "bolt", { bolted = true })
elseif st.phase == "bolt_open" then
 st.phase = "idle"
 result.status = "idle"
 result.timer = false
end
return save()
