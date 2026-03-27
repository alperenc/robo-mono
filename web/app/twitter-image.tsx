import { ImageResponse } from "next/og";
import { SocialPreview } from "./social-preview";

export const runtime = "edge";
export const alt = "Roboshare social preview";
export const size = {
  width: 1200,
  height: 630,
};
export const contentType = "image/png";

export default function TwitterImage() {
  return new ImageResponse(
    (
      <SocialPreview
        eyebrow="Roboshare"
        title="Vehicle Revenue, Traded Onchain"
        subtitle="Browse markets, launch primary pools, and settle earnings from a single protocol interface."
      />
    ),
    size,
  );
}
