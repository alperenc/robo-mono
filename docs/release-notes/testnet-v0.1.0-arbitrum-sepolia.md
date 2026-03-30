# Testnet v0.1.0 Arbitrum Sepolia Release Record

- Chain: `Arbitrum Sepolia`
- Chain ID: `421614`
- Deploy script: `Deploy.s.sol`
- Deploy source commit: `a450592`
- Broadcast file: `protocols/evm/broadcast/Deploy.s.sol/421614/run-1774901495742.json`
- First deployment block: `255124696`
- Graph network: `arbitrum-sepolia`
- Managed subgraph endpoint: `pending redeploy after contract refresh`

## Deployed Addresses

- `MockUSDC`: `0x20896fD729BCA167df95d6a352a934E729486E74`
- `RoboshareTokens`: `0x3a88Df4a4548DB7387968576DDDDdea457C72dea`
- `PartnerManager`: `0x46c813123b15e59630F2960FB3C70e0501563206`
- `RegistryRouter`: `0x7d379E0a8edD6Fe73f05809f3b33f2F7D115E1F5`
- `VehicleRegistry`: `0x25c79d5b080535D9ADc34bC3a9f0Bb11Cb217522`
- `Treasury`: `0x25E58C66C730Cb0FC434F735450D209938B8Cf51`
- `EarningsManager`: `0x15590892f5F65c2a111f886477d7b4061c006F76`
- `Marketplace`: `0xB631aEc2dC4Cea4D2ADF2ba9d71C10bB67d9Ab2D`

## Verification Status

- `MockUSDC`: verified
- `RoboshareTokens`: verified
- `PartnerManager`: verified
- `RegistryRouter`: verified
- `VehicleRegistry`: verified
- `Treasury`: verified
- `EarningsManager`: verified
- `Marketplace`: verified
- Proxy contracts: verified
- Treasury fee recipient set from env at deploy time: `0xc16ce1da7d33d10a80842d1b501e135b21e84b92`

## Notes

- `RoboshareTokens` implementation verification now succeeds under `solc 0.8.28` with `optimizer_runs = 200`, `via_ir = true`, and `evm_version = cancun`.
- The previous managed subgraph version must be republished against this refreshed deployment before the release line is ready.
