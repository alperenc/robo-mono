// Privy conditionally imports this package only inside Farcaster mini-app contexts.
// A local no-op shim keeps Next from failing module resolution when the optional
// dependency is not installed in standard web builds.
export {};
