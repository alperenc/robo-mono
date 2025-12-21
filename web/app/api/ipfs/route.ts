import { NextRequest, NextResponse } from "next/server";

export async function POST(req: NextRequest) {
  try {
    const formData = await req.formData();

    // In production, this URL would come from process.env.IPFS_API_URL
    const ipfsUrl = "http://127.0.0.1:5001/api/v0/add";

    const response = await fetch(ipfsUrl, {
      method: "POST",
      body: formData,
    });

    if (!response.ok) {
      return NextResponse.json({ error: `IPFS Node Error: ${response.statusText}` }, { status: response.status });
    }

    const data = await response.json();
    return NextResponse.json(data);
  } catch (error) {
    console.error("IPFS Proxy Error:", error);
    return NextResponse.json({ error: "Failed to upload to IPFS" }, { status: 500 });
  }
}
