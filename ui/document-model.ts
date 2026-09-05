import type { Json } from "@lunatic/ui";

// Consumed document fields: lunatic crates/lunatic-server/src/sim/ui/settings.rs,
// ui/settings/files.rs, ui/vending.rs, build.rs; docs/PACK-UI.md.
export interface DocumentIdentity {
  id: number;
  generation: number;
  title: string;
}
// A provider writes `state`; every reader here treats it as absent or
// incomplete rather than trusting the shape below.
export type PanelDocument = DocumentIdentity & {
  state?: Partial<DocumentState>;
};
export type DocumentState = BuildState | ScriptState | ModuleState;
export interface BuildState {
  document: "build";
  status?: number;
  recipes: {
    sprite?: string | null;
    label: string;
    have: number;
    cost: number;
    secs: number;
  }[];
}
export interface ScriptState {
  document: "script";
  status?: number;
  data: Json;
  actions: { id: string; input: number }[];
}
export type LabelRow =
  | {
      row: "press";
      label: string;
      text: string;
      field: string;
      option?: string | null;
      enabled: boolean;
    }
  | { row: "input"; label: string; action: string }
  | { row: "word"; label: string; text: string };
export interface ModuleState {
  document: "modules";
  status?: number;
  notice?: string | null;
  gauge?: number | null;
  readouts?: { section?: string | null; label: string; value: Json }[];
  toggles?: {
    label: string;
    on: boolean;
    on_text: string;
    off_text: string;
    field: string;
    option?: string | null;
  }[];
  labels?: LabelRow[];
  setpoints?: {
    label: string;
    unit: string;
    value: number;
    field: string;
    min: number;
    max: number;
  }[];
  products?: {
    sprite?: string | null;
    category?: string | null;
    label: string;
    stock: number;
    act: string;
    payload: Json;
  }[];
  matter?: Json;
  stores?: StoreRow[];
  media_slot?: string | null;
  files?: FileRow[];
  create?: string[];
  open?: OpenFile | null;
}
export interface StoreRow {
  label: string;
  used: number;
  capacity: number;
  count: number;
  count_cap: number;
}
export interface FileRow {
  store: string;
  uid: number;
  name: string;
  ext: string;
  size: number;
}
export interface OpenFile {
  store: string;
  uid: number;
  name: string;
  ext: string;
  body: string;
  revision: number;
}
