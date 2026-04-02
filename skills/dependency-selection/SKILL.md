---
name: dependency-selection
description: Guide for selecting third-party dependencies and libraries over custom implementations. Prioritize reuse of well-maintained, reputable libraries with proper vetting and approval workflow.
tools: Read, Write, Bash, Glob, Grep, cargo, npm
---

# Dependency Selection & Reuse-First Guidelines

When building software, **prioritize reusing well-maintained third-party libraries over custom implementations**. Only build internally when there is a clear, justified reason.

## Core Principle: Reuse by Default

Before writing custom code for any non-trivial functionality:

1. **Search for existing libraries** in the ecosystem
2. **Evaluate candidates** against quality criteria
3. **Get approval** for custom implementations (see approval workflow below)
4. **Document the rationale** for exceptions

## Library Vetting Criteria

All third-party dependencies must meet these standards:

### Maintenance & Health
- [ ] Active development (commits within last 3-6 months)
- [ ] Responsive maintainers (issue/PR response time < 2 weeks)
- [ ] Clear versioning strategy (semver compliance)
- [ ] Stable release history (not perpetual 0.x or alpha)
- [ ] Adequate test coverage and CI visible in repo

### Security & Trust
- [ ] Reputable source (established org, known maintainers, or well-vetted individual)
- [ ] No known unpatched vulnerabilities (check advisories)
- [ ] Transparent security practices (SECURITY.md, responsible disclosure)
- [ ] Minimal and auditable dependency tree (check with `cargo tree` or `npm ls`)
- [ ] License compatibility with project (MIT/Apache-2.0 preferred for Rust, MIT/BSD for JS)

### Quality & Fit
- [ ] Solves the problem without significant workarounds
- [ ] API design is idiomatic for the language/ecosystem
- [ ] Performance characteristics meet requirements
- [ ] Documentation is adequate for onboarding
- [ ] Used by other reputable projects (social proof)

## Ecosystem-Specific Trusted Sources

### Rust (crates.io)
**Tier 1 - Well-established, always consider first:**
- `tokio` / `async-std` - Async runtime
- `serde` / `serde_json` - Serialization
- `axum` / `actix-web` / `rocket` - Web frameworks
- `sqlx` / `diesel` - Database access
- `reqwest` / `hyper` - HTTP clients/servers
- `chrono` / `time` - Date/time handling
- `uuid` - UUID generation
- `tracing` / `log` - Logging infrastructure
- `clap` - CLI argument parsing
- `thiserror` / `anyhow` - Error handling
- `ed25519-dalek` / `ring` - Cryptography
- `argon2` / `bcrypt` - Password hashing
- `chacha20poly1305` / `aes-gcm` - Symmetric encryption
- `sha2` / `blake3` - Hashing
- `tower` / `tower-http` - Middleware/service composition
- `config` - Configuration management
- `validator` - Input validation
- `jsonwebtoken` - JWT handling

**Tier 2 - Specialized, evaluate per use case:**
- `nom` / `winnow` - Parser combinators
- `regex` - Regular expressions
- `rand` / `getrandom` - Random number generation
- `walkdir` - Directory traversal
- `globset` - Glob pattern matching
- `tempfile` - Temporary files
- `walkdir` - Directory traversal
- `notify` - File system watching
- `r2d2` / `deadpool` - Connection pooling

### JavaScript/TypeScript (npm)
**Tier 1 - Well-established, always consider first:**
- `zod` / `valibot` - Schema validation
- `ky` / `axios` - HTTP clients
- `lodash-es` / `radash` - Utilities (prefer native when possible)
- `date-fns` / `dayjs` - Date manipulation
- `nanoid` - ID generation
- `p-retry` / `p-throttle` - Promise utilities
- `execa` - Process execution
- `globby` - Glob matching
- `fs-extra` - File system utilities
- `commander` / `yargs` - CLI frameworks
- `chalk` / `picocolors` - Terminal colors
- `ora` - CLI spinners
- `inquirer` / `@inquirer/prompts` - Interactive prompts
- `cosmiconfig` - Configuration loading
- `debug` / `pino` - Logging

**Tier 2 - Specialized, evaluate per use case:**
- `fast-glob` - Fast glob matching
- `minimatch` - Glob matching
- `micromatch` - Glob matching with extended features
- `parse-json` - JSON parsing with better errors
- `strip-json-comments` - JSON with comments support
- `node-fetch` / `undici` - Fetch implementations

## When Custom Implementation is Justified

**Requires explicit approval. Document the rationale.**

