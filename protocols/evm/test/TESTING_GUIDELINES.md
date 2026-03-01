# EVM Testing Guidelines

## Core Rule
Prefer reachable public or authorized-contract flows over harness-based coverage.

The goal is to prove protocol behavior as it can actually occur, not to maximize branch counts with synthetic state.

## What Good Tests Look Like

### Integration tests
Files matching `*.Integration.t.sol` should cover:
- user flows
- partner flows
- router/registry/marketplace/treasury interactions
- valid fixture setup that produces real protocol states

They should not:
- expose internal functions through ad hoc harnesses
- use `vm.store(...)` to fabricate impossible states
- create marketplace token inventory through stale listing-era shortcuts

### Library tests
`protocols/evm/test/Libraries.t.sol` is the right place for:
- direct library math tests
- raw enum validation
- malformed-struct defensive behavior
- injected periods or isolated accounting state needed to unit-test a library

This is acceptable because the subject under test is the library itself.

## When Helper Contracts Are Acceptable
Helper contracts are acceptable when they:
- expose pure or library behavior for direct unit testing
- hold in-memory or isolated storage for library calculations
- support valid multi-contract protocol scenarios

Examples:
- good: `AssetHelper` in `protocols/evm/test/Libraries.t.sol`
- good: `MockRegistry` in `protocols/evm/test/RegistryRouter.Integration.t.sol`

## When Harnesses Are Not Acceptable
Do not add harnesses when they only:
- expose internal functions that are not reachable in current protocol flow
- force invalid or impossible state to satisfy a coverage report
- preserve stale product semantics after the protocol changed

Examples:
- bad: exposing stale internal escrow mint path in router integration tests
- bad: storage-forced `_clearCollateral(...)` path in treasury integration tests

## Coverage Waivers
Known unreachable or helper-only coverage artifacts should be recorded in:
- `protocols/evm/scripts-js/coverage-waivers.json`

Allowed classifications:
- `helper_only`
- `unreachable_valid_flow`
- `via_ir_artifact`

Use a waiver when:
- the branch only makes sense in direct library helper tests
- the branch cannot occur through valid public protocol flows
- the branch is misreported under `--ir-minimum` / `viaIR`

Do not use a waiver to hide a real missing behavioral test.

## Practical Review Question
Before adding a test helper or harness, ask:

`Can this state arise through any valid protocol path?`

If the answer is:
- `yes`: build the scenario through normal fixtures and real calls
- `no`: either move the test into direct library/unit coverage or waive it if it is not meaningful behavior
