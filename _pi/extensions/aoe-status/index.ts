import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { existsSync, lstatSync, mkdirSync, renameSync, statSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import process from "node:process";

type AoePiStatus = "idle" | "running" | "stopped";

const schema = 1;
const tool = "pi";
const startedAtMs = Date.now();
const registryParent = "/tmp/aoe-pi-status";
const heartbeatMs = 30000;
let latestStatus: AoePiStatus = "idle";
let latestContext: ExtensionContext | undefined;

function currentUid(): string {
  return typeof process.getuid === "function" ? String(process.getuid()) : "unknown";
}

function safeDirectory(path: string): boolean {
  try {
    const metadata = lstatSync(path);
    return metadata.isDirectory() && !metadata.isSymbolicLink();
  } catch {
    return false;
  }
}

function ensureRegistryDir(): string | undefined {
  try {
    if (existsSync(registryParent) && !safeDirectory(registryParent)) return undefined;
    mkdirSync(registryParent, { recursive: true, mode: 0o755 });
    if (!safeDirectory(registryParent)) return undefined;

    const dir = join(registryParent, currentUid());
    if (existsSync(dir) && !safeDirectory(dir)) return undefined;
    mkdirSync(dir, { recursive: true, mode: 0o700 });
    const metadata = statSync(dir);
    if (typeof process.getuid === "function" && metadata.uid !== process.getuid()) return undefined;
    return dir;
  } catch {
    return undefined;
  }
}

function writeStatus(status: AoePiStatus, ctx?: ExtensionContext): void {
  latestStatus = status;
  latestContext = ctx;
  try {
    const dir = ensureRegistryDir();
    if (!dir) return;
    const record = {
      schema,
      tool,
      status,
      pid: process.pid,
      cwd: ctx?.cwd ?? process.cwd(),
      sessionFile: ctx?.sessionManager?.getSessionFile?.(),
      updatedAtMs: Date.now(),
      startedAtMs,
    };
    const finalPath = join(dir, `${process.pid}.json`);
    const tempPath = join(dir, `.${process.pid}.${Date.now()}.tmp`);
    writeFileSync(tempPath, JSON.stringify(record), { mode: 0o600 });
    renameSync(tempPath, finalPath);
  } catch {
    // Status reporting must never break Pi startup or turns.
  }
}

export default function (pi: ExtensionAPI) {
  writeStatus("idle");
  const heartbeat = setInterval(() => writeStatus(latestStatus, latestContext), heartbeatMs);
  (heartbeat as { unref?: () => void }).unref?.();
  pi.on("session_start", async (_event, ctx) => writeStatus("idle", ctx));
  pi.on("agent_start", async (_event, ctx) => writeStatus("running", ctx));
  pi.on("turn_start", async (_event, ctx) => writeStatus("running", ctx));
  pi.on("agent_end", async (_event, ctx) => writeStatus("idle", ctx));
  pi.on("session_shutdown", async (_event, ctx) => writeStatus("stopped", ctx));
}
