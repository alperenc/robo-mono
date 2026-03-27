# Testnet v0.1.0 Sepolia Release Record

- Chain: `Sepolia`
- Chain ID: `11155111`
- Deploy script: `Deploy.s.sol`
- Deploy source commit: `0092f3a`
- Broadcast file: `protocols/evm/broadcast/Deploy.s.sol/11155111/run-1774602745127.json`
- First deployment block: `10531676`

## Deployed Addresses

- `MockUSDC`: `0x44E46A2ab9f70c31C0B1A59A93a47dC1228542c3`
- `RoboshareTokens`: `0xadb21069c84137A222F0cd19F055EAF2664e6A09`
- `PartnerManager`: `0x476eDD9b72a265BAeC48D8dc52520FC25e67CDB0`
- `RegistryRouter`: `0x253036b8EeBce9a4291e8803b8dbbE0d84FFa71f`
- `VehicleRegistry`: `0xD354d2AFBe2392082DE611503F333Bb2b2C41430`
- `Treasury`: `0xd0873Ee52DAecD392f97980E9FB934e487995e16`
- `EarningsManager`: `0x6e03547Dc90E060b20f5c9F689D76fcC475C2ab7`
- `Marketplace`: `0xD3Dc47372BB360822212F7E7159D0DB5fdCA8A85`

## Verification Status

- `MockUSDC`: verified
- `PartnerManager`: verified
- `RegistryRouter`: verified
- `VehicleRegistry`: verified
- `Treasury`: verified
- `EarningsManager`: verified
- `Marketplace`: verified
- Proxy contracts: verified
- `RoboshareTokens` implementation at `0x0C883Ea9EcD2228677BbbEe1C52D76c3cE6865cA`: verification exception

## Known Limitation

- `RoboshareTokens` implementation verification on Sepolia Etherscan failed with a bytecode mismatch despite a clean local rebuild matching the deployed initcode byte-for-byte. Treat this as an explorer/tooling exception for this release line unless a later manual verification succeeds.
