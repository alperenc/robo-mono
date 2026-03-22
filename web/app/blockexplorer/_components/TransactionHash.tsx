import Link from "next/link";
import { hardhat } from "viem/chains";
import { CheckCircleIcon, DocumentDuplicateIcon } from "@heroicons/react/24/outline";
import { useTargetNetwork } from "~~/hooks/scaffold-eth";
import { useCopyToClipboard } from "~~/hooks/scaffold-eth/useCopyToClipboard";
import { getBlockExplorerTxLink } from "~~/utils/scaffold-eth";

export const TransactionHash = ({ hash }: { hash: string }) => {
  const { copyToClipboard: copyAddressToClipboard, isCopiedToClipboard: isAddressCopiedToClipboard } =
    useCopyToClipboard();
  const { targetNetwork } = useTargetNetwork();
  const isLocalNetwork = targetNetwork.id === hardhat.id;
  const txHref = isLocalNetwork ? `/blockexplorer/transaction/${hash}` : getBlockExplorerTxLink(targetNetwork.id, hash);

  return (
    <div className="flex items-center">
      <Link
        href={txHref || "#"}
        target={isLocalNetwork ? undefined : "_blank"}
        rel={isLocalNetwork ? undefined : "noopener noreferrer"}
      >
        {hash?.substring(0, 6)}...{hash?.substring(hash.length - 4)}
      </Link>
      {isAddressCopiedToClipboard ? (
        <CheckCircleIcon
          className="ml-1.5 text-xl font-normal text-base-content h-5 w-5 cursor-pointer"
          aria-hidden="true"
        />
      ) : (
        <DocumentDuplicateIcon
          className="ml-1.5 text-xl font-normal h-5 w-5 cursor-pointer"
          aria-hidden="true"
          onClick={() => copyAddressToClipboard(hash)}
        />
      )}
    </div>
  );
};
