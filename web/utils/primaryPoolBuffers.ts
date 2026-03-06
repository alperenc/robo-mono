const YEARLY_INTERVAL = 365n * 24n * 60n * 60n;
const QUARTERLY_INTERVAL = 90n * 24n * 60n * 60n;
const BP_PRECISION = 10000n;
const PROTOCOL_FEE_BP = 250n;

const calculateEarnings = (principal: bigint, timeElapsed: bigint, earningsBP: bigint) => {
  return (principal * timeElapsed * earningsBP) / (YEARLY_INTERVAL * BP_PRECISION);
};

export const calculatePrimaryPoolBuffers = (baseAmount: bigint, targetYieldBP: bigint, protectionEnabled: boolean) => {
  const protocolBuffer = calculateEarnings(baseAmount, QUARTERLY_INTERVAL, PROTOCOL_FEE_BP);
  const protectionBuffer = calculateEarnings(baseAmount, QUARTERLY_INTERVAL, targetYieldBP);
  const totalBuffer = protocolBuffer + (protectionEnabled ? protectionBuffer : 0n);

  return {
    protocolBuffer,
    protectionBuffer,
    totalBuffer,
  };
};
