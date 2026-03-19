# Testnet Release, Launch, and Versioning Plan

## Summary

This document is the canonical internal plan for Roboshare's first public testnet release.
It merges the technical release plan, the launch and announcement plan, and the branching/versioning plan into one operational guide.

Current launch defaults:

- Default chain: `Sepolia`
- Additional supported testnets: `Polygon Amoy`, `Arbitrum Sepolia`
- Deferred for a later release: `Base Sepolia`
- Repo posture: public, `MIT`
- Launch sequence: `internal hardening -> quiet beta -> public testnet launch`
- Indexing: managed The Graph deployment path
- Incentives: none in the first public testnet cycle

## Goals and Release Principles

The goal of the first public testnet launch is to validate the end-to-end Roboshare product with real external users and partners, not to maximize hype before the system is usable.

Release principles:

- Ship a working product before broad promotion.
- Use `Sepolia` as the primary reference network in docs, QA, and support.
- Keep all public releases traceable to a release branch and Git tag.
- Announce only from a tagged, reproducible build.
- Rebrand all public-facing surfaces away from inherited Scaffold-ETH positioning before public launch.
- Keep launch scope disciplined; defer non-critical features if they threaten launch reliability.

## Phased Plan

### Phase 1: Release Foundations

Release management:

- Keep day-to-day development on `main`.
- Create feature branches from `main` for isolated work.
- Use a short-lived release branch for the launch line:
  - `release/testnet-v0.1.0`
- Use SemVer pre-release tags for launch stages:
  - `v0.1.0-internal.1`
  - `v0.1.0-beta.1`
  - `v0.1.0-testnet.1`
- Keep Git tags, GitHub releases, and deployment metadata as the source of truth for public releases.

Operational setup:

- Assign launch owners for:
  - deploy/release execution
  - issue triage
  - support/communications
  - hotfix ownership
- Decide the canonical support/reporting path before beta starts.
- Prepare one release-note template and one launch-day checklist.

Documentation setup:

- Rewrite `README.md` to describe Roboshare, not Scaffold-ETH.
- Rewrite `CONTRIBUTING.md` to reflect Roboshare's actual contribution expectations.
- Keep `LICENCE` as MIT and preserve upstream attribution correctly.

### Phase 2: Technical Readiness

Contracts and deployment:

- Complete deploy + verify flow for:
  - `Sepolia`
  - `Polygon Amoy`
  - `Arbitrum Sepolia`
- Treat `Sepolia` as the primary reference path and launch-default chain.
- Exclude `Base Sepolia` from the first public launch line and revisit it in a later release.
- Ensure deploy artifacts map cleanly to tagged commits.

Frontend and product UX:

- Make `Sepolia` the default selected chain in the app.
- Remove public-facing localhost and hardcoded local-chain assumptions.
- Hide or clearly scope local-only tools such as faucet/debug flows.
- Clean up public branding in the footer, metadata, and public copy.

Indexing and data:

- Use the managed The Graph deployment path for the first-launch supported testnets.
- Replace local-only indexing assumptions with chain-aware runtime configuration.
- Seed each chain with realistic demo state:
  - at least one partner
  - at least one registered asset
  - at least one primary pool
  - at least one listing

Launch docs and support materials:

- Add a public `Supported Testnets` section to the README.
- Add a public `How to Test Roboshare` section to the README.
- Add internal deploy, verify, seed, and rollback notes for launch operators.
- Prepare a tester bug-report template that asks for:
  - chain
  - wallet
  - tx hash
  - screenshot or screen recording
  - repro steps

### Phase 3: Quiet Beta

Branching and release cut:

- Cut `release/testnet-v0.1.0` from a green `main` commit only after Phase 2 is ready.
- Tag the first beta build as:
  - `v0.1.0-beta.1`
- Deploy quiet beta only from the release branch/tag, never from an untagged branch head.

Beta audience and distribution:

- Start with partners and trusted users via direct outreach.
- Ask testers to validate `Sepolia` first.
- Treat the other supported testnets as secondary validation targets during beta.

Quiet beta package:

- Beta app URL
- Supported chains
- Tester checklist
- Support channel
- Bug-report template
- Known limitations

Quiet beta exit criteria:

- Core Sepolia flows work end to end for invited testers.
- No blocker-level issue remains in:
  - wallet connection
  - chain switching
  - listings
  - purchases
  - withdrawals
  - indexed data freshness
- Public docs and support instructions are ready for broader external use.

Quiet beta fixes:

- Fix blockers against the active release branch.
- Tag additional beta/hotfix releases as needed.
- Merge all release-branch fixes back into `main`.

### Phase 4: Public Testnet Launch

Public release cut:

- Tag the public launch commit as:
  - `v0.1.0-testnet.1`
- Publish a matching GitHub release/changelog entry from that exact tag.
- Deploy the public app from that tagged commit only.

Public launch channels:

- Sequence:
  - partners/direct outreach first
  - then broad public posts on `X`, `Telegram`, and `Farcaster`
- Use Telegram as the live support and coordination channel during launch week.

Public launch package:

- app URL
- supported testnets
- default chain (`Sepolia`)
- known limitations
- bug-report path
- support channel

Post-launch stabilization:

- Track all issues in one launch board with severity and owner.
- Cut hotfixes from the release branch as needed and tag each one.
- Merge hotfixes back into `main`.
- Only after a stable post-launch window should the team expand awareness or consider broader campaigns.

