import { useState } from "react";

const modes = [
  {
    id: "local",
    label: "Local",
    title: "Live site",
    subtitle: "Through Amon privacy route",
    accent: "var(--lime)",
    mutedAccent: "rgba(198, 255, 97, 0.16)"
  },
  {
    id: "clean",
    label: "Clean",
    title: "Clean View",
    subtitle: "Fetched and presented",
    accent: "var(--lime)",
    mutedAccent: "rgba(198, 255, 97, 0.16)"
  },
  {
    id: "protected",
    label: "Protected",
    title: "Remote session",
    subtitle: "Mediated and temporary",
    accent: "var(--red)",
    mutedAccent: "rgba(255, 94, 79, 0.16)"
  }
];

function OutcomeSurface({ activeMode }) {
  if (activeMode === "clean") {
    return (
      <g>
        <rect x="820" y="132" width="218" height="154" rx="22" fill="rgba(255,255,255,0.025)" stroke="rgba(255,255,255,0.08)" />
        <rect x="836" y="148" width="184" height="126" rx="18" fill="rgba(198,255,97,0.08)" stroke="rgba(198,255,97,0.34)" />
        <text x="858" y="176" className="diagram-svg-kicker">Clean View</text>
        <rect x="858" y="196" width="112" height="8" rx="4" fill="rgba(244,239,232,0.72)" />
        <rect x="858" y="216" width="146" height="7" rx="3.5" fill="rgba(244,239,232,0.26)" />
        <rect x="858" y="232" width="132" height="7" rx="3.5" fill="rgba(244,239,232,0.2)" />
        <rect x="858" y="248" width="92" height="7" rx="3.5" fill="rgba(244,239,232,0.16)" />
      </g>
    );
  }

  if (activeMode === "protected") {
    return (
      <g>
        <rect x="798" y="120" width="112" height="112" rx="22" fill="rgba(255,94,79,0.08)" stroke="rgba(255,94,79,0.34)" />
        <text x="820" y="153" className="diagram-svg-kicker">Remote</text>
        <rect x="822" y="170" width="64" height="38" rx="8" fill="rgba(255,255,255,0.06)" stroke="rgba(255,255,255,0.12)" />
        <circle cx="836" cy="184" r="4" fill="var(--red)" />

        <rect x="940" y="132" width="128" height="112" rx="22" fill="rgba(255,255,255,0.028)" stroke="rgba(255,255,255,0.1)" />
        <text x="968" y="168" className="diagram-svg-kicker">Site</text>
        <rect x="968" y="190" width="64" height="8" rx="4" fill="rgba(244,239,232,0.36)" />
        <rect x="968" y="208" width="44" height="7" rx="3.5" fill="rgba(244,239,232,0.18)" />
      </g>
    );
  }

  return (
    <g>
      <rect x="820" y="132" width="218" height="154" rx="22" fill="rgba(255,255,255,0.028)" stroke="rgba(255,255,255,0.1)" />
      <rect x="842" y="154" width="174" height="104" rx="16" fill="rgba(255,255,255,0.045)" stroke="rgba(255,255,255,0.1)" />
      <rect x="858" y="170" width="142" height="12" rx="6" fill="rgba(244,239,232,0.44)" />
      <rect x="858" y="200" width="108" height="8" rx="4" fill="rgba(244,239,232,0.22)" />
      <rect x="858" y="218" width="126" height="8" rx="4" fill="rgba(244,239,232,0.16)" />
      <text x="858" y="246" className="diagram-svg-kicker">Live website</text>
    </g>
  );
}

