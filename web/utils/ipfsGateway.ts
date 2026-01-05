/**
 * IPFS Gateway utilities for resolving ipfs:// URLs to HTTP URLs
 */

// Use environment variable or default to local IPFS gateway for development
const IPFS_GATEWAY = process.env.NEXT_PUBLIC_IPFS_GATEWAY || "http://127.0.0.1:8080/ipfs/";

/**
 * Convert ipfs:// URL to HTTP gateway URL
 */
export const ipfsToHttp = (ipfsUrl: string | undefined | null): string | null => {
  if (!ipfsUrl) return null;

  // Handle ipfs:// protocol
  if (ipfsUrl.startsWith("ipfs://")) {
    const cid = ipfsUrl.replace("ipfs://", "");
    return `${IPFS_GATEWAY}${cid}`;
  }

  // Already an HTTP URL
  if (ipfsUrl.startsWith("http://") || ipfsUrl.startsWith("https://")) {
    return ipfsUrl;
  }

  return null;
};

/**
 * Metadata structure from IPFS JSON
 */
export interface IpfsMetadata {
  image?: string;
  name?: string;
  description?: string;
  properties?: Record<string, unknown>;
}

/**
 * Fetch and parse IPFS metadata JSON
 */
export const fetchIpfsMetadata = async (metadataUri: string | undefined | null): Promise<IpfsMetadata | null> => {
  const httpUrl = ipfsToHttp(metadataUri);
  if (!httpUrl) return null;

  try {
    // Add timeout to prevent hanging on unavailable IPFS gateway
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 5000);

    const response = await fetch(httpUrl, { signal: controller.signal });
    clearTimeout(timeoutId);

    if (!response.ok) return null;
    return await response.json();
  } catch (error) {
    // Silently fail for IPFS fetch errors (network, timeout, etc.)
    // This is expected when IPFS gateway is not running
    if (error instanceof Error && error.name !== "AbortError") {
      console.warn("IPFS metadata fetch failed (gateway may not be running):", httpUrl);
    }
    return null;
  }
};
