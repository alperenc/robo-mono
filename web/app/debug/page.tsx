"use client";

import { DebugContracts } from "./_components/DebugContracts";
import { RequireAdmin } from "~~/components/RequireAdmin";

export default function Debug() {
  return (
    <RequireAdmin>
      <DebugContracts />
      <div className="text-center mt-8 bg-secondary p-10">
        <h1 className="text-4xl my-0">Debug Contracts</h1>
        <p className="text-neutral">
          You can debug &amp; interact with your deployed contracts here.
          <br /> Check{" "}
          <code className="italic bg-base-300 text-base font-bold [word-spacing:-0.5rem] px-1">
            web / app / debug / page.tsx
          </code>{" "}
        </p>
      </div>
    </RequireAdmin>
  );
}
