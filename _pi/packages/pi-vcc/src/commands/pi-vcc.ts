import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

const PI_VCC_MANUAL_BYPASS_MARKER = "__PI_VCC_MANUAL_BYPASS__";

export const registerPiVccCommand = (pi: ExtensionAPI) => {
  pi.registerCommand("pi-vcc", {
    description: "Compact conversation with pi-vcc structured summary",
    handler: async (_args, ctx) => {
      ctx.compact({
        customInstructions: PI_VCC_MANUAL_BYPASS_MARKER,
        onComplete: () => ctx.ui.notify("Compacted with pi-vcc", "info"),
        onError: (err) => {
          if (err.message === "Compaction cancelled" || err.message === "Already compacted") {
            ctx.ui.notify("Nothing to compact", "info");
          } else {
            ctx.ui.notify(`Compaction failed: ${err.message}`, "error");
          }
        },
      });
    },
  });
};