Acceptable reasons:
1. **No suitable library exists** - The functionality is unique to your domain
2. **All candidates fail vetting** - Security, maintenance, or quality concerns
3. **Performance requirements** - Existing libraries don't meet performance needs (with benchmarks)
4. **Size constraints** - Binary size critical and library too heavy (with measurements)
5. **Custom protocol/format** - You're defining a new standard (e.g., sync-envelope, canonical-json)
6. **Learning/educational** - For deep understanding before using library (document the learning)

Unacceptable reasons:
- "I wanted to build it myself" (NIH syndrome)
- "It's only a small function" (the "small" code grows, maintenance burden compounds)
- "I don't trust dependencies" (vet them instead of reinventing)
- "The library does too much" (use only what you need, or find smaller alternative)

## Approval Workflow for Custom Implementation

When no suitable library exists and you believe custom implementation is required:

1. **Research phase** (20-30 min max):
   - Search crates.io / npm / GitHub for existing solutions
   - List 3-5 candidates with quick assessment
   - Document why each candidate was rejected

2. **Present findings**:
   ```
   Proposed custom implementation for: [functionality]
   
   Candidates evaluated:
   1. [crate/package] - [reason for rejection]
   2. [crate/package] - [reason for rejection]
   3. [crate/package] - [reason for rejection]
   
   Justification for custom implementation:
   - [specific reason]
   - [maintenance plan]
   
   Requesting approval to proceed with custom implementation.
   ```

3. **Get explicit approval** before writing code

4. **Document in codebase**:
   - Add README section explaining why custom
   - Include "Replaces: [candidate libraries]" comment
   - Set reminder to re-evaluate in 6 months

## Anti-Patterns to Avoid

### NIH (Not Invented Here) Syndrome
- Building custom JSON parser when `serde_json` exists
- Implementing custom crypto primitives (DANGEROUS)
- Writing custom HTTP client when `reqwest`/`ky` work
- Creating custom async runtime when `tokio` exists

### Premature Abstraction
- Building a "better" wrapper around a mature library without clear improvement
- Abstracting before understanding the domain
- Creating internal frameworks instead of using established ones

### Dependency Paranoia (without vetting)
- Refusing to use dependencies without evaluating them
- Building alternatives to well-maintained, audited libraries
- Not leveraging ecosystem solutions for irrational security theater

## Language-Specific Guidelines

### Rust
- Prefer `cargo add` over manual Cargo.toml editing
- Check `cargo tree -d` to understand duplicate dependencies
- Use `cargo audit` to check for security advisories
- Favor crates with `#![forbid(unsafe_code)]` when possible
- Prefer async-trait crates that are actively maintained
- For crypto: NEVER implement custom primitives. Always use audited crates.

### JavaScript/TypeScript
- Prefer `npm install` or package manager of choice
- Check `npm audit` regularly
- Favor ESM-native packages for new projects
- Evaluate bundle size impact with `npm run build` analysis
- Prefer zero-dependency or minimal-dependency packages
- Check Node.js version requirements align with project

### Python
- Prefer packages from PyPI with high download counts
- Check `pip-audit` for security issues
- Favor packages with type stubs or native typing
- Prefer packages with binary wheels (no compilation needed)
- Check maintenance via `pip show` and GitHub activity

## Periodic Review

**Quarterly dependency audit:**
1. Check for outdated dependencies (`cargo outdated`, `npm outdated`)
2. Review security advisories (`cargo audit`, `npm audit`)
3. Evaluate if custom implementations can now be replaced by libraries
4. Document any new quality concerns
5. Update this skill's trusted sources list based on experience

## Integration with Planning

When writing plans, include dependency analysis:

```markdown
### Dependencies to Evaluate
- [ ] `crate-name` for [purpose]
- [ ] Alternative: `other-crate`
- [ ] Custom implementation only if [specific condition]

### Library Selection Checkpoint
Before implementation phase:
- [ ] Candidate libraries evaluated
- [ ] Vetting criteria applied
- [ ] Decision documented
- [ ] Approval obtained (if custom)
```

## Success Metrics

A healthy project should have:
- >80% of non-trivial functionality from vetted dependencies
- <20% custom implementations (with documented justifications)
- Zero unaudited crypto implementations
- Regular dependency updates (within 1 month of security patches)
- Documented rationale for every custom implementation >100 lines

---

**Remember**: The goal is building the best product, not the most original code. Reuse is a competitive advantage—it lets you focus on your unique value proposition while leveraging battle-tested solutions for common problems.
