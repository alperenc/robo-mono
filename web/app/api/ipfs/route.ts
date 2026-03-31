import { NextRequest, NextResponse } from "next/server";

const LOCAL_IPFS_UPLOAD_URL = "http://127.0.0.1:5001/api/v0/add";
const PINATA_UPLOAD_URL = "https://uploads.pinata.cloud/v3/files";

export const runtime = "nodejs";

const uploadToLocalIpfs = async (file: File) => {
  const localFormData = new FormData();
  localFormData.append("file", file, file.name || "upload");

  const response = await fetch(process.env.IPFS_API_URL || LOCAL_IPFS_UPLOAD_URL, {
    method: "POST",
    body: localFormData,
  });

  if (!response.ok) {
    const errorText = await response.text();
    return NextResponse.json(
      { error: `Local IPFS upload failed: ${response.status} ${response.statusText}`, details: errorText },
      { status: response.status },
    );
  }

  const data = await response.json();
  return NextResponse.json(data);
};

const uploadToPinata = async (file: File) => {
  if (!process.env.PINATA_JWT) {
    return NextResponse.json({ error: "Pinata is not configured" }, { status: 500 });
  }

  const pinataFormData = new FormData();
  pinataFormData.append("network", "public");
  pinataFormData.append("file", file, file.name || "upload");

  if (process.env.PINATA_GROUP_ID) {
    pinataFormData.append("group_id", process.env.PINATA_GROUP_ID);
  }

  const response = await fetch(PINATA_UPLOAD_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${process.env.PINATA_JWT}`,
    },
    body: pinataFormData,
  });

  if (!response.ok) {
    const errorText = await response.text();
    return NextResponse.json(
      { error: `Pinata upload failed: ${response.status} ${response.statusText}`, details: errorText },
      { status: response.status },
    );
  }

  const data = await response.json();
  return NextResponse.json(data);
};

export async function POST(req: NextRequest) {
  try {
    const formData = await req.formData();
    const file = formData.get("file");

    if (!(file instanceof File)) {
      return NextResponse.json({ error: "Missing file upload" }, { status: 400 });
    }

    const shouldUseLocalIpfs =
      Boolean(process.env.IPFS_API_URL) || (!process.env.PINATA_JWT && process.env.NODE_ENV !== "production");

    if (shouldUseLocalIpfs) {
      return uploadToLocalIpfs(file);
    }

    return uploadToPinata(file);
  } catch (error) {
    console.error("IPFS Upload Error:", error);
    return NextResponse.json({ error: "Failed to upload to IPFS" }, { status: 500 });
  }
}
