import type { Json } from "@lunatic/ui";
import type { Label } from "./labels";

// Consumed document fields: lunatic crates/lunatic-server/src/sim/ui/settings.rs
// (`to_json`, `push_json`), ui/settings/files.rs, ui/vending.rs, build.rs and
// crates/lunatic-core/src/protocol/matter.rs; docs/tgui/documents.md.
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

/** The LAYOUT a module list asks for; never a renderer, never an act. */
export type Presentation =
  | "modules"
  | "shelf"
  | "visual_choices"
  | "choices"
  | "panes";

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
export interface Readout {
  section?: Label;
  label: Label;
  value: Json;
  tone?: string | null;
}
export interface Toggle {
  label: Label;
  on: boolean;
  on_text: Label;
  off_text: Label;
  field: string;
  option?: string | null;
  icon?: string | null;
  group?: string | null;
  color?: string | null;
  section?: Label;
}
export type LabelRow = { section?: Label } & (
  | {
      row: "press";
      label: Label;
      text: Label;
      field: string;
      option?: string | null;
      enabled: boolean;
    }
  | { row: "input"; label: Label; text?: Label; action: string; max_length?: number }
  | { row: "word"; label: Label; text: Label }
);
export interface Setpoint {
  label: Label;
  unit: string;
  value: number;
  field: string;
  min: number;
  max: number;
  step?: number;
  decimals?: number;
  section?: Label;
}
export interface Product {
  sprite?: string | null;
  category?: string | null;
  label: Label;
  stock: number;
  act: string;
  payload: Json;
}
export interface ModuleState {
  document: "modules";
  status?: number;
  presentation?: Presentation;
  name?: string;
  notice?: Label;
  gauge?: number | null;
  readouts?: Readout[];
  toggles?: Toggle[];
  labels?: LabelRow[];
  setpoints?: Setpoint[];
  products?: Product[];
  matter?: MatterBlock[];
  stores?: StoreRow[];
  media_slot?: string | null;
  files?: FileRow[];
  create?: string[];
  open?: OpenFile | null;
}
export type MatterPhase = "gas" | "liquid" | "solid";
export interface MatterRow {
  key: string;
  name: string;
  color?: string | null;
  moles: number;
  measure: number;
  mass_g: number;
}
export interface MatterStateBlock {
  phase: MatterPhase;
  moles: number;
  measure: number;
  mass_g: number;
  rows?: MatterRow[];
}
export interface MatterBlock {
  section: string;
  volume_l: number;
  headspace_l: number;
  temperature_k: number;
  sealed?: boolean | null;
  states?: MatterStateBlock[];
}
export interface StoreRow {
  key?: string;
  label: Label;
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
  open?: boolean;
}
export interface OpenFile {
  store: string;
  uid: number;
  name: string;
  ext: string;
  body: string;
  revision: number;
  cap?: number;
}
