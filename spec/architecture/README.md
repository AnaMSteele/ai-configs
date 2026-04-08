# Architecture Documentation

This directory contains architecture documents for implemented features.

## Architecture Docs

| Feature | Document | Status | Description |
|---------|----------|--------|-------------|
| Pi LSP provisioning strategy | [pi-lsp-provisioning-strategy.md](./pi-lsp-provisioning-strategy.md) | ✅ Implemented | Adds installer-managed provisioning and truthful verification for the curated `lsp-pi` server subset without vendoring `lsp-pi`. |
| OpenCode `review:plan` wrapper | [opencode-review-plan-wrapper.md](./opencode-review-plan-wrapper.md) | ✅ Implemented | Adds a first-class OpenCode `review:plan` entrypoint that fans out to the existing GPT5.4 and Kimi review flows without auto-integrating comments. |
| ltui image attachments | [ltui-image-attachments.md](./ltui-image-attachments.md) | ✅ Implemented | Adds deterministic issue attachment discovery, image hints in `issues view`, and optional safe local downloads. |
<!-- Rows added by /cmd:graduate after completing features -->
