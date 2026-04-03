"use client";

type TestFundsNotificationProps = {
  message: string;
  recipientAddress?: string;
  blockExplorerLink?: string;
};

const shortenAddress = (address: string) => `${address.slice(0, 6)}...${address.slice(-4)}`;

export const TestFundsNotification = ({ message, recipientAddress, blockExplorerLink }: TestFundsNotificationProps) => {
  return (
    <div className="flex flex-col ml-1 cursor-default">
      <p className="my-0">{message}</p>
      {recipientAddress ? (
        <p className="my-0 text-xs opacity-80">
          Sent to <span className="font-mono">{shortenAddress(recipientAddress)}</span>
        </p>
      ) : null}
      {blockExplorerLink ? (
        <a href={blockExplorerLink} target="_blank" rel="noreferrer" className="block link text-md">
          view transaction
        </a>
      ) : null}
    </div>
  );
};
