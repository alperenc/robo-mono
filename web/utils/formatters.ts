/**
 * Formats a token amount to a human-readable string with 2 decimals.
 * Strictly rounds UP (ceiling) to the next cent to ensure collateral requirements are met in display.
 * Example (6 decimals): 1000001n (1.000001) -> "1.01"
 */
export const formatTokenAmount = (value: bigint | undefined, decimals = 6): string => {
  if (value === undefined) return "0.00";

  const safeDecimals = Number.isFinite(decimals) ? Math.max(0, Math.floor(decimals)) : 6;
  const decimalShift = safeDecimals > 2 ? safeDecimals - 2 : 0;
  const divisor = 10n ** BigInt(decimalShift);

  let base = value / divisor;
  const remainder = value % divisor;

  if (remainder > 0n) {
    base += 1n;
  }

  const dollars = base / 100n;
  const cents = base % 100n;

  const dollarString = new Intl.NumberFormat("en-US").format(dollars);
  const centString = cents.toString().padStart(2, "0");

  return `${dollarString}.${centString}`;
};
