"use client";

import { useEffect, useState } from "react";
import { PrivyProvider } from "@privy-io/react-auth";
import { SmartWalletsProvider } from "@privy-io/react-auth/smart-wallets";
import { WagmiProvider as PrivyWagmiProvider } from "@privy-io/wagmi";
import { RainbowKitProvider, darkTheme, lightTheme } from "@rainbow-me/rainbowkit";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { AppProgressBar as ProgressBar } from "next-nprogress-bar";
import { useTheme } from "next-themes";
import { Toaster } from "react-hot-toast";
import { WagmiProvider } from "wagmi";
import { Footer } from "~~/components/Footer";
import { Header } from "~~/components/Header";
import { BlockieAvatar } from "~~/components/scaffold-eth";
import { useInitializeNativeCurrencyPrice } from "~~/hooks/scaffold-eth";
import { TransactingAccountProvider } from "~~/hooks/useTransactingAccount";
import { getPrivyAppId, getPrivyConfig, isPrivyEnabled } from "~~/services/web3/privyConfig";
import { getWagmiConfig } from "~~/services/web3/wagmiConfig";

const ScaffoldEthApp = ({ children }: { children: React.ReactNode }) => {
  useInitializeNativeCurrencyPrice();

  return (
    <>
      <div className={`flex flex-col min-h-screen `}>
        <Header />
        <main className="relative flex flex-col flex-1">{children}</main>
        <Footer />
      </div>
      <Toaster />
    </>
  );
};

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      refetchOnWindowFocus: false,
    },
  },
});

const RainbowKitShell = ({ children, isDarkMode }: { children: React.ReactNode; isDarkMode: boolean }) => {
  return (
    <>
      <ProgressBar height="3px" color="#2299dd" />
      <RainbowKitProvider avatar={BlockieAvatar} theme={isDarkMode ? darkTheme() : lightTheme()}>
        <ScaffoldEthApp>{children}</ScaffoldEthApp>
      </RainbowKitProvider>
    </>
  );
};

export const ScaffoldEthAppWithProviders = ({ children }: { children: React.ReactNode }) => {
  const { resolvedTheme } = useTheme();
  const isDarkMode = resolvedTheme === "dark";
  const [mounted, setMounted] = useState(false);
  const [wagmiConfig, setWagmiConfig] = useState<ReturnType<typeof getWagmiConfig> | null>(null);

  useEffect(() => {
    setWagmiConfig(getWagmiConfig());
    setMounted(true);
  }, []);

  if (!mounted || !wagmiConfig) {
    return null;
  }

  const privyAppId = getPrivyAppId();

  if (isPrivyEnabled() && privyAppId) {
    return (
      <PrivyProvider appId={privyAppId} config={getPrivyConfig(isDarkMode ? "dark" : "light")}>
        <SmartWalletsProvider>
          <QueryClientProvider client={queryClient}>
            <PrivyWagmiProvider config={wagmiConfig}>
              <TransactingAccountProvider privyEnabled>
                <RainbowKitShell isDarkMode={isDarkMode}>{children}</RainbowKitShell>
              </TransactingAccountProvider>
            </PrivyWagmiProvider>
          </QueryClientProvider>
        </SmartWalletsProvider>
      </PrivyProvider>
    );
  }

  return (
    <QueryClientProvider client={queryClient}>
      <WagmiProvider config={wagmiConfig}>
        <TransactingAccountProvider privyEnabled={false}>
          <RainbowKitShell isDarkMode={isDarkMode}>{children}</RainbowKitShell>
        </TransactingAccountProvider>
      </WagmiProvider>
    </QueryClientProvider>
  );
};
