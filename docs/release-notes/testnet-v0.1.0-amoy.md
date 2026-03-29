# Testnet v0.1.0 Polygon Amoy Release Record

- Chain: `Polygon Amoy`
- Chain ID: `80002`
- Deploy script: `Deploy.s.sol`
- Deploy source commit: `d7c3838`
- Broadcast file: `protocols/evm/broadcast/Deploy.s.sol/80002/run-1774785212039.json`
- First deployment block: `35828813`
- Graph network: `polygon-amoy`
- Managed subgraph endpoint: `https://api.studio.thegraph.com/query/1745285/roboshare-protocol/v0.1.0-amoy.1`

## Deployed Addresses

- `MockUSDC`: `0xA1353ccD55F09Af47de80828E06F7669998f811C`
- `RoboshareTokens`: `0xb86D8392b96C1F6DdFa79bc8c3e90cC81C248FD1`
- `PartnerManager`: `0x9f0b752c8170bb329DDb27F3381DDB662D5d532b`
- `RegistryRouter`: `0xdc76F725D9319758DdF9bFC7FC155399Ec957F63`
- `VehicleRegistry`: `0xB6B045d7Eb6Fe5b63715C9f9BA385B11ED9a2a9E`
- `Treasury`: `0x7F53aa8860c254909467FBC7b29AeD125d78c94c`
- `EarningsManager`: `0x2B81c5792F48DD23c6Dd405FC94f164Db73E0CDC`
- `Marketplace`: `0xDE6FB62710B21EEf2d7a7a208F99D1C294e34867`

## Verification Status

- `MockUSDC`: verified
- `PartnerManager`: verified
- `RegistryRouter`: verified
- `VehicleRegistry`: verified
- `Treasury`: verified
- `EarningsManager`: verified
- `Marketplace`: verified
- Proxy contracts: verified
- `RoboshareTokens` implementation at `0x96f62C9d0716E9B94a49232a2895d090CA9CF379`: verification exception

## Known Limitations

- `RoboshareTokens` implementation verification on Polygon Amoy Polygonscan failed with a bytecode mismatch after deployment. Treat this as the same explorer/tooling exception class already seen on Sepolia unless a later manual verification succeeds.
- `TREASURY_FEE_RECIPIENT` still defaulted to the deployer on Amoy because the current public-testnet deploy helpers fall back to the deployer outside the future redeploy fix.
- Managed subgraph deployment should use the Graph network identifier `polygon-amoy`.
