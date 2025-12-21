export const uploadToIpfs = async (data: File | object): Promise<string> => {
  try {
    const formData = new FormData();

    if (data instanceof File) {
      formData.append("file", data);
    } else {
      const blob = new Blob([JSON.stringify(data)], { type: "application/json" });
      formData.append("file", blob, "metadata.json");
    }

    // Using the local IPFS node exposed by the subgraph docker compose
    const response = await fetch("http://localhost:5001/api/v0/add", {
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
