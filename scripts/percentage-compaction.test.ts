import { describe, expect, test } from "bun:test";

import percentageCompaction, {
  COMPACTION_THRESHOLD_PERCENT,
  PI_VCC_MANUAL_BYPASS_MARKER,
} from "../_pi/extensions/percentage-compaction";

type HandlerMap = Record<string, (event: any, ctx: any) => any>;
type CommandMap = Record<string, { description: string; handler: (args: string, ctx: any) => any }>;

const setup = (percent = COMPACTION_THRESHOLD_PERCENT + 1) => {
  const handlers: HandlerMap = {};
  const commands: CommandMap = {};
  const notifications: Array<{ message: string; level: string }> = [];
  const compactCalls: Array<any> = [];

  const ctx = {
    ui: {
      notify: (message: string, level: string) => {
        notifications.push({ message, level });
      },
    },
    compact: (options?: any) => {
      compactCalls.push(options ?? {});
    },
    getContextUsage: () => ({
      percent,
      contextWindow: 272000,
    }),
  };

  percentageCompaction({
    on: (event: string, handler: (event: any, ctx: any) => any) => {
      handlers[event] = handler;
    },
    registerCommand: (name: string, command: any) => {
      commands[name] = command;
    },
  } as any);

  return { handlers, commands, notifications, compactCalls, ctx };
};

describe("percentage-compaction extension", () => {
  test("proactively compacts at threshold on a safe assistant boundary", async () => {
    const { handlers, compactCalls, notifications, ctx } = setup(60.4);

    await handlers.message_end?.(
      { message: { role: "assistant", stopReason: "stop" } },
      ctx,
    );

    expect(compactCalls).toHaveLength(1);
    expect(compactCalls[0]?.customInstructions).toBe(PI_VCC_MANUAL_BYPASS_MARKER);
    expect(notifications.some((entry) => entry.message.includes("Auto-compacting at 60%"))).toBe(true);
  });

  test("waits for the current tool-using turn to finish before compacting", async () => {
    const { handlers, compactCalls, notifications, ctx } = setup(61.2);

    await handlers.message_end?.(
      { message: { role: "assistant", stopReason: "toolUse" } },
      ctx,
    );
    await handlers.message_end?.(
      { message: { role: "tool" } },
      ctx,
    );

    expect(compactCalls).toHaveLength(0);
    expect(notifications.some((entry) => entry.message.includes("Waiting for the current assistant response"))).toBe(true);

    await handlers.message_end?.(
      { message: { role: "assistant", stopReason: "stop" } },
      ctx,
    );

    expect(compactCalls).toHaveLength(1);
  });

  test("manual compact-now bypasses the threshold gate", async () => {
    const { commands, handlers, compactCalls, ctx } = setup(20);

    await commands["compact-now"].handler("keep goals", ctx);

    expect(compactCalls).toHaveLength(1);
    expect(compactCalls[0]?.customInstructions).toBe("keep goals");

    const result = await handlers.session_before_compact?.(
      { customInstructions: "keep goals" },
      ctx,
    );

    expect(result).toBeUndefined();
  });

  test("core auto-compaction is still blocked below threshold without bypass", async () => {
    const { handlers, ctx } = setup(59.9);

    const result = await handlers.session_before_compact?.(
      { customInstructions: undefined },
      ctx,
    );

    expect(result).toEqual({ cancel: true });
  });

  test("bypass marker allows pi-vcc compaction below threshold", async () => {
    const { handlers, ctx } = setup(59.9);

    const result = await handlers.session_before_compact?.(
      { customInstructions: PI_VCC_MANUAL_BYPASS_MARKER },
      ctx,
    );

    expect(result).toBeUndefined();
  });
});