export function RequestFlowDiagram({ compact = false }) {
  const [activeMode, setActiveMode] = useState("clean");
  const active = modes.find((mode) => mode.id === activeMode) ?? modes[1];

  const handleKeyDown = (event, modeId) => {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      setActiveMode(modeId);
    }
  };

  return (
    <div className={`request-flow-diagram${compact ? " is-compact" : ""}`} data-active-mode={activeMode}>
      <svg
        className="request-flow-svg"
        viewBox="0 0 1120 540"
        role="img"
        aria-label="Amon routes every request through its privacy layer, then handles it locally, cleanly, or through a protected session."
      >
        <defs>
          <linearGradient id="amonFlowPanel" x1="0" x2="1">
            <stop offset="0%" stopColor="rgba(198,255,97,0.08)" />
            <stop offset="100%" stopColor="rgba(255,94,79,0.08)" />
          </linearGradient>

          <filter id="softGlow" x="-20%" y="-20%" width="140%" height="140%">
            <feGaussianBlur stdDeviation="8" result="blur" />
            <feColorMatrix
              in="blur"
              type="matrix"
              values="0.75 0 0 0 0.1  0 0.9 0 0 0.2  0 0 0.25 0 0.05  0 0 0 0.42 0"
            />
            <feBlend in="SourceGraphic" mode="screen" />
          </filter>
        </defs>

        <rect x="1" y="1" width="1118" height="538" rx="34" fill="rgba(255,255,255,0.025)" stroke="rgba(255,255,255,0.08)" />

        <g className="request-flow-grid">
          <path d="M72 404 H1048" stroke="rgba(255,255,255,0.035)" strokeWidth="1" />
          <path d="M72 92 H1048" stroke="rgba(255,255,255,0.035)" strokeWidth="1" />
          <path d="M560 52 V494" stroke="rgba(255,255,255,0.025)" strokeWidth="1" />
        </g>

        <g className="request-flow-device">
          <rect x="64" y="130" width="230" height="184" rx="28" fill="var(--panel)" stroke="var(--line)" />
          <text x="92" y="166" className="diagram-svg-kicker">You</text>
          <rect x="92" y="190" width="166" height="34" rx="17" fill="rgba(255,255,255,0.055)" stroke="rgba(255,255,255,0.1)" />
          <text x="110" y="212" className="diagram-svg-small">search anything</text>
          <rect x="92" y="246" width="148" height="8" rx="4" fill="rgba(244,239,232,0.34)" />
          <rect x="92" y="266" width="112" height="7" rx="3.5" fill="rgba(244,239,232,0.2)" />
        </g>

        <path d="M294 222 C342 222 354 222 398 222" stroke="rgba(255,255,255,0.28)" strokeWidth="2" fill="none" />
        <path d="M294 222 C342 222 354 222 398 222" className="request-flow-active-line" stroke={active.accent} strokeWidth="2" fill="none" />

        <g className="request-flow-amon">
          <rect x="398" y="90" width="322" height="258" rx="32" fill="rgba(255,255,255,0.035)" stroke={active.accent} strokeWidth="1.5" filter="url(#softGlow)" />
          <text x="430" y="132" className="diagram-svg-kicker">Amon</text>
          <text x="430" y="166" className="diagram-svg-title">Privacy layer</text>
          <text x="430" y="194" className="diagram-svg-small">Every request enters here.</text>

          {modes.map((mode, index) => {
            const x = 430 + index * 92;
            const isActive = activeMode === mode.id;

            return (
              <g
                key={mode.id}
                className="request-flow-chip"
                role="button"
                tabIndex="0"
                aria-label={`Select ${mode.label}`}
                onClick={() => setActiveMode(mode.id)}
                onKeyDown={(event) => handleKeyDown(event, mode.id)}
              >
                <rect
                  x={x}
                  y="228"
                  width="78"
                  height="38"
                  rx="19"
                  fill={isActive ? mode.mutedAccent : "rgba(255,255,255,0.035)"}
                  stroke={isActive ? mode.accent : "rgba(255,255,255,0.12)"}
                />
                <text x={x + 39} y="252" textAnchor="middle" className="diagram-svg-chip">
                  {mode.label}
                </text>
              </g>
            );
          })}

          <rect x="430" y="294" width="256" height="18" rx="9" fill="rgba(255,255,255,0.04)" />
          <rect x="430" y="294" width={activeMode === "local" ? "74" : activeMode === "clean" ? "158" : "256"} height="18" rx="9" fill={active.accent} opacity="0.85" />
        </g>

        <path d="M720 222 C760 222 772 222 808 222" stroke="rgba(255,255,255,0.28)" strokeWidth="2" fill="none" />
        <path d="M720 222 C760 222 772 222 808 222" className="request-flow-active-line" stroke={active.accent} strokeWidth="2.2" fill="none" />

        <g className="request-flow-outcome">
          <OutcomeSurface activeMode={activeMode} />
          <text x="820" y="324" className="diagram-svg-kicker">{active.title}</text>
          <text x="820" y="350" className="diagram-svg-small">{active.subtitle}</text>
        </g>

        <path d="M560 348 C560 378 560 396 560 424" stroke="rgba(255,255,255,0.18)" strokeWidth="2" fill="none" strokeDasharray="4 8" />
        <path d="M560 348 C560 378 560 396 560 424" stroke="var(--lime)" strokeWidth="2" fill="none" opacity="0.62" strokeDasharray="1 12" />

        <g className="request-flow-workspace">
          <rect x="424" y="424" width="292" height="96" rx="26" fill="rgba(255,255,255,0.035)" stroke="rgba(255,255,255,0.1)" />
          <text x="454" y="462" className="diagram-svg-kicker">Workspace</text>
          <text x="454" y="488" className="diagram-svg-small">Saved locally. Company-unreadable.</text>
          <rect x="626" y="448" width="28" height="38" rx="6" fill="rgba(198,255,97,0.12)" stroke="rgba(198,255,97,0.28)" />
          <rect x="662" y="448" width="28" height="38" rx="6" fill="rgba(255,255,255,0.04)" stroke="rgba(255,255,255,0.12)" />
        </g>
      </svg>

      <div className="request-flow-caption">
        <span>{active.label}</span>
        <p>{active.subtitle}</p>
      </div>
    </div>
  );
}