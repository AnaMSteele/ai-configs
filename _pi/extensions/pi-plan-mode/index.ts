import { access } from "node:fs/promises";
import { isAbsolute, relative, resolve } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { Key } from "@mariozechner/pi-tui";

const PLAN_STATE_TYPE = "plan-mode-state";
const PLAN_ROOT = "thoughts";
const PLAN_DIRECTORY = "thoughts/plans";
const MAX_REVIEW_CYCLES = 3;

const DESTRUCTIVE_PATTERNS = [
	/\brm\b/i,
	/\brmdir\b/i,
	/\bmv\b/i,
	/\bcp\b/i,
	/\bmkdir\b/i,
	/\btouch\b/i,
	/\bchmod\b/i,
	/\bchown\b/i,
	/\bchgrp\b/i,
	/\bln\b/i,
	/\btee\b/i,
	/\btruncate\b/i,
	/\bdd\b/i,
	/\bshred\b/i,
	/(^|[^<])>(?!>)/,
	/>>/,
	/\bnpm\s+(install|uninstall|update|ci|link|publish)/i,
	/\byarn\s+(add|remove|install|publish)/i,
	/\bpnpm\s+(add|remove|install|publish)/i,
	/\bpip\s+(install|uninstall)/i,
	/\bapt(-get)?\s+(install|remove|purge|update|upgrade)/i,
	/\bbrew\s+(install|uninstall|upgrade)/i,
	/\bgit\s+(add|commit|push|pull|merge|rebase|reset|checkout|branch\s+-[dD]|stash|cherry-pick|revert|tag|init|clone)/i,
	/\bsudo\b/i,
	/\bsu\b/i,
	/\bkill\b/i,
	/\bpkill\b/i,
	/\bkillall\b/i,
	/\breboot\b/i,
	/\bshutdown\b/i,
	/\bsystemctl\s+(start|stop|restart|enable|disable)/i,
	/\bservice\s+\S+\s+(start|stop|restart)/i,
	/\b(vim?|nano|emacs|code|subl)\b/i,
];

const SAFE_BASH_PATTERNS = [
	/^\s*cat\b/,
	/^\s*head\b/,
	/^\s*tail\b/,
	/^\s*less\b/,
	/^\s*more\b/,
	/^\s*grep\b/,
	/^\s*find\b/,
	/^\s*ls\b/,
	/^\s*pwd\b/,
	/^\s*echo\b/,
	/^\s*printf\b/,
	/^\s*wc\b/,
	/^\s*sort\b/,
	/^\s*uniq\b/,
	/^\s*diff\b/,
	/^\s*file\b/,
	/^\s*stat\b/,
	/^\s*du\b/,
	/^\s*df\b/,
	/^\s*tree\b/,
	/^\s*which\b/,
	/^\s*whereis\b/,
	/^\s*type\b/,
	/^\s*env\b/,
	/^\s*printenv\b/,
	/^\s*uname\b/,
	/^\s*whoami\b/,
	/^\s*id\b/,
	/^\s*date\b/,
	/^\s*cal\b/,
	/^\s*uptime\b/,
	/^\s*ps\b/,
	/^\s*top\b/,
	/^\s*htop\b/,
	/^\s*free\b/,
	/^\s*git\s+(status|log|diff|show|branch|remote|config\s+--get)/i,
	/^\s*git\s+ls-/i,
	/^\s*npm\s+(list|ls|view|info|search|outdated|audit)/i,
	/^\s*yarn\s+(list|info|why|audit)/i,
	/^\s*pnpm\s+(list|why|outdated|audit)/i,
	/^\s*node\s+--version/i,
	/^\s*python\s+--version/i,
	/^\s*python3\s+--version/i,
	/^\s*curl\s/i,
	/^\s*wget\s+-O\s*-/i,
	/^\s*jq\b/,
	/^\s*sed\s+-n/i,
	/^\s*awk\b/,
	/^\s*rg\b/,
	/^\s*fd\b/,
	/^\s*bat\b/,
	/^\s*exa\b/,
];

const DEFAULT_PLAN_TOOLS = [
	"read",
	"bash",
	"grep",
	"find",
	"ls",
	"edit",
	"write",
	"todo",
	"lsp",
	"web_search",
	"fetch_content",
	"get_search_content",
	"question",
	"questionnaire",
] as const;

interface PlanModeState {
	enabled: boolean;
	currentPlanPath?: string;
	savedActiveTools?: string[];
	reviewCycles: number;
}

function stripPathSigil(inputPath: string): string {
	return inputPath.startsWith("@") ? inputPath.slice(1) : inputPath;
}

