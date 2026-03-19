# Testnet Release Strategy

## Summary

This document captures the non-sensitive release strategy for Roboshare's first public testnet cycle.
It covers phase ordering, release gates, branching, versioning, and launch messaging at a level that should stay versioned with the codebase.

Current release defaults:

- Default chain: `Sepolia`
- Additional supported testnets: `Polygon Amoy`, `Arbitrum Sepolia`
- Deferred to a later release line: `Base Sepolia`
- Repo posture: public, `MIT`
- Launch sequence: `internal hardening -> quiet beta -> public testnet launch`
- Indexing: managed The Graph deployment path
- Incentives: none in the first public testnet cycle

## Release Principles

- Ship a working product before broad promotion.
- Use `Sepolia` as the primary reference network in docs, QA, and support.
- Keep every public release traceable to a release branch and Git tag.
- Announce only from a tagged, reproducible build.
- Keep public-facing surfaces clearly branded as Roboshare while preserving Scaffold-ETH attribution.
- Defer non-critical features if they threaten launch reliability.

## Phase Ordering

### Phase 1: Release Foundations

- Keep day-to-day development on `main`.
- Create short-lived feature or fix branches from `main`.
- Prepare the first release branch:
  - `release/testnet-v0.1.0`
- Use pre-release tags for launch stages:
  - `v0.1.0-internal.1`
  - `v0.1.0-beta.1`
  - `v0.1.0-testnet.1`
- Define the release-note format before beta begins.

### Phase 2: Technical Readiness

- Complete deploy and verify flow for `Sepolia`, `Polygon Amoy`, and `Arbitrum Sepolia`.
- Make `Sepolia` the default chain in the product and docs.
- Replace public-facing localhost assumptions with chain-aware configuration.
- Publish managed The Graph deployments for the supported launch networks.
- Seed realistic demo state on each supported launch chain.
- Finish the public-facing README and CONTRIBUTING cleanup before beta.

### Phase 3: Quiet Beta

- Cut `release/testnet-v0.1.0` only from a green `main` commit.
- Tag the first beta build as `v0.1.0-beta.1`.
- Deploy quiet beta only from the tagged release branch.
- Start with partners and trusted users through direct outreach.
- Treat `Sepolia` as the primary beta path and the other supported testnets as secondary validation targets.
- Fix launch blockers on the release branch and merge them back into `main`.

### Phase 4: Public Testnet Launch

- Tag the public launch commit as `v0.1.0-testnet.1`.
- Publish the matching GitHub release from that exact tag.
- Announce only after quiet beta exit criteria are met.
- Sequence launch channels:
  - partners/direct outreach first
  - then `X`, `Telegram`, and `Farcaster`
- Use a short post-launch stabilization window before any broader campaign.

## Quiet Beta And Public Launch Gates

Quiet beta is ready only when:

- core `Sepolia` flows work end to end
- no blocker-level issues remain in wallet connection, chain switching, listings, purchases, withdrawals, or indexed data freshness
- public-facing docs are accurate enough for external testers

Public launch is ready only when:

- quiet beta passed
- the app is deployed from a tagged release-branch commit
- release notes are prepared
- support instructions and bug-report instructions are ready
- all public-facing product surfaces are aligned with the current launch scope

## Branching And Versioning

### Branching Model

- `main` is the integration branch.
- Feature work happens on short-lived feature and fix branches.
- The active launch line is isolated on `release/testnet-v0.1.0`.
- Launch blockers and hotfixes are fixed on the release branch first.
- Every release-branch fix shipped externally must be merged back into `main`.

### Versioning Model

- Use pre-release SemVer tags for the testnet lifecycle.
- Recommended first-cycle progression:
  - `v0.1.0-internal.1`
  - `v0.1.0-beta.1`
  - `v0.1.0-testnet.1`
- Use patch bumps for launch fixes.
- Use minor bumps for meaningful user-facing capability changes before mainnet.

### Release Truth

Every public-facing release should be traceable through:

- Git tag
- GitHub release entry
- commit SHA
- deployed addresses
- subgraph endpoints
- known limitations

Do not treat monorepo `package.json` versions as the public release truth.

## Announcement Plan

### Quiet Beta Messaging

- keep outreach direct and narrow
- include the app URL, supported chains, what to test, and how to report issues
- ask testers to start on `Sepolia`

### Public Launch Messaging

Primary framing:

- Roboshare public testnet is live
- `Sepolia` is the default chain
- the first public release supports `Sepolia`, `Polygon Amoy`, and `Arbitrum Sepolia`
- feedback is wanted on real usage, not on speculative hype

Required assets:

- one X thread
- one Telegram launch post
- one Farcaster post
- one partner outreach message
- one tester instruction message

Messaging priorities:

- be explicit about current scope and known limits
- keep the first public cycle focused on feedback quality
- avoid incentives in the first cycle

## Public And Private Docs Split

Keep these materials in the repo:

- public architecture and developer documentation
- release strategy
- non-sensitive technical checklists

Keep these materials in a private ops system, such as a Linear doc:

- launch-day owner assignments
- exact support channels
- partner lists
- rollback decision process
- secret-adjacent operational details

## Assumptions

- `Sepolia` remains the primary/default launch network.
- `Base Sepolia` is out of scope for the first public launch.
- The repo remains public and MIT-licensed for this cycle.
- Managed The Graph indexing is available for the supported first-launch testnets.
- Smart-wallet work is not on the critical path unless the base wallet UX proves inadequate.
- There is only one active public testnet release line at a time.
