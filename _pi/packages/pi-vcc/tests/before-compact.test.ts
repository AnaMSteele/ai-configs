import { describe, expect, it, mock } from "bun:test";
import {
  assistantText,
  assistantWithToolCall,
  toolResult,
  userMsg,
} from "./fixtures";

mock.module("@mariozechner/pi-coding-agent", () => ({
  convertToLlm: (messages: any[]) => messages,
}));

const getBeforeCompactHandler = async () => {
  const { registerBeforeCompactHook } = await import("../src/hooks/before-compact");

  let handler: ((event: any) => any) | undefined;
  registerBeforeCompactHook({
    on: (eventName: string, callback: (event: any) => any) => {
      if (eventName === "session_before_compact") handler = callback;
    },
  } as any);

  if (!handler) throw new Error("session_before_compact handler was not registered");
  return handler;
};

const messageEntry = (id: string, message: any) => ({ id, type: "message", message });

const basePreparation = {
  previousSummary: undefined,
  tokensBefore: 1234,
  fileOps: {
    read: [],
    written: [],
    edited: [],
  },
};

describe("before-compact cut policy", () => {
  it("falls back to compacting long agent-only tails", async () => {
    const handler = await getBeforeCompactHandler();
    const result = handler({
      preparation: basePreparation,
      branchEntries: [
        messageEntry("1", userMsg("Investigate the compaction bug")),
        messageEntry("2", assistantText("I found the hook.")),
        messageEntry("3", assistantWithToolCall("Read", { path: "a.ts" })),
        messageEntry("4", toolResult("Read", "hook source")),
        messageEntry("5", assistantText("The cut policy only keeps a last user boundary.")),
        messageEntry("6", assistantWithToolCall("Read", { path: "b.ts" })),
        messageEntry("7", toolResult("Read", "test source")),
        messageEntry("8", assistantText("We should keep a recent non-user tail instead.")),
      ],
    });

    expect(result.cancel).toBeUndefined();
    expect(result.compaction.firstKeptEntryId).toBe("5");
    expect(result.compaction.summary).toContain("Investigate the compaction bug");
    expect(result.compaction.summary).toContain("I found the hook.");
  });

  it("still prefers the latest user boundary when one exists", async () => {
    const handler = await getBeforeCompactHandler();
    const result = handler({
      preparation: basePreparation,
      branchEntries: [
        messageEntry("1", userMsg("First request")),
        messageEntry("2", assistantText("Handled the first request.")),
        messageEntry("3", userMsg("Follow-up request")),
        messageEntry("4", assistantWithToolCall("Read", { path: "followup.ts" })),
        messageEntry("5", toolResult("Read", "followup source")),
        messageEntry("6", assistantText("Working on the follow-up.")),
      ],
    });

    expect(result.cancel).toBeUndefined();
    expect(result.compaction.firstKeptEntryId).toBe("3");
    expect(result.compaction.summary).toContain("First request");
    expect(result.compaction.summary).not.toContain("Follow-up request");
  });
});