function resolveFromCwd(cwd: string, inputPath: string): string {
	const normalized = stripPathSigil(inputPath);
	return isAbsolute(normalized) ? normalized : resolve(cwd, normalized);
}

function isWithin(parent: string, child: string): boolean {
	const rel = relative(parent, child);
	return rel === "" || (!rel.startsWith("..") && !isAbsolute(rel));
}

function relativeToCwd(cwd: string, inputPath: string): string {
	return relative(cwd, resolveFromCwd(cwd, inputPath));
}

function isSafeCommand(command: string): boolean {
	const destructive = DESTRUCTIVE_PATTERNS.some((pattern) => pattern.test(command));
	const safe = SAFE_BASH_PATTERNS.some((pattern) => pattern.test(command));
	return !destructive && safe;
}

function getThoughtsRoot(cwd: string): string {
	return resolve(cwd, PLAN_ROOT);
}

function getPlansRoot(cwd: string): string {
	return resolve(cwd, PLAN_DIRECTORY);
}

function isThoughtsPath(cwd: string, inputPath: string): boolean {
	return isWithin(getThoughtsRoot(cwd), resolveFromCwd(cwd, inputPath));
}

function isPlanFilePath(cwd: string, inputPath: string): boolean {
	const resolved = resolveFromCwd(cwd, inputPath);
	return isWithin(getPlansRoot(cwd), resolved) && resolved.endsWith(".md");
}

function derivePlanTools(allTools: string[], normalTools: string[] | undefined, includeSubagent: boolean): string[] {
	const desired = new Set<string>(DEFAULT_PLAN_TOOLS);
	if (includeSubagent) desired.add("subagent");

	const orderedSource = normalTools && normalTools.length > 0 ? normalTools : allTools;
	const selected = orderedSource.filter((tool) => desired.has(tool));

	for (const required of desired) {
		if (allTools.includes(required) && !selected.includes(required)) {
			selected.push(required);
		}
	}

	return selected;
}

