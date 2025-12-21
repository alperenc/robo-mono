/**
 * Formats a BigInt USDC value (6 decimals) to a human-readable string with 2 decimals.
 * Strictly rounds UP (ceiling) to the next cent to ensure collateral requirements are met in display.
 * Example: 1000001n (1.000001) -> "1.01"
 */
export const formatUsdc = (value: bigint | undefined): string => {
  if (value === undefined) return "0.00";

  // We have 6 decimals. We want to display 2 decimals.
  // We need to divide by 10^(6-2) = 10^4 = 10000
  const divisor = 10000n;

  let base = value / divisor;
  const remainder = value % divisor;

  // Round up if there's any remainder
  if (remainder > 0n) {
    base += 1n;
  }

  // Now 'base' is the value in "cents"
  const dollars = base / 100n;
  const cents = base % 100n;

  // Add commas for thousands using Intl
  const dollarString = new Intl.NumberFormat("en-US").format(dollars);
  const centString = cents.toString().padStart(2, "0");

  return `${dollarString}.${centString}`;
};
