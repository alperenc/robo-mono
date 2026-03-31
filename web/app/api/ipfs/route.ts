import { NextRequest, NextResponse } from "next/server";

const PINATA_UPLOAD_URL = "https://uploads.pinata.cloud/v3/files";

export const runtime = "nodejs";

export async function POST(req: NextRequest) {
  try {
    if (!process.env.PINATA_JWT) {
      return NextResponse.json({ error: "Pinata is not configured" }, { status: 500 });
    }

    const formData = await req.formData();
    const file = formData.get("file");

    if (!(file instanceof File)) {
      return NextResponse.json({ error: "Missing file upload" }, { status: 400 });
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
  } catch (error) {
    console.error("Pinata Upload Error:", error);
    return NextResponse.json({ error: "Failed to upload to IPFS" }, { status: 500 });
  }
}
