"use client";

import { usePrivy } from "@privy-io/react-auth";
import { useConnectModal } from "@rainbow-me/rainbowkit";
import { isPrivyEnabled } from "~~/services/web3/privyConfig";

type ModalAuthActionButtonProps = {
  className?: string;
};

const PrivyModalAuthActionButton = ({ className }: ModalAuthActionButtonProps) => {
  const { ready, authenticated, login, connectOrCreateWallet } = usePrivy();

  return (
    <button
      type="button"
      className={className}
      disabled={!ready}
      onClick={() => {
        if (authenticated) {
          void connectOrCreateWallet();
          return;
        }

        void login();
      }}
    >
      {!ready ? "Loading..." : authenticated ? "Open Wallet to Continue" : "Log In to Continue"}
    </button>
  );
};

const LegacyModalAuthActionButton = ({ className }: ModalAuthActionButtonProps) => {
  const { openConnectModal } = useConnectModal();

  return (
    <button type="button" className={className} disabled={!openConnectModal} onClick={() => openConnectModal?.()}>
      {openConnectModal ? "Connect Wallet to Continue" : "Loading..."}
    </button>
  );
};

export const ModalAuthActionButton = (props: ModalAuthActionButtonProps) => {
  return isPrivyEnabled() ? <PrivyModalAuthActionButton {...props} /> : <LegacyModalAuthActionButton {...props} />;
};
