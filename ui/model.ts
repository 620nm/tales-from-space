import type { Json } from "@lunatic/ui";
import type { PanelDocument } from "./document-model";

// Consumed projections: lunatic crates/lunatic-client/src/ui/mod.rs and
// crates/lunatic-core/src/protocol/{messages,types}.rs; docs/PACK-UI.md.
// Compile-time shapes, never runtime validators: every reader here
// treats a field as absent rather than trusting it.
export interface ItemFill {
  sprite: string;
  color: string;
  percent?: number;
}
export interface ItemView {
  name: string;
  sprite: string;
  fill?: ItemFill | null;
}
export interface EquipmentSlot {
  id: string;
  label: string;
  quick_store: boolean;
}
export interface InventoryState {
  active: number;
  hands: (ItemView | null)[];
  held: (ItemView[] | null)[];
  equipment: {
    slot: number;
    item: ItemView | null;
    contents: ItemView[] | null;
  }[];
}
export interface TargetZone {
  id: string;
  label: string;
  /** `[x, y, w, h]` in the unit square of the figure. */
  rect?: [number, number, number, number] | null;
  sprite?: string | null;
  slot?: number | null;
}
export interface LogLine {
  kind?: string | null;
  channel?: string | null;
  name?: string;
  text: string;
}
export interface GameplayView {
  body: boolean;
  documents?: Record<string, PanelDocument>;
  log?: LogLine[];
  state: {
    jobs?: {
      jobs: {
        key: string;
        name: string;
        taken: number;
        slots: number | null;
      }[];
    };
    bodyStatus?: {
      state: { controllable: boolean; animate: boolean; label: string };
      can_respawn: boolean;
    };
    inventory?: InventoryState;
    equipment?: { slots: EquipmentSlot[] };
    targets?: { base?: string | null; zones: TargetZone[] };
    target?: { zone: number };
    throwing?: boolean;
    identity?: { you: number | null; name: string };
    vitals?: { values: { slot: number; value?: number }[] };
    readouts?: { slots: { label: string; suffix?: string }[] };
    armed?: number;
    examine?: {
      sprite?: string | null;
      title: string;
      lines: { spans: { text: string; color?: string | null }[] }[];
    };
    context?: { sprite?: string | null; name: string; target: Json }[];
    progress?: { job: number; sequence: number; ms: number }[];
    speech?: {
      id: number;
      sequence: number;
      channel?: string | null;
      text: string;
    }[];
  };
}
