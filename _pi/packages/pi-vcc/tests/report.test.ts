import { describe, it, expect } from "bun:test";
import { buildCompactReport } from "../src/core/report";
import {
  userMsg,
  assistantText,
  assistantWithToolCall,
  toolResult,
} from "./fixtures";

describe("buildCompactReport", () => {
  it("includes before and after compact metrics", () => {
    const report = buildCompactReport({
      messages: [
        userMsg("Fix login bug in auth.ts"),
        assistantWithToolCall("Read", { path: "auth.ts" }),
        toolResult("Read", "const x = 1;"),
        assistantText("Found the root cause in auth.ts.\n1. Fix validation\n2. Run tests"),
      ],
    });
    expect(report.before.messageCount).toBe(4);
    expect(report.before.roleCounts.user).toBe(1);
    expect(report.before.topFiles).toContain("auth.ts");
    expect(report.before.preview).toContain("Fix login bug in auth.ts");
    expect(report.after.sectionCount).toBeGreaterThan(0);
    expect(report.after.summaryPreview).toContain("[Session Goal]");
    expect(report.after.summaryPreview).toContain('* Read "auth.ts"');
    expect(report.after.briefTranscriptLines).toBeGreaterThan(0);
    expect(report.compression.ratio).toBeGreaterThan(0);
  });

  it("marks recall probe coverage for goal and file queries", () => {
    const report = buildCompactReport({
      messages: [
        userMsg("Fix login bug in auth.ts"),
        assistantWithToolCall("Read", { path: "auth.ts" }),
        toolResult("Read", "code content"),
        assistantText("Found the root cause"),
      ],
    });
    expect(report.recall.probes.length).toBeGreaterThanOrEqual(1);
    const goalProbe = report.recall.probes.find((p) => p.label === "goal");
    expect(goalProbe?.summaryMentioned).toBe(true);
  });

  it("counts recall hits with the probe query", () => {
    const report = buildCompactReport({
      messages: [
        userMsg("Handle unrelated setup"),
        assistantWithToolCall("Read", { path: "unique-auth-file.ts" }),
        toolResult("Read", "code content"),
        assistantText("Done"),
      ],
    });
    const fileProbe = report.recall.probes.find((p) => p.label === "file");
    expect(fileProbe?.query).toBe("unique-auth-file.ts");
    expect(fileProbe?.recallHits).toBe(1);
  });

  it("matches file probe recall hits literally", () => {
    const report = buildCompactReport({
      messages: [
        userMsg("Handle unrelated setup"),
        assistantWithToolCall("Read", { path: "unique-auth-file.ts" }),
        assistantText("Mention unique-auth-fileXts as a separate token"),
      ],
    });
    const fileProbe = report.recall.probes.find((p) => p.label === "file");
    expect(fileProbe?.query).toBe("unique-auth-file.ts");
    expect(fileProbe?.recallHits).toBe(1);
  });

  it("counts and previews bashExecution messages", () => {
    const report = buildCompactReport({
      messages: [
        userMsg("Run the failing test"),
        { role: "bashExecution", command: "bun test auth.test.ts", output: "rare_failure_marker", exitCode: 1 },
      ],
    });
    expect(report.before.roleCounts.bashExecution).toBe(1);
    expect(report.before.blockCounts.bash).toBe(1);
    expect(report.before.preview).toContain("bun test auth.test.ts");
    expect(report.before.preview).toContain("rare_failure_marker");
  });
});