export default function planModeExtension(pi: ExtensionAPI): void {
	let planModeEnabled = false;
	let currentPlanPath: string | undefined;
	let savedActiveTools: string[] | undefined;
	let reviewCycles = 0;
	let reviewInFlight = false;
	let pendingAutoReviewCommand = false;
	let turnTouchedPlan = false;

	function getAllToolNames(): string[] {
		return pi.getAllTools().map((tool) => tool.name);
	}

	function persistState(): void {
		pi.appendEntry(PLAN_STATE_TYPE, {
			enabled: planModeEnabled,
			currentPlanPath,
			savedActiveTools,
			reviewCycles,
		} satisfies PlanModeState);
	}

	function updateUi(ctx: ExtensionContext): void {
		if (!planModeEnabled) {
			ctx.ui.setStatus("plan-mode", undefined);
			ctx.ui.setWidget("plan-mode", undefined);
			return;
		}

		const planLabel = currentPlanPath ?? "no plan file yet";
		const displayedCycles = Math.min(reviewCycles, MAX_REVIEW_CYCLES);
		const cycleLabel = reviewCycles > 0 ? ` • review ${displayedCycles}/${MAX_REVIEW_CYCLES}` : "";
		const status = reviewInFlight ? `🧪 plan review${cycleLabel}` : `📝 plan${cycleLabel}`;
		ctx.ui.setStatus("plan-mode", ctx.ui.theme.fg("accent", status));
		ctx.ui.setWidget("plan-mode", [
			ctx.ui.theme.fg("accent", "Plan mode active"),
			ctx.ui.theme.fg("muted", `Current plan: ${planLabel}`),
			ctx.ui.theme.fg("muted", `Writes allowed only under ${PLAN_ROOT}/`),
		]);
	}

	function applyPlanTools(includeSubagent = false): void {
		const allTools = getAllToolNames();
		pi.setActiveTools(derivePlanTools(allTools, savedActiveTools, includeSubagent));
	}

	function enablePlanMode(ctx: ExtensionContext): void {
		if (!planModeEnabled) {
			savedActiveTools = pi.getActiveTools();
		}
		planModeEnabled = true;
		reviewInFlight = false;
		pendingAutoReviewCommand = false;
		turnTouchedPlan = false;
		applyPlanTools(false);
		updateUi(ctx);
		persistState();

		const planNote = currentPlanPath ? ` Current plan: ${currentPlanPath}` : "";
		ctx.ui.notify(`Plan mode enabled.${planNote}`, "info");
	}

	function disablePlanMode(ctx: ExtensionContext): void {
		planModeEnabled = false;
		reviewInFlight = false;
		pendingAutoReviewCommand = false;
		turnTouchedPlan = false;
		if (savedActiveTools && savedActiveTools.length > 0) {
			pi.setActiveTools(savedActiveTools);
		}
		updateUi(ctx);
		persistState();
		const planNote = currentPlanPath ? ` Current plan preserved: ${currentPlanPath}` : "";
		ctx.ui.notify(`Plan mode disabled.${planNote}`, "info");
	}

	function togglePlanMode(ctx: ExtensionContext): void {
		if (planModeEnabled) {
			disablePlanMode(ctx);
		} else {
			enablePlanMode(ctx);
		}
	}

	function startReviewCycle(ctx: ExtensionContext): void {
		reviewInFlight = true;
		pendingAutoReviewCommand = true;
		reviewCycles += 1;
		applyPlanTools(true);
		updateUi(ctx);
		persistState();
		pi.sendUserMessage(`/review:plan ${currentPlanPath}`);
	}

	async function hydrateState(ctx: ExtensionContext): Promise<void> {
		planModeEnabled = false;
		reviewInFlight = false;
		pendingAutoReviewCommand = false;
		currentPlanPath = undefined;
		savedActiveTools = undefined;
		reviewCycles = 0;
		turnTouchedPlan = false;

		const stateEntry = ctx.sessionManager
			.getEntries()
			.filter((entry: { type: string; customType?: string }) => entry.type === "custom" && entry.customType === PLAN_STATE_TYPE)
			.pop() as { data?: PlanModeState } | undefined;

		if (stateEntry?.data) {
			planModeEnabled = stateEntry.data.enabled;
			currentPlanPath = stateEntry.data.currentPlanPath;
			savedActiveTools = stateEntry.data.savedActiveTools;
			reviewCycles = stateEntry.data.reviewCycles ?? 0;
		}

		if (pi.getFlag("plan") === true) {
			planModeEnabled = true;
		}

		if (currentPlanPath) {
			try {
				await access(resolve(ctx.cwd, currentPlanPath));
			} catch {
				currentPlanPath = undefined;
				reviewCycles = 0;
			}
		}

		if (planModeEnabled) {
			if (!savedActiveTools || savedActiveTools.length === 0) {
				savedActiveTools = pi.getActiveTools();
			}
			applyPlanTools(false);
		} else if (savedActiveTools && savedActiveTools.length > 0) {
			pi.setActiveTools(savedActiveTools);
		}

		updateUi(ctx);
	}

	async function offerReview(ctx: ExtensionContext, reason: string): Promise<void> {
		if (!planModeEnabled || !ctx.hasUI || !currentPlanPath) return;

		if (reviewCycles >= MAX_REVIEW_CYCLES) {
			ctx.ui.notify(
				`Plan review auto-loop stopped after ${MAX_REVIEW_CYCLES} cycles for ${currentPlanPath}.`,
				"warning",
			);
			updateUi(ctx);
			persistState();
			return;
		}

		const choice = await ctx.ui.select(`Plan updated (${reason}). Run /review:plan for ${currentPlanPath}?`, [
			"Run multi-agent plan review",
			"Keep editing in plan mode",
		]);

		if (choice !== "Run multi-agent plan review") {
			return;
		}

		startReviewCycle(ctx);
	}

	async function offerPostReviewAction(ctx: ExtensionContext, reason: string): Promise<void> {
		if (!planModeEnabled || !ctx.hasUI || !currentPlanPath) return;

		const choices = [
			"Continue with /dev:run",
			"Continue with /ralph:run",
			"Keep editing in plan mode",
		];
		if (reviewCycles < MAX_REVIEW_CYCLES) {
			choices.splice(2, 0, "Run another review cycle");
		}

		const choice = await ctx.ui.select(`Plan review complete (${reason}). Choose an exit path for ${currentPlanPath}.`, choices);

		if (choice === "Continue with /dev:run") {
			disablePlanMode(ctx);
			pi.sendUserMessage(`/cmd:execute-plan ${currentPlanPath} --target dev:run`);
			return;
		}

		if (choice === "Continue with /ralph:run") {
			disablePlanMode(ctx);
			pi.sendUserMessage(`/cmd:execute-plan ${currentPlanPath} --target ralph:run`);
			return;
		}

		if (choice === "Run another review cycle") {
			startReviewCycle(ctx);
		}
	}

	pi.registerFlag("plan", {
		description: "Start in plan mode",
		type: "boolean",
		default: false,
	});

	pi.registerCommand("plan", {
		description: "Toggle plan mode for thoughts/ planning workflows",
		handler: async (_args, ctx) => togglePlanMode(ctx),
	});

	pi.registerShortcut(Key.ctrlAlt("p"), {
		description: "Toggle plan mode",
		handler: async (ctx) => togglePlanMode(ctx),
	});

	pi.on("session_start", async (_event, ctx) => {
		await hydrateState(ctx);
	});

	pi.on("session_switch", async (_event, ctx) => {
		await hydrateState(ctx);
	});

	pi.on("session_fork", async (_event, ctx) => {
		await hydrateState(ctx);
	});

	pi.on("session_tree", async (_event, ctx) => {
		await hydrateState(ctx);
	});

	pi.on("input", async (event, ctx) => {
		turnTouchedPlan = false;
		const text = event.text.trim();
		if (!planModeEnabled) return { action: "continue" };

		if (text.startsWith("/cmd:execute-plan") || text.startsWith("/dev:run") || text.startsWith("/ralph:run")) {
			disablePlanMode(ctx);
			return { action: "continue" };
		}

		if (text.startsWith("/review:plan")) {
			reviewInFlight = true;
			if (pendingAutoReviewCommand) {
				pendingAutoReviewCommand = false;
			} else {
				reviewCycles += 1;
			}
			if (!savedActiveTools || savedActiveTools.length === 0) {
				savedActiveTools = pi.getActiveTools();
			}
			applyPlanTools(true);
			updateUi(ctx);
			persistState();
		}

		return { action: "continue" };
	});

	pi.on("before_agent_start", async (_event) => {
		if (!planModeEnabled) return;

		const currentPlanInstruction = currentPlanPath
			? `Current plan file: ${currentPlanPath}. Continue evolving that file unless the user explicitly asks for a different one.`
			: `If you create a new plan, write it to ${PLAN_DIRECTORY}/<slug>.md.`;

		return {
			message: {
				customType: "plan-mode-context",
				content: `[PLAN MODE ACTIVE]
You are in planning mode for this repository.

Constraints:
- Read the codebase freely.
- You may write only under ${PLAN_ROOT}/ using edit/write tools.
- Keep plan files in ${PLAN_DIRECTORY}/.
- Do not make implementation changes outside ${PLAN_ROOT}/.
- Use read-only bash commands for exploration; file mutations must go through edit/write inside ${PLAN_ROOT}/.
- Plans should align with thoughts/specs/product_intent.md and thoughts/plans/AGENTS.md when relevant.
- After creating or materially updating a plan, expect to be offered /review:plan <path>.
- After review completes, expect to be offered both /dev:run <path> and /ralph:run <path> as exit paths from the reviewed plan.
- In Pi, those exit choices dispatch through /cmd:execute-plan <path> --target ... so context cleanup still happens before execution.
- Review feedback should be integrated back into the same plan file.
- Automatic review looping is capped at ${MAX_REVIEW_CYCLES} cycles before stopping.

${currentPlanInstruction}`,
				display: false,
			},
		};
	});

	pi.on("tool_call", async (event, ctx) => {
		if (!planModeEnabled) return;

		if (event.toolName === "bash") {
			const command = String(event.input.command ?? "");
			if (!isSafeCommand(command)) {
				return {
					block: true,
					reason: `Plan mode only allows read-only bash commands. Use edit/write within ${PLAN_ROOT}/ for plan files.`,
				};
			}
		}

		if (event.toolName === "edit" || event.toolName === "write") {
			const inputPath = typeof event.input.path === "string" ? event.input.path : "";
			if (!inputPath || !isThoughtsPath(ctx.cwd, inputPath)) {
				return {
					block: true,
					reason: `Plan mode only allows edit/write under ${PLAN_ROOT}/.`,
				};
			}
		}
	});

	pi.on("tool_result", async (event, ctx) => {
		if (!planModeEnabled || event.isError) return;
		if (event.toolName !== "edit" && event.toolName !== "write") return;

		const inputPath = typeof event.input.path === "string" ? event.input.path : undefined;
		if (!inputPath || !isPlanFilePath(ctx.cwd, inputPath)) return;

		turnTouchedPlan = true;
		currentPlanPath = relativeToCwd(ctx.cwd, inputPath);
		if (!reviewInFlight) {
			reviewCycles = 0;
		}
		updateUi(ctx);
		persistState();
	});

	pi.on("agent_end", async (_event, ctx) => {
		if (!planModeEnabled) return;

		if (reviewInFlight) {
			reviewInFlight = false;
			pendingAutoReviewCommand = false;
			applyPlanTools(false);
			updateUi(ctx);
			persistState();
			await offerPostReviewAction(
				ctx,
				turnTouchedPlan ? `review cycle ${reviewCycles} integrated` : `review cycle ${reviewCycles} completed`,
			);
			turnTouchedPlan = false;
			return;
		}

		if (turnTouchedPlan) {
			await offerReview(ctx, "plan file updated");
		}

		turnTouchedPlan = false;
	});
}
