# Pi LSP Provisioning Strategy

**Last Updated:** 2026-04-08
**Status:** ✅ Implemented
**Original Plan:** `thoughts/plans/pi-lsp-provisioning-strategy.md`

## Overview

This repo's Pi install flow now provisions the subset of language-server binaries that current `lsp-pi` actually knows how to spawn, instead of only registering `npm:lsp-pi` and leaving server availability to host drift.

The shipped design keeps Phase 1 intentionally small:
- no vendored or forked `lsp-pi`
- no private Pi-only LSP package store
- no lazy runtime installation
- no PATH mutation in shell startup files

Instead, `install.sh --pi` performs installer-side curated provisioning when npm global install locations are already compatible with `lsp-pi`'s existing discovery logic.

## Curated Provisioning Scope

Phase 1 provisions only the npm-manageable surfaces that current `lsp-pi` consumes directly:
- `typescript-language-server` → `typescript-language-server`
- `@vue/language-server` → `vue-language-server`
- `svelte-language-server` → `svelteserver`
- `pyright` → `pyright-langserver`
- `typescript` as a runtime fallback package for TypeScript-family workspaces that do not provide a local `typescript` install

The design explicitly does not claim Astro, YAML, Bash, or Dockerfile LSP support because current `lsp-pi` does not spawn those servers.

Toolchain-backed servers remain unmanaged and informational in Phase 1:
- `gopls`
- `rust-analyzer`
- `dart`
- `sourcekit-lsp`
- Kotlin servers

## Installer Flow

`install.sh` now adds a dedicated curated-LSP provisioning helper inside the Pi package-install path.

The helper:
1. resolves npm global prefix/bin/root information using `npm prefix -g`, `npm config get prefix`, and `npm root -g`
2. checks that the npm global prefix is writable without `sudo`
3. checks that the npm global bin directory is already on `PATH`, or matches a hardcoded fallback directory current `lsp-pi` already searches (`/usr/local/bin` or `/opt/homebrew/bin`)
4. installs only missing curated packages
5. logs per-package outcomes as `already available`, `installed`, `skipped: preflight failed`, or `failed`
6. preserves idempotent reruns

Command discovery intentionally requires executability, not just shell resolution, so a broken or non-executable shim is not treated as success.

## Verification Model

`scripts/verify-pi-install.sh` now verifies three distinct surfaces:

1. **Pi package registration**
   - checks the expected `pi list` package set
   - keeps repo-managed extensions separate from package-managed installs

2. **Curated `lsp-pi` provisioning**
   - repeats npm preflight checks
   - probes the curated commands that `lsp-pi` actually spawns
   - treats missing or non-executable curated binaries as hard failures when preflight says provisioning should work
   - treats missing global `typescript` as degraded fallback support rather than a fatal curated-binary failure

3. **Unmanaged informational surface**
   - reports Go, Rust, Dart, Swift, and Kotlin status without failing the script in Phase 1

Executable smoke probes are lightweight and match each server's real behavior on this host. In particular, Pyright uses `pyright-langserver --stdio` with EOF handling rather than `--help`/`--version`, because those flags do not provide a clean health check here.

## End-to-End Smoke Fixture

The canonical TypeScript smoke fixture lives at:
- `thoughts/fixtures/lsp/typescript-smoke/index.ts`
- `thoughts/fixtures/lsp/typescript-smoke/tsconfig.json`

The fixture intentionally contains a type error so Pi's `lsp` tool can prove real TypeScript diagnostics and symbol navigation, not just command visibility.

Verified behavior included:
- a diagnostics request returning the expected `number` → `string` type mismatch
- a definition request resolving `greet(...)` back to `index.ts:1:17`

## Why This Was Chosen

The repo needed OpenCode-style out-of-box value without taking on OpenCode-style runtime complexity.

The implemented approach captures the highest-value path:
- common JS/TS-family servers become available automatically on compatible hosts
- verification can distinguish registration from actual usability
- the repo avoids becoming a cross-platform LSP package manager
- a future private-bin or lazy-runtime design remains possible if requirements change

After implementation and verification, no runtime-managed follow-up is necessary right now.

## Integration Points

- `install.sh`
- `scripts/verify-pi-install.sh`
- `README.md`
- `_pi/README.md`
- `thoughts/fixtures/lsp/typescript-smoke/index.ts`
- `thoughts/fixtures/lsp/typescript-smoke/tsconfig.json`
- `thoughts/plans/pi-lsp-provisioning-strategy.md`

## Implementation Notes

- npm 11 on the execution host no longer supported `npm bin -g`, so bin-path derivation uses resolved prefix + `/bin` instead.
- The final implementation keeps current `lsp-pi` source unchanged.
- Runtime-managed/private-bin provisioning remains a separate future decision point rather than hidden Phase 1 scope creep.
