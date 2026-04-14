import { existsSync } from "fs";
import { pathToFileURL } from "url";
import type { Message } from "@mariozechner/pi-ai";

const sessionManagerCandidates = [
  process.env.PI_VCC_SESSION_MANAGER_PATH,
  new URL("../../../../../node_modules/@mariozechner/pi-coding-agent/dist/core/session-manager.js", import.meta.url).pathname,
  "/opt/homebrew/lib/node_modules/@mariozechner/pi-coding-agent/dist/core/session-manager.js",
  "/home/linuxbrew/.linuxbrew/lib/node_modules/@mariozechner/pi-coding-agent/dist/core/session-manager.js",
].filter((value): value is string => Boolean(value));

const loadSessionManager = async () => {
  for (const candidate of sessionManagerCandidates) {
    try {
      if (candidate.startsWith("/") && !existsSync(candidate)) continue;
      return await import(candidate.startsWith("/") ? pathToFileURL(candidate).href : candidate);
    } catch {
      continue;
    }
  }

  throw new Error(`Unable to resolve pi-coding-agent session-manager.js from: ${sessionManagerCandidates.join(", ")}`);
};

const { buildSessionContext, loadEntriesFromFile } = await loadSessionManager();

export interface LoadedSession {
  messageCount: number;
  skippedCount: number;
  messages: Message[];
}

export const loadSessionMessages = (file: string): LoadedSession => {
  const entries = loadEntriesFromFile(file);
  const sessionEntries = entries.filter((entry) => entry.type !== "header");
  const context = buildSessionContext(sessionEntries as any);
  const messages = (context.messages as any[]).filter(
    (msg): msg is Message =>
      msg && typeof msg.role === "string" && "content" in msg,
  );
  return {
    messageCount: messages.length,
    skippedCount: context.messages.length - messages.length,
    messages,
  };
};
