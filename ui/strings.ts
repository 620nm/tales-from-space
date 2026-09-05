// Every English word this package writes, in one module. A catalog swap
// replaces this file; nothing else in `ui/` spells a player-facing word.
// Server-authored words arrive through `labels.ts` instead.
import type { Json } from "@lunatic/ui";

export const CLOSE = "Close";
export const CLOSE_MARK = "✕";

// Lobby and the body a session is left with.
export const LOBBY_TITLE = "Crew manifest";
export const LOBBY_HINT = "Choose a role to board the station.";
export const LOBBY_UNLIMITED = "aboard";
export const RESPAWN = "Respawn";
export const BODY_TITLE = "Condition";

// Comms.
export const CHAT_TITLE = "Comms";
export const CHAT_EMPTY = "Nothing heard yet.";

// The tray.
export const HANDS = "Hands";
export const WORN = "Worn";
export const EMPTY = "empty";
export const ACTIONS = "Actions";
export const SWAP = "Swap";
export const DROP = "Drop";
export const USE = "Use";
export const USE_OTHER = "Use on other";
export const EQUIP = "Equip";
export const THROW = "Throw";
export const THROWING = "Throwing";
export const BUILD = "Build";
export const OPEN = "Open";
export const STORAGE = "Contents";
export const STORE_HELD = "Stow held";
export const TAKE_OFF = "Take off";
export const VITALS = "Vitals";
export const TARGET = "Target";

// Looking.
export const TILE_TITLE = "On this tile";
export const EXAMINE_TITLE = "Examine";

// Documents.
export const NO_FILE_OPEN = "No file open";
export const MEDIA = "Media";
export const MEDIA_EMPTY = "empty";
export const EJECT = "Eject";
export const COPY = "Copy";
export const DELETE = "Delete";
export const RENAME = "Rename";
export const SAVE = "Save";
export const REVERT = "Revert";
export const MODIFIED = "modified";
export const CONFLICT =
  "This file changed while you were editing. Revert to load the current version.";
export const STOCK = "Stock";
export const VEND = "Vend";
export const HAVE = "have";
export const COST = "cost";
export const ARM = "Arm";
export const ARMED = "Armed";
export const SEALED = "sealed";
export const OPEN_SHELL = "open";
export const SHELL = "Shell";
export const HEADSPACE = "Headspace";
export const TEMPERATURE = "Temperature";
export const SET = "Set";
export const LOWER = "−";
export const RAISE = "+";

export const hand = (index: number): string => `Hand ${index + 1}`;
export const newFile = (ext: string): string => `New .${ext}`;
export const fileName = (name: string, ext: string): string => `${name}.${ext}`;
export const bytes = (size: number): string => `${size} B`;
export const storeUse = (
  used: number,
  capacity: number,
  count: number,
  cap: number,
): string => `${used} / ${capacity} B · ${count} / ${cap}`;
export const jobCount = (taken: number, slots: number | null): string =>
  slots === null ? `${taken} ${LOBBY_UNLIMITED}` : `${taken} / ${slots}`;
export const recipeCost = (have: number, cost: number, secs: number): string =>
  `${HAVE} ${have} · ${COST} ${cost} · ${secs}s`;
export const range = (min: string, max: string, unit: string): string =>
  `${min} – ${max}${unit ? ` ${unit}` : ""}`;
export const channel = (name: string): string => `[${name}]`;
export const speaker = (name: string): string => `${name}:`;

// The English behind a server label id, until the catalog owns them
// (CONTRACT §I2). An id nothing here spells falls back to itself, so a
// new module reads as its own key rather than as a blank row.
const MODULE_LABELS: Record<string, string> = {
  "battery.capacity": "capacity",
  "battery.state": "state",
  "battery.stored": "stored",
  "battery.supply": "supply",
  "canister.port": "port",
  "canister.regulator": "regulator",
  "canister.release_valve": "release valve",
  "channels.alarm": "alarm",
  "channels.main_breaker": "main breaker",
  "dock.vessel": "vessel",
  "dock.eject": "eject",
  "filter.transfer_rate": "transfer rate",
  "flow.gate_temperature": "gate temperature",
  "flow.heat_transfer": "heat transfer",
  "flow.limiters": "limiters",
  "flow.room": "room",
  "flow.sensor": "sensor",
  "flow.supply": "supply",
  "flow.transfer_rate": "transfer rate",
  "held_tank.internals": "internals",
  "held_tank.release_pressure": "release pressure",
  "holder.rating": "rating",
  "holder.supply": "supply",
  "link.address": "address",
  "link.lock": "lock",
  "link.state": "state",
  "meter.pipe": "pipe",
  "mint.amount": "amount",
  "mint.contents": "contents",
  "mixer.back_intake": "back intake",
  "mixer.mix": "mix",
  "mixer.output": "output",
  "parts.parts": "parts",
  "reach.reach": "reach",
  "room_device.power": "power",
  "room_device.room": "room",
  "room_device.supply": "supply",
  "scrubber.roster": "roster",
  "scrubber.scrub_rate": "scrub rate",
  "scrubber.stop_at": "stop at",
  "thermo.pipe": "pipe",
  "thermo.power": "power",
  "thermo.pressure": "pressure",
  "thermo.supply": "supply",
  "thermo.thermostat": "thermostat",
  "thermostat.power": "power",
  "thermostat.supply": "supply",
  "thermostat.temperature": "temperature",
  "thermostat.thermostat": "thermostat",
  "thermostat.vessel": "vessel",
  "trinary.power": "power",
  "vent.empty_over": "empty over",
  "vent.feed_under": "feed under",
  "vent.hold_at": "hold at",
  "state.on": "on",
  "state.off": "off",
};

// `{name}` placeholders only, as the catalog templates use.
export function moduleLabel(
  id: string,
  args?: Record<string, Json> | null,
): string {
  const template = MODULE_LABELS[id] ?? id;
  if (!args) return template;
  return template.replace(/\{([a-z0-9_]{1,64})\}/g, (whole, key: string) => {
    const value = args[key];
    return value === undefined || value === null ? whole : String(value);
  });
}
