// The HUD package's stylesheet, assembled from `ui/theme/`: the kit
// drawn with the station's roles and the shared chrome (`kit.ts`), then
// the gameplay sheet's own surfaces. Class names outside the kit's
// vocabulary are this pack's (docs/pack-ui/components.md); the overlay
// package assembles its own sheet in `overlay/styles.ts`.
import type { UiStyleRule } from "@lunatic/ui";
import { defineStyles } from "@lunatic/ui";
import { kitRules } from "./theme/kit";
import { hudRules } from "./theme/hud";
import { surfaceRules } from "./theme/surfaces";
import { documentRules } from "./theme/documents";
import { workspaceRules } from "./theme/workspace";

export default defineStyles([
  ...kitRules,
  ...hudRules,
  ...surfaceRules,
  ...documentRules,
  ...workspaceRules,
] as UiStyleRule[]);
