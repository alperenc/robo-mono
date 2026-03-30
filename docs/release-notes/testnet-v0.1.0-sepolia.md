# Testnet v0.1.0 Sepolia Release Record

- Chain: `Sepolia`
- Chain ID: `11155111`
- Deploy script: `Deploy.s.sol`
- Deploy source commit: `1f6c624`
- Broadcast file: `protocols/evm/broadcast/Deploy.s.sol/11155111/run-1774897033665.json`
- First deployment block: `10555421`
- Graph network: `sepolia`
- Managed subgraph endpoint: `https://api.studio.thegraph.com/query/1745285/roboshare-protocol/v0.1.0-sepolia.2`

## Deployed Addresses

- `MockUSDC`: `0x0488828713720Cb7d4DF39B739eC0a92F774c7b8`
- `RoboshareTokens`: `0xd739AfD4C1280c49e7CBa5265308eB604969D776`
- `PartnerManager`: `0x2220d39463bF1c1cbC5DF665f368609E7A71a573`
- `RegistryRouter`: `0xC6ABDc71072B7797351B34Cb44BD663702A2eFD8`
- `VehicleRegistry`: `0x6e9Ec5D4eB71dcB5e53B12C3E4cC93C4Da48b631`
- `Treasury`: `0xde824AeeaC6C980d7018CF5D38d33CA92631Ebe8`
- `EarningsManager`: `0x0C26eeC91728C865988F2F56b6DFBC2D075D8882`
- `Marketplace`: `0xEc456f8d3ABBbaF5195355b85aebCb16817e8391`

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
- Managed subgraph deployment uses the shared Studio slug `roboshare-protocol`; later publishes for other chains may archive older Studio versions until they are unarchived again.
