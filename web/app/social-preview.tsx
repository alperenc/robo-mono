const brandGradient = "linear-gradient(135deg, #050505 0%, #111111 38%, #1f1f1f 100%)";

export const SocialPreview = ({ eyebrow, title, subtitle }: { eyebrow: string; title: string; subtitle: string }) => {
  return (
    <div
      style={{
        width: "100%",
        height: "100%",
        display: "flex",
        position: "relative",
        overflow: "hidden",
        background: brandGradient,
        color: "#f8f8f8",
        fontFamily: 'ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
      }}
    >
      <div
        style={{
          position: "absolute",
          inset: 0,
          display: "flex",
          background:
            "radial-gradient(circle at top right, rgba(255,255,255,0.12), transparent 30%), radial-gradient(circle at bottom left, rgba(255,255,255,0.08), transparent 32%)",
        }}
      />
      <div
        style={{
          position: "absolute",
          top: -160,
          right: -120,
          width: 460,
          height: 460,
          borderRadius: 9999,
          background: "radial-gradient(circle, rgba(255,255,255,0.18), rgba(255,255,255,0.02) 58%, transparent 72%)",
        }}
      />
      <div
        style={{
          position: "absolute",
          bottom: -210,
          left: -120,
          width: 420,
          height: 420,
          borderRadius: 9999,
          background: "radial-gradient(circle, rgba(247,210,82,0.22), rgba(247,210,82,0.04) 58%, transparent 75%)",
        }}
      />
      <div
        style={{
          position: "relative",
          zIndex: 1,
          display: "flex",
          flexDirection: "column",
          justifyContent: "space-between",
          width: "100%",
          padding: "72px 76px 58px",
        }}
      >
        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: 18,
          }}
        >
          <div
            style={{
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              width: 84,
              height: 84,
              borderRadius: 24,
              background: "#ffffff",
              color: "#0b0b0b",
              fontSize: 42,
              fontWeight: 800,
              letterSpacing: "-0.06em",
            }}
          >
            R
          </div>
          <div
            style={{
              display: "flex",
              flexDirection: "column",
              gap: 6,
            }}
          >
            <div
              style={{
                display: "flex",
                fontSize: 22,
                letterSpacing: "0.24em",
                textTransform: "uppercase",
                color: "#f7d252",
                fontWeight: 700,
              }}
            >
              {eyebrow}
            </div>
            <div
              style={{
                display: "flex",
                fontSize: 32,
                fontWeight: 650,
                letterSpacing: "-0.04em",
              }}
            >
              Roboshare
            </div>
          </div>
        </div>

        <div
          style={{
            display: "flex",
            flexDirection: "column",
            gap: 20,
            maxWidth: 930,
          }}
        >
          <div
            style={{
              display: "flex",
              fontSize: 82,
              lineHeight: 1.02,
              fontWeight: 800,
              letterSpacing: "-0.07em",
            }}
          >
            {title}
          </div>
          <div
            style={{
              display: "flex",
              fontSize: 30,
              lineHeight: 1.35,
              color: "rgba(248,248,248,0.78)",
              maxWidth: 860,
            }}
          >
            {subtitle}
          </div>
        </div>

        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: 16,
            fontSize: 22,
            color: "rgba(248,248,248,0.72)",
          }}
        >
          <div
            style={{
              display: "flex",
              width: 14,
              height: 14,
              borderRadius: 9999,
              background: "#f7d252",
            }}
          />
          Vehicle-backed revenue markets onchain
        </div>
      </div>
    </div>
  );
};
