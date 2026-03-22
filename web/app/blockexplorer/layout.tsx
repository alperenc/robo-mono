import { LocalExplorerGuard } from "./_components/LocalExplorerGuard";
import { getMetadata } from "~~/utils/scaffold-eth/getMetadata";

export const metadata = getMetadata({
  title: "Block Explorer",
  description: "Roboshare block explorer and onchain inspection view",
});

const BlockExplorerLayout = ({ children }: { children: React.ReactNode }) => {
  return <LocalExplorerGuard>{children}</LocalExplorerGuard>;
};

export default BlockExplorerLayout;
