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
      throw new Error(`IPFS upload failed: ${response.statusText}`);
    }

    const result = await response.json();
    return `ipfs://${result.Hash}`;
  } catch (error) {
    console.error("Error uploading to IPFS:", error);
    throw error;
  }
};
