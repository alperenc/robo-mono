import { ImageResponse } from "next/og";
import { SocialPreview } from "./social-preview";

export const runtime = "edge";
export const alt = "Roboshare social preview";
export const size = {
  width: 1200,
  height: 630,
};
export const contentType = "image/png";

export default function OpenGraphImage() {
  return new ImageResponse(
    (
      <SocialPreview
        eyebrow="Protocol App"
        title="Trade Tokenized Revenue Streams"
        subtitle="Roboshare turns vehicle-linked earnings into onchain markets for primary issuance, trading, and payout distribution."
      />
    ),
    size,
  );
}
