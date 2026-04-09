import type { NormalizedBlock } from "../types";
import { clip, nonEmptyLines } from "../core/content";

const PREF_PATTERNS = [
  /\bprefer\b/i,
  /\bdon'?t want\b/i,
  /\balways\b/i,
  /\bnever\b/i,
  /\bplease\s+(use|avoid|keep|make)\b/i,
  /\bstyle[:\s]/i,
  /\bformat[:\s]/i,
  /\blanguage[:\s]/i,
];

export const extractPreferences = (blocks: NormalizedBlock[]): string[] => {
  const prefs: string[] = [];

  for (const b of blocks) {
    if (b.kind !== "user") continue;
    for (const line of nonEmptyLines(b.text)) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.length < 5) continue;
      if (PREF_PATTERNS.some((p) => p.test(trimmed))) {
        prefs.push(clip(trimmed, 200));
      }
    }
  }

  return [...new Set(prefs)].slice(0, 10);
};
