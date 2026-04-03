/**
 * Simple Multi-Line Status Extension for pi
 *
 * A lightweight alternative that shows all stats in a multi-line widget
 * below the input box. No commands needed - just enable and it works.
 *
 * To use:
 *   pi -e ./simple-multi-status.ts
 *
 * Or install to ~/.pi/agent/extensions/ for auto-loading.
 */

import type { AssistantMessage } from "@mariozechner/pi-ai";
import type { ExtensionAPI, ExtensionContext, ReadonlyFooterDataProvider } from "@mariozechner/pi-coding-agent";
import { truncateToWidth } from "@mariozechner/pi-tui";

const WIDGET_ID = "simple-status";
const MULTICODEX_STATUS_KEY = "multicodex-usage";
const MULTI_PASS_STATUS_KEY = "multi-pass";

function fmtNumber(n: number): string {
	if (n < 1000) return `${n}`;
	if (n < 1_000_000) return `${(n / 1000).toFixed(1)}k`;
	return `${(n / 1_000_000).toFixed(2)}M`;
}

function getStats(ctx: ExtensionContext) {
	let inputTokens = 0;
	let outputTokens = 0;
	let cacheRead = 0;
	let cacheWrite = 0;
	let cost = 0;

	for (const e of ctx.sessionManager.getBranch()) {
		if (e.type === "message" && e.message.role === "assistant") {
			const m = e.message as AssistantMessage;
			inputTokens += m.usage.input;
			outputTokens += m.usage.output;
			cost += m.usage.cost.total;
			if (m.usage.cacheRead) cacheRead += m.usage.cacheRead;
			if (m.usage.cacheWrite) cacheWrite += m.usage.cacheWrite;
		}
	}

	return { inputTokens, outputTokens, cacheRead, cacheWrite, cost };
}

function getCodexStatusLine(
	footerData: ReadonlyFooterDataProvider | null,
	width: number,
): string | null {
	const statuses = footerData?.getExtensionStatuses();
	if (!statuses || statuses.size === 0) return null;

	const status =
		statuses.get(MULTICODEX_STATUS_KEY) ??
		statuses.get(MULTI_PASS_STATUS_KEY) ??
		Array.from(statuses.entries()).find(([key]) => key.includes("multicodex") || key.includes("multi-pass"))?.[1] ??
		null;
	if (!status) return null;

	return truncateToWidth(status, Math.max(1, width), "");
}

function buildLines(
	ctx: ExtensionContext,
	width: number,
	footerData: ReadonlyFooterDataProvider | null,
): string[] {
	const theme = ctx.ui.theme;
	const model = ctx.model;
	const { inputTokens, outputTokens, cacheRead, cacheWrite, cost } = getStats(ctx);
	const usage = ctx.getContextUsage();

	const lines: string[] = [];

	// Horizontal separator above model (separator between input and status)
	const separator = theme.fg("dim", "─".repeat(Math.max(1, width - 2)));
	lines.push(separator);

	// Line 1: Model
	const modelStr = model
		? `${model.provider}/${model.id}`
		: "no-model";
	lines.push(theme.fg("accent", modelStr));

	// Line 2: Tokens
	let tokenLine = `Tokens: ↑${fmtNumber(inputTokens)} ↓${fmtNumber(outputTokens)}`;
	if (cacheRead > 0 || cacheWrite > 0) {
		tokenLine += ` · cache r:${fmtNumber(cacheRead)} w:${fmtNumber(cacheWrite)}`;
	}
	tokenLine += ` · $${cost.toFixed(3)}`;
	lines.push(theme.fg("dim", tokenLine));

	// Line 3: Codex usage on its own dedicated row
	const codexStatusLine = getCodexStatusLine(footerData, width);
	if (codexStatusLine) {
		lines.push(codexStatusLine);
	}

	// Next line: Context usage (tokens / total window)
	let contextStr: string;
	if (usage && model) {
		const pct = Math.round((usage.tokens / model.contextWindow) * 100);
		contextStr = `Context: ${fmtNumber(usage.tokens)} / ${fmtNumber(model.contextWindow)} (${pct}%)`;
	} else {
		contextStr = "Context: --";
	}

	lines.push(theme.fg("dim", contextStr));

	// Line 4: Working directory (shortened)
	const home = process.env.HOME || "/home/user";
	const cwd = ctx.cwd.startsWith(home) ? `~${ctx.cwd.slice(home.length)}` : ctx.cwd;
	lines.push(theme.fg("dim", cwd));

	return lines;
}

function updateWidget(
	ctx: ExtensionContext,
	getFooterData: () => ReadonlyFooterDataProvider | null,
): void {
	if (!ctx.hasUI) return;

	ctx.ui.setWidget(
		WIDGET_ID,
		(_tui, _theme) => ({
			render: (w: number) => buildLines(ctx, w, getFooterData()),
			invalidate: () => {},
		}),
		{ placement: "belowEditor" }
	);
}

export default function (pi: ExtensionAPI): void {
	let footerDataRef: ReadonlyFooterDataProvider | null = null;
	// Initialize on session start
	pi.on("session_start", async (_event, ctx) => {
		// Hide the default footer to avoid duplication, but keep footerData access
		ctx.ui.setFooter((_tui, _theme, footerData) => {
			footerDataRef = footerData;
			return {
				render: () => [],
				invalidate: () => {},
				dispose: () => {
					if (footerDataRef === footerData) footerDataRef = null;
				},
			};
		});
		updateWidget(ctx, () => footerDataRef);
	});

	// Update after each turn (when stats change)
	pi.on("turn_end", async (_event, ctx) => {
		updateWidget(ctx, () => footerDataRef);
	});

	// Update when model changes
	pi.on("model_select", async (_event, ctx) => {
		updateWidget(ctx, () => footerDataRef);
	});

}
