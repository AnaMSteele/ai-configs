import { access, readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { isAbsolute, relative, resolve } from "node:path";
import type { ExtensionAPI, ExtensionCommandContext, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { Key } from "@mariozechner/pi-tui";

const PLAN_STATE_TYPE = "plan-mode-state";
const PLAN_ROOT = "thoughts";
const PLAN_DIRECTORY = "thoughts/plans";
const PLAN_PROMPTS_DIRECTORIES = ["_pi/prompts", ".pi/prompts"] as const;
const GLOBAL_PROMPTS_DIRECTORY = resolve(homedir(), ".pi/agent/prompts");
const EXECUTE_PLAN_COMMAND = "cmd:execute-plan";
const STANDARD_PLAN_REVIEW_COMMAND = "review:plan";
const ADVERSARIAL_PLAN_REVIEW_COMMAND = "review:plan-adversarial";
const CLAUDE_REVIEW_COMMAND = "review:change-claude-code";
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

const REVIEW_ORCHESTRATION_TOOLS = [
	"subagent",
	"Agent",
	"get_subagent_result",
	"steer_subagent",
	"interactive_shell",
	"process",
] as const;

const REVIEW_ACTIVITY_TOOLS = [
	"subagent",
	"Agent",
	"get_subagent_result",
	"steer_subagent",
	"interactive_shell",
	"process",
] as const;

interface PlanModeState {
	enabled: boolean;
	currentPlanPath?: string;
	savedActiveTools?: string[];
	reviewCycles: number;
	lastReviewCommand?: string;
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

function stripFrontmatter(content: string): string {
	if (!content.startsWith("---\n")) return content;
	const end = content.indexOf("\n---\n", 4);
	return end === -1 ? content : content.slice(end + 5);
}

function parseCommandArgs(argsString: string): string[] {
	const args: string[] = [];
	let current = "";
	let inQuote: string | null = null;

	for (let i = 0; i < argsString.length; i += 1) {
		const char = argsString[i];

		if (inQuote) {
			if (char === inQuote) {
				inQuote = null;
			} else {
				current += char;
			}
		} else if (char === '"' || char === "'") {
			inQuote = char;
		} else if (char === " " || char === "\t") {
			if (current) {
				args.push(current);
				current = "";
			}
		} else {
			current += char;
		}
	}

	if (current) {
		args.push(current);
	}

	return args;
}

function substituteCommandArgs(content: string, args: string[]): string {
	let result = content.replace(/\$(\d+)/g, (_, num: string) => {
		const index = Number.parseInt(num, 10) - 1;
		return args[index] ?? "";
	});

	result = result.replace(/\$@\[(\d+)(?::(\d*)?)?\]/g, (_, startRaw: string, lengthRaw?: string) => {
		const start = Number.parseInt(startRaw, 10);
		if (!Number.isFinite(start) || start < 1) return "";

		const startIndex = start - 1;
		if (startIndex >= args.length) return "";
		if (lengthRaw === undefined || lengthRaw === "") {
			return args.slice(startIndex).join(" ");
		}

		const length = Number.parseInt(lengthRaw, 10);
		if (!Number.isFinite(length) || length <= 0) return "";
		return args.slice(startIndex, startIndex + length).join(" ");
	});

	const allArgs = args.join(" ");
	result = result.replaceAll("$ARGUMENTS", allArgs);
	result = result.replaceAll("$@", allArgs);
	return result;
}

async function expandSlashCommandPrompt(cwd: string, commandText: string): Promise<string | undefined> {
	if (!commandText.startsWith("/")) return undefined;

	const spaceIndex = commandText.indexOf(" ");
	const commandName = spaceIndex === -1 ? commandText.slice(1) : commandText.slice(1, spaceIndex);
	const argsString = spaceIndex === -1 ? "" : commandText.slice(spaceIndex + 1);
	const candidatePaths = [
		...PLAN_PROMPTS_DIRECTORIES.map((directory) => resolve(cwd, directory, `${commandName}.md`)),
		resolve(GLOBAL_PROMPTS_DIRECTORY, `${commandName}.md`),
	];

	for (const candidatePath of candidatePaths) {
		try {
			const template = stripFrontmatter(await readFile(candidatePath, "utf8"));
			return substituteCommandArgs(template, parseCommandArgs(argsString));
		} catch {
			// Ignore missing prompt files and continue searching fallback locations.
		}
	}

	return undefined;
}

function normalizeExecuteTarget(target: string | undefined): "dev:run" | "ralph:run" | undefined {
	if (!target) return undefined;
	const normalized = target.trim().replace(/^\//, "");
	if (normalized === "dev:run" || normalized === "ralph:run") return normalized;
	return undefined;
}

function formatCommandArg(arg: string): string {
	return /\s/.test(arg) ? JSON.stringify(arg) : arg;
}

function getExecutePlanUsage(): string {
	return `Usage: /${EXECUTE_PLAN_COMMAND} <plan slug | thoughts/plans/<slug>.md | path/to/plan.md> [--target dev:run|ralph:run]`;
}

async function resolveExecutePlanRequest(
	cwd: string,
	rawArgs: string,
): Promise<
	| { planDispatchArgument: string; planPath: string; targetOverride?: "dev:run" | "ralph:run" }
	| { error: string }
> {
	const tokens = parseCommandArgs(rawArgs.trim());
	if (tokens.length === 0) {
		return { error: getExecutePlanUsage() };
	}

	const targetFlagIndex = tokens.lastIndexOf("--target");
	let planTokens = tokens;
	let targetOverride: "dev:run" | "ralph:run" | undefined;

	if (targetFlagIndex !== -1) {
		if (targetFlagIndex === tokens.length - 1) {
			return { error: "Missing value after --target. Valid targets: /dev:run or /ralph:run." };
		}
		if (targetFlagIndex < tokens.length - 2) {
			return { error: "Unexpected extra arguments after --target. Use exactly one target value." };
		}

		targetOverride = normalizeExecuteTarget(tokens[targetFlagIndex + 1]);
		if (!targetOverride) {
			return { error: "Invalid --target value. Valid targets: /dev:run or /ralph:run." };
		}
		planTokens = tokens.slice(0, targetFlagIndex);
	}

	const planArgument = planTokens.join(" ").trim();
	if (!planArgument) {
		return { error: getExecutePlanUsage() };
	}

	const planDispatchArgument = stripPathSigil(planArgument);
	const planPath = planDispatchArgument.endsWith(".md")
		? resolveFromCwd(cwd, planDispatchArgument)
		: resolve(cwd, PLAN_DIRECTORY, `${planDispatchArgument}.md`);

	try {
		await access(planPath);
	} catch {
		return {
			error: `Reviewed plan not found: ${planPath}. /${EXECUTE_PLAN_COMMAND} requires an explicit existing reviewed plan file or slug.`,
		};
	}

	return { planDispatchArgument, planPath, targetOverride };
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

function derivePlanTools(allTools: string[], normalTools: string[] | undefined, includeReviewTools: boolean): string[] {
	const desired = new Set<string>(DEFAULT_PLAN_TOOLS);
	if (includeReviewTools) {
		for (const toolName of REVIEW_ORCHESTRATION_TOOLS) {
			desired.add(toolName);
		}
	}

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
	let reviewSawReviewActivity = false;
	let reviewClaudeFallbackAttempted = false;
	let lastReviewCommand: string | undefined;
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
			lastReviewCommand,
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

	function applyPlanTools(includeReviewTools = false): void {
		const allTools = getAllToolNames();
		pi.setActiveTools(derivePlanTools(allTools, savedActiveTools, includeReviewTools));
	}

	function enablePlanMode(ctx: ExtensionContext): void {
		if (!planModeEnabled) {
			savedActiveTools = pi.getActiveTools();
		}
		planModeEnabled = true;
		reviewInFlight = false;
		pendingAutoReviewCommand = false;
		reviewSawReviewActivity = false;
		reviewClaudeFallbackAttempted = false;
		lastReviewCommand = undefined;
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
		reviewSawReviewActivity = false;
		reviewClaudeFallbackAttempted = false;
		lastReviewCommand = undefined;
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

	async function dispatchSlashCommandPrompt(ctx: ExtensionContext, commandText: string): Promise<void> {
		// pi.sendUserMessage() bypasses slash-command expansion, so expand prompt-backed
		// slash commands before dispatching them from plan-mode automation.
		const expandedPrompt = await expandSlashCommandPrompt(ctx.cwd, commandText);
		pi.sendUserMessage(expandedPrompt ?? commandText);
	}

	function prepareFreshExecutionCommand(ctx: ExtensionContext, target: "dev:run" | "ralph:run"): void {
		if (!currentPlanPath) return;
		const command = `/${EXECUTE_PLAN_COMMAND} ${formatCommandArg(currentPlanPath)} --target ${target}`;
		ctx.ui.setEditorText(command);
		ctx.ui.notify(`Prepared ${command}. Press Enter to start a fresh execution session.`, "info");
	}

	async function handleExecutePlanCommand(args: string, ctx: ExtensionCommandContext): Promise<void> {
		const request = await resolveExecutePlanRequest(ctx.cwd, args);
		if ("error" in request) {
			ctx.ui.notify(request.error, "warning");
			return;
		}

		let target = request.targetOverride;
		if (!target) {
			if (!ctx.hasUI) {
				ctx.ui.notify("No UI available. Re-run with --target dev:run or --target ralph:run.", "warning");
				return;
			}

			const choice = await ctx.ui.select(`Choose execution path for ${request.planDispatchArgument}.`, [
				`/ralph:run ${request.planDispatchArgument}`,
				`/dev:run ${request.planDispatchArgument}`,
			]);
			if (!choice) {
				return;
			}
			target = choice.startsWith("/ralph:run") ? "ralph:run" : "dev:run";
		}

		const executionPrompt = await expandSlashCommandPrompt(ctx.cwd, `/${target} ${request.planDispatchArgument}`);
		if (!executionPrompt) {
			ctx.ui.notify(`Could not expand /${target}. Ensure the corresponding prompt template exists.`, "error");
			return;
		}

		await ctx.waitForIdle();
		const result = await ctx.newSession({ parentSession: ctx.sessionManager.getSessionFile() });
		if (result.cancelled) {
			return;
		}

		pi.sendUserMessage(executionPrompt);
	}

	async function startReviewCycle(
		ctx: ExtensionContext,
		command: string = STANDARD_PLAN_REVIEW_COMMAND,
	): Promise<void> {
		reviewInFlight = true;
		pendingAutoReviewCommand = true;
		reviewSawReviewActivity = false;
		reviewClaudeFallbackAttempted = false;
		lastReviewCommand = command;
		reviewCycles += 1;
		applyPlanTools(true);
		updateUi(ctx);
		persistState();
		await dispatchSlashCommandPrompt(ctx, `/${command} ${currentPlanPath}`);
	}

	async function hydrateState(ctx: ExtensionContext): Promise<void> {
		planModeEnabled = false;
		reviewInFlight = false;
		pendingAutoReviewCommand = false;
		reviewSawReviewActivity = false;
		reviewClaudeFallbackAttempted = false;
		currentPlanPath = undefined;
		savedActiveTools = undefined;
		reviewCycles = 0;
		lastReviewCommand = undefined;
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
			lastReviewCommand = stateEntry.data.lastReviewCommand;
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
				lastReviewCommand = undefined;
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

		const choice = await ctx.ui.select(`Plan updated (${reason}). Run /${STANDARD_PLAN_REVIEW_COMMAND} for ${currentPlanPath}?`, [
			"Run standard multi-agent plan review",
			"Keep editing in plan mode",
		]);

		if (choice !== "Run standard multi-agent plan review") {
			return;
		}

		await startReviewCycle(ctx, STANDARD_PLAN_REVIEW_COMMAND);
	}

	async function startAdversarialReviewCycle(ctx: ExtensionContext): Promise<void> {
		await startReviewCycle(ctx, ADVERSARIAL_PLAN_REVIEW_COMMAND);
	}

	async function offerPostReviewAction(ctx: ExtensionContext, reason: string): Promise<void> {
		if (!planModeEnabled || !ctx.hasUI || !currentPlanPath) return;

		const choices = [
			"Start fresh /dev:run session",
			"Start fresh /ralph:run session",
			"Keep editing in plan mode",
		];
		if (lastReviewCommand === STANDARD_PLAN_REVIEW_COMMAND) {
			choices.splice(2, 0, `Run /${ADVERSARIAL_PLAN_REVIEW_COMMAND} pass`);
		}
		if (reviewCycles < MAX_REVIEW_CYCLES) {
			choices.splice(choices.length - 1, 0, "Run another standard review cycle");
		}

		const choice = await ctx.ui.select(`Plan review complete (${reason}). Choose an exit path for ${currentPlanPath}.`, choices);

		if (choice === "Start fresh /dev:run session") {
			disablePlanMode(ctx);
			prepareFreshExecutionCommand(ctx, "dev:run");
			return;
		}

		if (choice === "Start fresh /ralph:run session") {
			disablePlanMode(ctx);
			prepareFreshExecutionCommand(ctx, "ralph:run");
			return;
		}

		if (choice === `Run /${ADVERSARIAL_PLAN_REVIEW_COMMAND} pass`) {
			await startAdversarialReviewCycle(ctx);
			return;
		}

		if (choice === "Run another standard review cycle") {
			await startReviewCycle(ctx, STANDARD_PLAN_REVIEW_COMMAND);
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

	pi.registerCommand(EXECUTE_PLAN_COMMAND, {
		description: "Start /dev:run or /ralph:run in a fresh session from a reviewed plan",
		handler: async (args, ctx) => handleExecutePlanCommand(args, ctx),
	});

	pi.registerShortcut(Key.ctrlAlt("p"), {
		description: "Toggle plan mode",
		handler: async (ctx) => togglePlanMode(ctx),
	});

	pi.on("session_start", async (_event, ctx) => {
		await hydrateState(ctx);
	});

	pi.on("session_tree", async (_event, ctx) => {
		await hydrateState(ctx);
	});

	pi.on("input", async (event, ctx) => {
		turnTouchedPlan = false;
		const text = event.text.trim();
		if (!planModeEnabled) return { action: "continue" };

		if (text.startsWith(`/${EXECUTE_PLAN_COMMAND}`) || text.startsWith("/dev:run") || text.startsWith("/ralph:run")) {
			disablePlanMode(ctx);
			return { action: "continue" };
		}

		if (text.startsWith(`/${ADVERSARIAL_PLAN_REVIEW_COMMAND}`) || text.startsWith(`/${STANDARD_PLAN_REVIEW_COMMAND}`)) {
			reviewInFlight = true;
			reviewSawReviewActivity = false;
			reviewClaudeFallbackAttempted = false;
			lastReviewCommand = text.startsWith(`/${ADVERSARIAL_PLAN_REVIEW_COMMAND}`)
				? ADVERSARIAL_PLAN_REVIEW_COMMAND
				: STANDARD_PLAN_REVIEW_COMMAND;
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
- After a standard review completes, you may optionally run /review:plan-adversarial <path> for a second-pass challenge review.
- After review completes, expect to be offered both /dev:run <path> and /ralph:run <path> as exit paths from the reviewed plan.
- In Pi, those exit choices route through /cmd:execute-plan <path> --target ... so execution starts from a fresh session instead of staying in planning context.
- Review feedback should be integrated back into the same plan file.
- Automatic review looping is capped at ${MAX_REVIEW_CYCLES} cycles before stopping.

${currentPlanInstruction}`,
				display: false,
			},
		};
	});

	pi.on("tool_call", async (event, ctx) => {
		if (!planModeEnabled) return;

		if (reviewInFlight && REVIEW_ACTIVITY_TOOLS.includes(event.toolName as (typeof REVIEW_ACTIVITY_TOOLS)[number])) {
			reviewSawReviewActivity = true;
			persistState();
		}

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
			lastReviewCommand = undefined;
		}
		updateUi(ctx);
		persistState();
	});

	pi.on("agent_end", async (_event, ctx) => {
		if (!planModeEnabled) return;

		if (reviewInFlight) {
			if (
				lastReviewCommand === STANDARD_PLAN_REVIEW_COMMAND &&
				!reviewSawReviewActivity &&
				!reviewClaudeFallbackAttempted &&
				currentPlanPath
			) {
				reviewClaudeFallbackAttempted = true;
				applyPlanTools(true);
				updateUi(ctx);
				persistState();
				ctx.ui.notify(
					`/${STANDARD_PLAN_REVIEW_COMMAND} ended before launching Claude Code. Starting /${CLAUDE_REVIEW_COMMAND} for ${currentPlanPath}.`,
					"warning",
				);
				await dispatchSlashCommandPrompt(ctx, `/${CLAUDE_REVIEW_COMMAND} ${formatCommandArg(currentPlanPath)}`);
				return;
			}

			reviewInFlight = false;
			pendingAutoReviewCommand = false;
			reviewSawReviewActivity = false;
			reviewClaudeFallbackAttempted = false;
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
