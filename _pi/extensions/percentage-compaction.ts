import type { ExtensionAPI, ExtensionContext, SessionBeforeCompactEvent } from "@mariozechner/pi-coding-agent";

// Configure your threshold here (0-100)
const COMPACTION_THRESHOLD_PERCENT = 60;
const PI_VCC_MANUAL_BYPASS_MARKER = "__PI_VCC_MANUAL_BYPASS__";
let warnedAtThreshold = false;
let allowNextManualCompaction = false;

export default function (pi: ExtensionAPI) {
  const triggerManualCompaction = (ctx: ExtensionContext, customInstructions?: string) => {
    allowNextManualCompaction = true;
    ctx.ui.notify("Compacting context...", "info");
    ctx.compact({
      customInstructions,
      onComplete: () => {
        allowNextManualCompaction = false;
        ctx.ui.notify("Compaction complete", "info");
      },
      onError: (err: Error) => {
        allowNextManualCompaction = false;
        ctx.ui.notify(`Compaction failed: ${err.message}`, "error");
      },
    });
  };

  // Register /compact-now command for manual triggering
  pi.registerCommand("compact-now", {
    description: "Trigger compaction immediately with optional custom instructions",
    handler: async (args, ctx: ExtensionContext) => {
      const customInstructions = args.trim() || undefined;
      triggerManualCompaction(ctx, customInstructions);
    },
  });

  // Register /compact-status command to check current usage
  pi.registerCommand("compact-status", {
    description: "Show current context usage percentage",
    handler: async (_args, ctx: ExtensionContext) => {
      const usage = ctx.getContextUsage();
      if (!usage || usage.percent === null) {
        ctx.ui.notify("Context usage: unknown", "warning");
        return;
      }
      ctx.ui.notify(
        `Context: ${Math.floor(usage.percent)}% of ${usage.contextWindow.toLocaleString()} tokens ` +
        `(threshold: ${COMPACTION_THRESHOLD_PERCENT}%)`,
        "info"
      );
    },
  });

  // Monitor context usage on each message
  pi.on("message_end", async (_event, ctx: ExtensionContext) => {
    const usage = ctx.getContextUsage();
    if (!usage || usage.percent === null) return;
    
    const currentPercent = Math.floor(usage.percent);
    const threshold = COMPACTION_THRESHOLD_PERCENT;
    
    // Warn once when crossing threshold
    if (currentPercent >= threshold && !warnedAtThreshold) {
      warnedAtThreshold = true;
      ctx.ui.notify(
        `⚠️ Context at ${currentPercent}% (threshold: ${threshold}%). ` +
        `Run /compact-now to compact.`, 
        "warning"
      );
    }
    
    // Reset warning if we drop below (e.g., after compaction)
    if (currentPercent < threshold) {
      warnedAtThreshold = false;
    }
  });

  // Intercept auto-compaction - gate by threshold
  // Let pi-vcc handle the actual compaction when threshold is reached
  pi.on("session_before_compact", async (event: SessionBeforeCompactEvent, ctx: ExtensionContext) => {
    const usage = ctx.getContextUsage();
    if (!usage || usage.percent === null) return;

    const manualPiVccBypass = event.customInstructions?.startsWith(PI_VCC_MANUAL_BYPASS_MARKER) ?? false;
    if (allowNextManualCompaction || manualPiVccBypass) {
      allowNextManualCompaction = false;
      ctx.ui.notify(
        `✓ Manual compaction bypassed ${COMPACTION_THRESHOLD_PERCENT}% threshold at ${Math.floor(usage.percent)}%`,
        "info"
      );
      return;
    }
    
    // If below threshold, cancel and wait
    if (usage.percent < COMPACTION_THRESHOLD_PERCENT) {
      ctx.ui.notify(
        `⏸️ Delayed auto-compaction: ${Math.floor(usage.percent)}% < ${COMPACTION_THRESHOLD_PERCENT}% threshold`, 
        "info"
      );
      return { cancel: true };
    }
    
    // At or above threshold - allow compaction to proceed (pi-vcc will handle it)
    ctx.ui.notify(
      `✓ Auto-compacting at ${Math.floor(usage.percent)}% (threshold: ${COMPACTION_THRESHOLD_PERCENT}%)`, 
      "info"
    );
    // Return nothing - let pi-vcc or default compaction handle the actual compaction
  });
}
