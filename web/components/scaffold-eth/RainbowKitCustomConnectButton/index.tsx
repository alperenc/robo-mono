"use client";

// @refresh reset
import { Balance } from "../Balance";
import { AddressInfoDropdown } from "./AddressInfoDropdown";
import { AddressQRCodeModal } from "./AddressQRCodeModal";
import { WrongNetworkDropdown } from "./WrongNetworkDropdown";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import { Address, formatUnits } from "viem";
import { useNetworkColor, useWatchTokenBalance } from "~~/hooks/scaffold-eth";
import { useTargetNetwork } from "~~/hooks/scaffold-eth/useTargetNetwork";
import { usePaymentToken } from "~~/hooks/usePaymentToken";
import { getBlockExplorerAddressLink } from "~~/utils/scaffold-eth";

const ConnectedWalletSummary = ({ address, chainName }: { address: Address; chainName?: string }) => {
  const networkColor = useNetworkColor();
  const {
    address: paymentTokenAddress,
    symbol: paymentTokenSymbol,
    decimals: paymentTokenDecimals,
  } = usePaymentToken();
  const { data: paymentTokenBalance } = useWatchTokenBalance({
    tokenAddress: paymentTokenAddress,
    ownerAddress: address,
  });

  const formattedPaymentTokenBalance =
    paymentTokenBalance !== undefined
      ? Number(formatUnits(paymentTokenBalance as bigint, paymentTokenDecimals)).toLocaleString(undefined, {
          minimumFractionDigits: 2,
          maximumFractionDigits: 2,
        })
      : null;

  return (
    <div className="hidden sm:block mr-2 text-right leading-tight">
      <Balance address={address} className="min-h-0 h-auto p-0 justify-end ml-auto" />
      {formattedPaymentTokenBalance !== null ? (
        <span className="block text-xs font-medium text-base-content/70">
          {formattedPaymentTokenBalance} {paymentTokenSymbol}
        </span>
      ) : null}
      {chainName ? (
        <span className="block text-[11px]" style={{ color: networkColor }}>
          {chainName}
        </span>
      ) : null}
    </div>
  );
};

/**
 * Custom Wagmi Connect Button (watch balance + custom design)
 */
export const RainbowKitCustomConnectButton = () => {
  const { targetNetwork } = useTargetNetwork();

  return (
    <ConnectButton.Custom>
      {({ account, chain, openConnectModal, mounted }) => {
        const connected = mounted && account && chain;
        const blockExplorerAddressLink = account
          ? getBlockExplorerAddressLink(targetNetwork, account.address)
          : undefined;

        return (
          <>
            {(() => {
              if (!connected) {
                return (
                  <button className="btn btn-primary btn-sm" onClick={openConnectModal} type="button">
                    Connect Wallet
                  </button>
                );
              }

              if (chain.unsupported || chain.id !== targetNetwork.id) {
                return <WrongNetworkDropdown />;
              }

              return (
                <>
                  <div className="flex flex-col items-end">
                    <div className="flex items-center">
                      <ConnectedWalletSummary address={account.address as Address} chainName={chain.name} />
                      <AddressInfoDropdown
                        address={account.address as Address}
                        displayName={account.displayName}
                        ensAvatar={account.ensAvatar}
                        blockExplorerAddressLink={blockExplorerAddressLink}
                        chainName={chain.name}
                      />
                    </div>
                  </div>
                  <AddressQRCodeModal address={account.address as Address} modalId="qrcode-modal" />
                </>
              );
            })()}
          </>
        );
      }}
    </ConnectButton.Custom>
  );
};
