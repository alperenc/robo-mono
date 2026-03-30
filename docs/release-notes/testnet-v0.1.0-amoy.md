# Testnet v0.1.0 Polygon Amoy Release Record

- Chain: `Polygon Amoy`
- Chain ID: `80002`
- Deploy script: `Deploy.s.sol`
- Deploy source commit: `71ec3e9`
- Broadcast file: `protocols/evm/broadcast/Deploy.s.sol/80002/run-1774898211481.json`
- First deployment block: `35884945`
- Graph network: `polygon-amoy`
- Managed subgraph endpoint: `https://api.studio.thegraph.com/query/1745285/roboshare-protocol/v0.1.0-amoy.1`

## Deployed Addresses

- `MockUSDC`: `0x9cbb0f294084dC1D2c88eBE88926c6339d5DaeaB`
- `RoboshareTokens`: `0xa9347dB6B85eA6c079Dc42A001921b480eebcBe0`
- `PartnerManager`: `0x9a38Df0Ef0C0BaAA418Be25363970bd71372dbC6`
- `RegistryRouter`: `0xCEB1Cb04B914fF2aB9d3DaA543536A6b662d265f`
- `VehicleRegistry`: `0x20896fD729BCA167df95d6a352a934E729486E74`
- `Treasury`: `0x73C84698f265c23E93fa23c338c9cc2db632b2a9`
- `EarningsManager`: `0x62E125007BBa8223951D41bcf13940c848F52d7B`
- `Marketplace`: `0x6C909F0C98126d4CD9b875cAaB472a31018F441c`

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
- Managed subgraph deployment should use the Graph network identifier `polygon-amoy`.
