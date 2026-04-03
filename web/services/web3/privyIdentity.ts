import type { User } from "@privy-io/react-auth";
import type { Address } from "viem";

type GetPrivyIdentityLabelParams = {
  address?: Address;
  connectorName?: string;
  user?: User | null;
};

export const getPrivyIdentityLabel = ({ address, connectorName, user }: GetPrivyIdentityLabelParams) => {
  if (!user) {
    return connectorName || (address ? `${address.slice(0, 6)}...${address.slice(-4)}` : undefined);
  }

  if (user.email?.address) return user.email.address;
  if (user.google?.email) return user.google.email;
  if (user.apple?.email) return user.apple.email;
  if (user.discord?.username) return `@${user.discord.username}`;
  if (user.discord?.email) return user.discord.email;
  if (user.github?.username) return `@${user.github.username}`;
  if (user.github?.email) return user.github.email;
  if (user.twitter?.username) return `@${user.twitter.username}`;
  if (user.twitter?.name) return user.twitter.name;
  if (user.telegram?.username) return `@${user.telegram.username}`;
  if (user.farcaster?.username) return `@${user.farcaster.username}`;
  if (user.linkedin?.email) return user.linkedin.email;
  if (user.linkedin?.vanityName) return user.linkedin.vanityName;
  if (user.phone?.number) return user.phone.number;

  return connectorName || (address ? `${address.slice(0, 6)}...${address.slice(-4)}` : undefined);
};
