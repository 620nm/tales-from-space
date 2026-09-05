// Every word this package writes, as the catalog key it comes out of.
// The words live in `locale/<tag>.json`; an unrendered key answers with
// itself, which is visible rather than blank
// (docs/localization/catalogs.md). Server-authored words arrive through
// `labels.ts` instead.
import { scoped } from "@lunatic/ui";

/** This mod's namespace, bound once: `tfs("ui.tray.drop")`. */
export const tfs = scoped("lunatic/tfs");

export const CLOSE_MARK = tfs("ui.chrome.close_mark");

// Lobby and the body a session is left with.
export const LOBBY_TITLE = tfs("ui.lobby.title");
export const LOBBY_HINT = tfs("ui.lobby.hint");
export const RESPAWN = tfs("ui.lobby.respawn");
export const BODY_TITLE = tfs("ui.lobby.condition");

// Comms.
export const CHAT_TITLE = tfs("ui.comms.title");
export const CHAT_EMPTY = tfs("ui.comms.empty");

// The tray.
export const HANDS = tfs("ui.tray.hands");
export const WORN = tfs("ui.tray.worn");
export const SWAP = tfs("ui.tray.swap");
export const DROP = tfs("ui.tray.drop");
export const USE = tfs("ui.tray.use");
export const USE_OTHER = tfs("ui.tray.use_other");
export const EQUIP = tfs("ui.tray.equip");
export const THROW = tfs("ui.tray.throw");
export const THROWING = tfs("ui.tray.throwing");
export const BUILD = tfs("ui.tray.build");
export const OPEN = tfs("ui.tray.open");
export const STORAGE = tfs("ui.tray.storage");
export const STORE_HELD = tfs("ui.tray.store_held");
export const TAKE_OFF = tfs("ui.tray.take_off");
export const TARGET = tfs("ui.tray.target");

// Looking.
export const TILE_TITLE = tfs("ui.look.tile");
export const NOTHING_MORE = tfs("ui.look.nothing_more");

// Documents.
export const NO_FILE_OPEN = tfs("ui.files.none_open");
export const MEDIA = tfs("ui.files.media");
export const MEDIA_EMPTY = tfs("ui.files.media_empty");
export const EJECT = tfs("ui.files.eject");
export const COPY = tfs("ui.files.copy");
export const DELETE = tfs("ui.files.delete");
export const RENAME = tfs("ui.files.rename");
export const SAVE = tfs("ui.files.save");
export const REVERT = tfs("ui.files.revert");
export const CONFLICT = tfs("ui.files.conflict");
export const STOCK = tfs("ui.shelf.stock");
export const VEND = tfs("ui.shelf.vend");
export const ARM = tfs("ui.shelf.arm");
export const ARMED = tfs("ui.shelf.armed");
export const SEAL = tfs("ui.matter.seal");
export const SEALED = tfs("ui.matter.sealed");
export const OPEN_SHELL = tfs("ui.matter.open");
export const SHELL = tfs("ui.matter.shell");
export const HEADSPACE = tfs("ui.matter.headspace");
export const TEMPERATURE = tfs("ui.matter.temperature");
export const SET = tfs("ui.module.set");
export const LOWER = tfs("ui.module.lower");
export const RAISE = tfs("ui.module.raise");

export const hand = (index: number): string =>
  tfs("ui.tray.hand", { index: index + 1 });
// A 40px square holds one short word. A wrapped name climbs over the
// sprite it belongs to, so the tray cuts rather than wraps.
export const short = (text: string, limit = 10): string =>
  text.length > limit ? `${text.slice(0, limit - 1)}…` : text;
export const storageTitle = (label: string): string =>
  tfs("ui.tray.storage_of", { label });
export const newFile = (ext: string): string => tfs("ui.files.new", { ext });
export const fileName = (name: string, ext: string): string =>
  tfs("ui.files.name", { name, ext });
export const fileTitle = (name: string, ext: string, dirty: boolean): string =>
  tfs(dirty ? "ui.files.name_modified" : "ui.files.name", { name, ext });
export const bytes = (size: number): string => tfs("ui.files.bytes", { size });
export const storeUse = (
  used: number,
  capacity: number,
  count: number,
  cap: number,
): string => tfs("ui.files.store_use", { used, capacity, count, cap });
export const jobCount = (taken: number, slots: number | null): string =>
  slots === null
    ? tfs("ui.lobby.jobs_unlimited", { taken })
    : tfs("ui.lobby.jobs", { taken, slots });
export const recipeCost = (have: number, cost: number, secs: number): string =>
  tfs("ui.shelf.recipe", { have, cost, secs });
export const range = (min: string, max: string, unit: string): string =>
  unit
    ? tfs("ui.module.range_unit", { min, max, unit })
    : tfs("ui.module.range", { min, max });
export const channel = (name: string): string =>
  tfs("ui.comms.channel", { name });
export const speaker = (name: string): string =>
  tfs("ui.comms.speaker", { name });

// The contents block's phase headings and rows: one authored template
// each, never a word joined to a reading (docs/LOCALIZATION.md §5).
export const gasHeading = (reading: string, amount: string): string =>
  tfs("ui.matter.gas", { reading, amount });
export const liquidHeading = (reading: string): string =>
  tfs("ui.matter.liquid", { reading });
export const solidHeading = (mass: string, reading: string): string =>
  mass
    ? tfs("ui.matter.solid", { mass, reading })
    : tfs("ui.matter.solid_bare", { reading });
export const matterRow = (
  mass: string,
  reading: string,
  amount: string,
): string =>
  mass
    ? tfs("ui.matter.row_weighed", { mass, reading, amount })
    : tfs("ui.matter.row", { reading, amount });
