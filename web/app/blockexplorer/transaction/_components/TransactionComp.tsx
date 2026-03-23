"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { Hash, Transaction, TransactionReceipt, formatEther, formatUnits } from "viem";
import { hardhat } from "viem/chains";
import { usePublicClient } from "wagmi";
import { Address } from "~~/components/scaffold-eth";
import { useTargetNetwork } from "~~/hooks/scaffold-eth/useTargetNetwork";
import { decodeTransactionData, getFunctionDetails } from "~~/utils/scaffold-eth";
import { replacer } from "~~/utils/scaffold-eth/common";
import { getBlockExplorerTxLink } from "~~/utils/scaffold-eth/networks";

const TransactionComp = ({ txHash }: { txHash: Hash }) => {
  const client = usePublicClient({ chainId: hardhat.id });
  const router = useRouter();
  const [transaction, setTransaction] = useState<Transaction>();
  const [receipt, setReceipt] = useState<TransactionReceipt>();
  const [functionCalled, setFunctionCalled] = useState<string>();

  const { targetNetwork } = useTargetNetwork();
  const isLocalNetwork = targetNetwork.id === hardhat.id;

  useEffect(() => {
    if (txHash && client) {
      const fetchTransaction = async () => {
        const tx = await client.getTransaction({ hash: txHash });
        const receipt = await client.getTransactionReceipt({ hash: txHash });

        const transactionWithDecodedData = decodeTransactionData(tx);
        setTransaction(transactionWithDecodedData);
        setReceipt(receipt);

        const functionCalled = transactionWithDecodedData.input.substring(0, 10);
        setFunctionCalled(functionCalled);
      };

      fetchTransaction();
    }
  }, [client, txHash]);

  if (!isLocalNetwork) {
    return (
      <div className="container mx-auto mt-10 mb-20 px-10 md:px-0">
        <button className="btn btn-sm btn-primary mb-6" onClick={() => router.back()}>
          Back
        </button>
        <div className="rounded-3xl border border-base-300 bg-base-100 p-8 shadow-lg">
          <h2 className="text-3xl font-bold mb-4">External Explorer Only</h2>
          <p className="text-base-content/70 mb-6">
            Transaction details for testnets are shown in the network&apos;s external explorer.
          </p>
          <Link
            href={getBlockExplorerTxLink(targetNetwork.id, txHash) || "#"}
            target="_blank"
            rel="noopener noreferrer"
            className="btn btn-primary"
          >
            Open in {targetNetwork.blockExplorers?.default?.name || `${targetNetwork.name} Explorer`}
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="container mx-auto mt-10 mb-20 px-10 md:px-0">
      <button className="btn btn-sm btn-primary" onClick={() => router.back()}>
        Back
      </button>
      {transaction ? (
        <div className="overflow-x-auto">
          <h2 className="text-3xl font-bold mb-4 text-center text-primary-content">Transaction Details</h2>{" "}
          <table className="table rounded-lg bg-base-100 w-full shadow-lg md:table-lg table-md">
            <tbody>
              <tr>
                <td>
                  <strong>Transaction Hash:</strong>
                </td>
                <td>{transaction.hash}</td>
              </tr>
              <tr>
                <td>
                  <strong>Block Number:</strong>
                </td>
                <td>{Number(transaction.blockNumber)}</td>
              </tr>
              <tr>
                <td>
                  <strong>From:</strong>
                </td>
                <td>
                  <Address address={transaction.from} format="long" onlyEnsOrAddress />
                </td>
              </tr>
              <tr>
                <td>
                  <strong>To:</strong>
                </td>
                <td>
                  {!receipt?.contractAddress ? (
                    transaction.to && <Address address={transaction.to} format="long" onlyEnsOrAddress />
                  ) : (
                    <span>
                      Contract Creation:
                      <Address address={receipt.contractAddress} format="long" onlyEnsOrAddress />
                    </span>
                  )}
                </td>
              </tr>
              <tr>
                <td>
                  <strong>Value:</strong>
                </td>
                <td>
                  {formatEther(transaction.value)} {targetNetwork.nativeCurrency.symbol}
                </td>
              </tr>
              <tr>
                <td>
                  <strong>Function called:</strong>
                </td>
                <td>
                  <div className="w-full md:max-w-[600px] lg:max-w-[800px] overflow-x-auto whitespace-nowrap">
                    {functionCalled === "0x" ? (
                      "This transaction did not call any function."
                    ) : (
                      <>
                        <span className="mr-2">{getFunctionDetails(transaction)}</span>
                        <span className="badge badge-primary font-bold">{functionCalled}</span>
                      </>
                    )}
                  </div>
                </td>
              </tr>
              <tr>
                <td>
                  <strong>Gas Price:</strong>
                </td>
                <td>{formatUnits(transaction.gasPrice || 0n, 9)} Gwei</td>
              </tr>
              <tr>
                <td>
                  <strong>Data:</strong>
                </td>
                <td className="form-control">
                  <textarea
                    readOnly
                    value={transaction.input}
                    className="p-0 w-full textarea-primary bg-inherit h-[150px]"
                  />
                </td>
              </tr>
              <tr>
                <td>
                  <strong>Logs:</strong>
                </td>
                <td>
                  <ul>
                    {receipt?.logs?.map((log, i) => (
                      <li key={i}>
                        <strong>Log {i} topics:</strong> {JSON.stringify(log.topics, replacer, 2)}
                      </li>
                    ))}
                  </ul>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      ) : (
        <p className="text-2xl text-base-content">Loading...</p>
      )}
    </div>
  );
};

export default TransactionComp;
