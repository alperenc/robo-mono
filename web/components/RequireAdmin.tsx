"use client";

import { ReactNode, useEffect } from "react";
import { useRouter } from "next/navigation";
import { useIsAdmin } from "~~/hooks/useIsAdmin";

interface RequireAdminProps {
  children: ReactNode;
  redirectTo?: string;
}

/**
 * Wrapper component that only renders children if the connected wallet has DEFAULT_ADMIN_ROLE.
 * Redirects to home if not authorized.
 */
export function RequireAdmin({ children, redirectTo = "/" }: RequireAdminProps) {
  const { isAdmin, isLoading, isConnected } = useIsAdmin();
  const router = useRouter();

  useEffect(() => {
    // Only redirect if:
    // 1. User IS connected (so we can verify their role)
    // 2. NOT loading (query is complete)
    // 3. NOT admin (they don't have the role)
    if (isConnected && !isLoading && !isAdmin) {
      router.push(redirectTo);
    }
  }, [isAdmin, isLoading, isConnected, router, redirectTo]);

  // Show loading state while checking (only when connected)
  if (isConnected && isLoading) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[60vh] gap-4">
        <span className="loading loading-spinner loading-lg"></span>
        <p className="text-sm opacity-70">Checking access...</p>
      </div>
    );
  }

  // Not connected - prompt to connect
  if (!isConnected) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[60vh] gap-4">
        <h2 className="text-2xl font-bold">Connect Wallet</h2>
        <p className="text-sm opacity-70">Please connect your wallet to access this page.</p>
      </div>
    );
  }

  // Not admin - this shouldn't show as we redirect, but just in case
  if (!isAdmin) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[60vh] gap-4">
        <span className="loading loading-spinner loading-lg"></span>
        <p className="text-sm opacity-70">Redirecting...</p>
      </div>
    );
  }

  return <>{children}</>;
}
