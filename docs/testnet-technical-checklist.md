# Testnet Technical Checklist

## Summary

This document is the non-sensitive operator checklist for Roboshare's first public testnet release.
It focuses on deploy, verify, indexing, frontend wiring, seeded data, and smoke-test readiness for the supported launch networks.

Supported launch networks:

- `Sepolia` (default)
- `Polygon Amoy`
- `Arbitrum Sepolia`

Deferred:

- `Base Sepolia`

## Release Foundations Checklist

- [ ] Confirm the release branch name:
  - `release/testnet-v0.1.0`
- [ ] Confirm the launch-stage tags:
  - `v0.1.0-internal.1`
  - `v0.1.0-beta.1`
  - `v0.1.0-testnet.1`
- [ ] Confirm the release-note template includes:
  - commit SHA
  - default chain
  - supported chains
  - deployed addresses
  - subgraph endpoints
  - known limitations

## Contracts And Deployment Checklist

- [ ] Deploy contracts to `Sepolia`
- [ ] Deploy contracts to `Polygon Amoy`
- [ ] Deploy contracts to `Arbitrum Sepolia`
- [ ] Preserve deploy artifacts for each chain
- [ ] Regenerate frontend contract metadata after each deploy
- [ ] Confirm the generated frontend contract map contains every supported launch chain

Verification:

- [ ] Verify `Sepolia` contracts where explorer access is available
- [ ] Verify `Polygon Amoy` contracts where explorer access is available
- [ ] Verify `Arbitrum Sepolia` contracts where explorer access is available
- [ ] Record any verification exception explicitly in the release notes

## Managed Subgraph Deployment Checklist

For each supported launch chain, record:

- [ ] Graph network name
- [ ] deployed contract address
- [ ] start block
- [ ] resulting Graph endpoint

Build and publish flow:

- [ ] Run `yarn subgraph:abi-copy`
- [ ] Run `yarn subgraph:codegen`
- [ ] Run `yarn subgraph:build`
- [ ] Authenticate Graph CLI with `yarn graph auth --studio <DEPLOY_KEY>`
- [ ] Deploy with `yarn subgraph:deploy`
- [ ] Capture the resulting Studio endpoint
- [ ] Wire the endpoint into the frontend's chain-aware configuration
- [ ] Confirm the deployed endpoint reflects fresh writes from the contracts

Local graph-node is for development only and should not be treated as the public testnet release path.

## Frontend Checklist

- [ ] Make `Sepolia` the default selected chain
- [ ] Confirm supported chain list matches the release scope
- [ ] Remove or guard localhost and local-chain assumptions from public flows
- [ ] Hide or clearly scope local-only debug or faucet features
- [ ] Confirm public-facing branding is Roboshare-specific and not starter-template boilerplate

## Demo Data Checklist

For each supported launch chain:

- [ ] authorize at least one partner
- [ ] register at least one asset
- [ ] create at least one primary pool
- [ ] create at least one listing

## Smoke Tests

Per supported launch chain:

- [ ] wallet connects successfully
- [ ] chain switching works
- [ ] partner flow works end to end
- [ ] listing flow works end to end
- [ ] purchase flow works end to end
- [ ] withdrawal flow works end to end
- [ ] indexed data appears correctly
- [ ] explorer verification links resolve correctly where verification is available

Cross-chain:

- [ ] switching chains updates addresses, reads, and indexed data without stale cache bleed

## Quiet Beta Readiness

- [ ] deploy the beta app from a tagged release-branch commit
- [ ] publish supported-chain guidance for testers
- [ ] publish bug-report instructions for testers
- [ ] confirm known limitations are documented
- [ ] confirm no blocker-level issue remains in the Sepolia-first user path

## Public Launch Readiness

- [ ] tag `v0.1.0-testnet.1`
- [ ] publish the GitHub release from that tag
- [ ] confirm the public app deploy maps to the tagged commit
- [ ] confirm the public docs match the actual supported launch scope
- [ ] confirm support instructions are ready

## Per-Chain Release Record Template

Record one entry per supported launch chain in the release notes:

- chain
- chain id
- deployed contract addresses
- verification status
- subgraph endpoint
- start block
- seeded demo state status
- known chain-specific limitations
