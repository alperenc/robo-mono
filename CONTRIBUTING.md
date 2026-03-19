# Contributing to Roboshare

Thank you for contributing to Roboshare.

This repository contains the smart contracts, subgraph, and web application for the Roboshare testnet release.
Read [README.md](README.md) first for product context and supported testnets.

## Project Status

The project is under active development and currently focused on a staged public testnet launch.

Current priorities:

- release reliability
- Sepolia-first product quality
- launch documentation
- partner and tester feedback loops

## How to Contribute

Contributions are welcome in these areas:

- bug fixes
- test coverage
- docs improvements
- launch-readiness improvements
- UX and reliability issues

Before opening new work:

- search existing issues and PRs first
- keep changes scoped to one concern
- if behavior changes, update docs where appropriate

## Reporting Issues

When reporting a bug, include:

- the target chain
- the wallet used
- the transaction hash, if any
- expected behavior
- actual behavior
- reproduction steps
- screenshots or short recordings when useful

## Pull Requests

We follow a fork-and-pull workflow.

Recommended process:

1. branch from the current target branch
2. keep the PR focused on a single concern
3. include validation steps in the PR description
4. update docs if the user-facing behavior changed
5. respond to review comments and resolve conversations clearly

PR guidance:

- prefer descriptive branch names with the existing repo conventions
- use clear commit messages
- include screenshots for UI changes when relevant
- avoid mixing unrelated refactors into launch-critical work

Merge policy:

- PRs are generally squash-merged
- launch-critical fixes should remain easy to trace in the PR description

## Validation Expectations

At minimum, contributors should run the checks relevant to their change, such as:

- `yarn evm:test`
- `yarn web:check-types`
- `yarn web:build`
- `yarn evm:lint`

If a change affects deploy, verify, or release behavior, mention that explicitly in the PR.
