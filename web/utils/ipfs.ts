export const uploadToIpfs = async (data: File | object): Promise<string> => {
  try {
    const formData = new FormData();

    if (data instanceof File) {
      formData.append("file", data);
    } else {
      const blob = new Blob([JSON.stringify(data)], { type: "application/json" });
      formData.append("file", blob, "metadata.json");
    }

    // Use our internal API proxy to avoid CORS issues and protect infrastructure
    const response = await fetch("/api/ipfs", {
      method: "POST",
      body: formData,
    });

    if (!response.ok) {
      const errorBody = await response.json().catch(() => null);
      const message =
        typeof errorBody?.error === "string" ? errorBody.error : `IPFS upload failed: ${response.statusText}`;
      throw new Error(message);
    }

    const result = await response.json();
    const cid = result?.data?.cid ?? result?.Hash;
    if (!cid) {
      throw new Error("IPFS upload failed: missing CID in response");
    }
    return `ipfs://${cid}`;
  } catch (error) {
    console.error("Error uploading to IPFS:", error);
    throw error;
  }
};
