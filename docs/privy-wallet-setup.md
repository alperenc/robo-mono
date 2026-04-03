# Privy Wallet Setup

This project now supports a `Privy in code + AA endpoints in the Privy dashboard` wallet setup for embedded wallets, social login, and smart-wallet-ready transaction flows.

At runtime:

- if `NEXT_PUBLIC_PRIVY_APP_ID` is set, the web app uses Privy for login and wallet connection
- if it is not set, the app falls back to the existing RainbowKit-only path

## Environment

Add the following client-side variables in `web/.env.local` or your deployment environment:

```sh
NEXT_PUBLIC_PRIVY_APP_ID=your-privy-app-id
NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID=your-walletconnect-project-id
```

`NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID` is still used because Privy can expose external wallet connection flows that rely on WalletConnect.

No additional bundler or paymaster environment variables are required in this repo. Those values are configured in the Privy dashboard.

## Recommended Production Topology

For Roboshare, the recommended setup is:

- app code: `Privy`
- smart-wallet infrastructure configured inside Privy: `Pimlico`
- bundler URL: `Pimlico`
- paymaster URL: `Pimlico`

This keeps wallet and auth logic in one SDK while avoiding a second AA integration inside the frontend codebase.

## Dashboard Checklist

Configure the following in the Privy Dashboard before testing embedded smart-wallet flows:

1. Enable your desired login methods.
2. Enable embedded Ethereum wallets.
3. Enable smart wallets and select the smart wallet type for the app.
4. Configure the supported networks used by Roboshare:
   - `Sepolia`
   - `Polygon Amoy`
   - `Arbitrum Sepolia`
   - optionally `Base Sepolia`
5. For each smart-wallet network, provide:
   - a bundler URL
   - a paymaster URL if you want sponsored gas
6. Prefer dedicated Pimlico endpoints over the default Privy-offered rate-limited bundler for any serious testing or production traffic.

## Important Distinction

Privy exposes two different gas-related setup models:

1. Smart wallets:
   - used by this app's batched `wallet_sendCalls` path
   - require smart wallets to be enabled in the dashboard
   - require dashboard-configured bundler URLs
   - use dashboard-configured paymaster URLs for sponsored gas
2. Native gas sponsorship:
   - uses Privy's `useSendTransaction(..., { sponsor: true })` flow
   - is a separate execution path from the app's current wagmi-based contract writes

Roboshare currently uses the smart-wallet-ready wagmi path, not the `useSendTransaction` sponsorship path.

## Current App Behavior

The current integration includes:

- embedded wallet login via Privy
- external wallet connection via Privy
- automatic embedded Ethereum wallet creation for users without wallets
- Privy `SmartWalletsProvider` mounted in the app shell
- batched `approve + buy` when the connected wallet exposes atomic call support
- dynamic payment-token handling instead of hard-coded `MockUSDC`

## Next Production Step

To sponsor investor transactions end-to-end in production:

1. create Pimlico bundler and paymaster endpoints for the target chain
2. paste those URLs into the corresponding chain configuration in the Privy dashboard
3. restrict sponsorship to the Roboshare transaction surface you intend to subsidize
4. test the batched investor flows on this branch against that chain