## Concrete Launch Checklist

### Release Foundations Checklist

- [ ] Create release branch naming convention and tag naming convention
- [ ] Define release-note template
- [ ] Define support/triage/hotfix owners
- [ ] Decide launch support channel
- [ ] Draft README rewrite structure
- [ ] Draft CONTRIBUTING rewrite structure

### Technical Readiness Checklist

- [ ] Deploy contracts to `Sepolia`, `Polygon Amoy`, and `Arbitrum Sepolia`
- [ ] Verify contracts where explorer access is available
- [ ] Publish managed subgraphs for the first-launch supported testnets
- [ ] Wire chain-aware subgraph endpoints into the frontend
- [ ] Make `Sepolia` the default selected chain
- [ ] Remove localhost/31337 assumptions from public flows
- [ ] Seed demo data on each first-launch supported chain
- [ ] Remove inherited Scaffold-ETH/BuidlGuidl public branding

### Quiet Beta Checklist

- [ ] Cut `release/testnet-v0.1.0`
- [ ] Tag `v0.1.0-beta.1`
- [ ] Publish beta app build from the tagged release branch
- [ ] Send quiet-beta instructions to partners and trusted testers
- [ ] Collect structured feedback
- [ ] Fix blockers on the release branch
- [ ] Back-merge fixes to `main`

### Public Launch Checklist

- [ ] Finalize README and CONTRIBUTING rewrites
- [ ] Finalize launch posts and partner outreach copy
- [ ] Tag `v0.1.0-testnet.1`
- [ ] Publish GitHub release/changelog
- [ ] Deploy public app from the tagged commit
- [ ] Publish X, Telegram, and Farcaster launch posts
- [ ] Monitor support channel and issue board

## Branching and Versioning

### Branching Model

- `main` is the integration branch.
- Feature work happens on short-lived feature/fix branches.
- The active launch line is isolated on:
  - `release/testnet-v0.1.0`
- Launch blockers and hotfixes are fixed against the release branch first.
- Every fix shipped from the release branch must be merged back into `main`.

### Versioning Model

- Use pre-release SemVer tags for testnet lifecycle stages.
- Recommended first-cycle progression:
  - `v0.1.0-internal.1`
  - `v0.1.0-beta.1`
  - `v0.1.0-testnet.1`
- Use patch bumps for launch fixes:
  - `v0.1.1-testnet.2`
  - `v0.1.2-testnet.3`
- Use minor bumps when meaningful user-facing capability changes before mainnet:
  - example: `v0.2.0-testnet.1`

### Release Truth

Every public-facing release should be traceable through:

- Git tag
- GitHub release entry
- commit SHA
- deployed addresses
- subgraph endpoints
- known limitations

Do not treat the current monorepo `package.json` versions as the authoritative public release version.
If the app needs a visible release identifier later, prefer build metadata from CI or the Git tag.

## Docs and Public Rebrand

### README

The README should explain:

- what Roboshare is
- who it is for
- supported testnets
- default chain (`Sepolia`)
- how to try the product
- how to report issues

It should no longer read like a Scaffold-ETH starter repo quickstart.

### CONTRIBUTING

The contributing guide should explain:

- contribution workflow
- issue expectations
- PR expectations
- testing expectations
- code review norms

It should no longer point contributors at upstream Scaffold-ETH issue flows as if this repo were the upstream project.

### License

Best practice for this release cycle:

- keep `MIT`
- preserve upstream attribution
- add Roboshare-specific attribution/notice language only where needed

Do not create a restrictive license transition as part of the first public testnet launch.

## Announcement Plan

### Quiet Beta Messaging

Goals:

- validate core UX with real users
- catch operational issues before public attention
- collect structured partner/user feedback

Message shape:

- short direct outreach
- app URL
- supported chains
- what to test
- where to report issues

### Public Launch Messaging

Primary framing:

- Roboshare public testnet is live
- default chain is `Sepolia`
- first public release supports `Sepolia`, `Polygon Amoy`, and `Arbitrum Sepolia`
- users and partners should try the marketplace flows
- feedback is wanted on real usage, not speculative hype

Required assets:

- one X thread
- one Telegram launch post
- one Farcaster post
- one partner outreach message
- one tester instruction message

### Messaging Priorities

- Be explicit about current scope and known limits.
- Keep the first public cycle focused on feedback quality.
- Do not run incentives or public quests in the first cycle.
- Avoid signaling “mainnet imminence” unless it is actually true.

## Acceptance Criteria

The unified launch plan is considered executed correctly only if:

- public deployments come from tagged release-branch commits
- Sepolia is the default chain in the product and docs
- all public-facing docs and app surfaces are Roboshare-branded
- quiet beta happens before public launch
- the public launch includes release notes and support instructions
- every shipped fix is traceable back to a release tag and commit SHA

## Assumptions

- `Sepolia` remains the primary/default network for beta and public launch.
- `Base Sepolia` is deferred to a later release line and is out of scope for the first public launch.
- The repo remains public and MIT-licensed for this cycle.
- Managed The Graph indexing is available for the first-launch supported testnets.
- Smart-wallet work is not on the critical path unless the base wallet UX proves inadequate.
- There is only one active public testnet release line at a time.
- No incentives are used during the first public testnet cycle.
