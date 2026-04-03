"use client";

import { DebugContracts } from "./_components/DebugContracts";
import { RequireAdmin } from "~~/components/RequireAdmin";

export default function Debug() {
  return (
    <RequireAdmin>
      <DebugContracts />
      <div className="text-center mt-8 bg-secondary p-10">
        <h1 className="text-4xl my-0">Contract Tools</h1>
        <p className="text-neutral">Internal admin utilities for direct protocol inspection and contract actions.</p>
      </div>
    </RequireAdmin>
  );
}
