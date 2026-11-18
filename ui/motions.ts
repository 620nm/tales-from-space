import { defineMotions } from "@lunatic/ui";

export default defineMotions([
  {
    name: "speech-spawn",
    durationMs: 200,
    curve: "linear",
    from: { opacity: 0, translate: { x: 0, y: 8 } },
    to: { opacity: 1, translate: { x: 0, y: 0 } },
  },
]);
