# Testnet v0.1.0 Arbitrum Sepolia Release Record

- Chain: `Arbitrum Sepolia`
- Chain ID: `421614`
- Deploy script: `Deploy.s.sol`
- Deploy source commit: `1c3c375`
- Broadcast file: `protocols/evm/broadcast/Deploy.s.sol/421614/run-latest.json`
- First deployment block: `254765990`
- Graph network: `arbitrum-sepolia`
- Managed subgraph endpoint: `https://api.studio.thegraph.com/query/1745285/roboshare-protocol/v0.1.0-arbitrum-sepolia.1`

## Deployed Addresses

- `MockUSDC`: `0x0bFAD385790a919B430dDE171b8b205fF462177B`
- `RoboshareTokens`: `0x7F53aa8860c254909467FBC7b29AeD125d78c94c`
- `PartnerManager`: `0x2B81c5792F48DD23c6Dd405FC94f164Db73E0CDC`
- `RegistryRouter`: `0xDE6FB62710B21EEf2d7a7a208F99D1C294e34867`
- `VehicleRegistry`: `0x65E61fE214B9DCecB799029ce98EE39fA58d093E`
- `Treasury`: `0x462B87524b3C1eCE703eA2B6731D0D9747803e97`
- `EarningsManager`: `0x2c5B1281290578539A79C9d60D701eE0cFc86B76`
- `Marketplace`: `0xd4d376947D8915595a1dCe24A24484B42b6bf58B`

## Verification Status

- `MockUSDC`: verified
- `PartnerManager`: verified
- `RegistryRouter`: verified
- `VehicleRegistry`: verified
- `Treasury`: verified
- `EarningsManager`: verified
- `Marketplace`: verified
- Proxy contracts: verified
- `RoboshareTokens` implementation at `0x2772cb9D74b7AFE07983562f7B4c3282acEAaaA5`: verification exception

## Known Limitations

- `RoboshareTokens` implementation verification on Arbiscan Sepolia failed with a bytecode mismatch after deployment. Treat this as the same explorer/tooling exception class already seen on Sepolia and Amoy unless a later manual verification succeeds.
- `TREASURY_FEE_RECIPIENT` still defaulted to the deployer on Arbitrum Sepolia because the current public-testnet deploy helpers still fall back to the deployer outside the future redeploy fix.
