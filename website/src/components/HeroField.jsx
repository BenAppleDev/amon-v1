export function HeroField() {
  return (
    <div className="hero-field" aria-hidden="true">
      <svg className="hero-field-svg" viewBox="0 0 620 560">
        <defs>
          <radialGradient id="heroSpotlight" cx="54%" cy="44%" r="48%">
            <stop offset="0%" stopColor="#ffffff" stopOpacity="0.12" />
            <stop offset="68%" stopColor="#ffffff" stopOpacity="0" />
          </radialGradient>
        </defs>
        <ellipse cx="336" cy="248" rx="220" ry="168" fill="url(#heroSpotlight)" />
        <path
          d="M96 124C166 124 198 146 236 186C278 230 322 258 404 258H520"
          className="hero-field-track"
          fill="none"
          stroke="rgba(255,255,255,0.08)"
          strokeLinecap="round"
          strokeWidth="4.5"
        />
        <path
          d="M96 124C166 124 198 146 236 186C278 230 322 258 404 258H520"
          className="hero-field-path hero-field-path-primary"
          fill="none"
          stroke="rgba(198,255,97,0.72)"
          strokeLinecap="round"
          strokeWidth="2.5"
          pathLength="1"
        />
        <path
          d="M236 186C278 230 288 328 364 378C412 406 458 412 530 412"
          className="hero-field-track"
          fill="none"
          stroke="rgba(255,255,255,0.08)"
          strokeLinecap="round"
          strokeWidth="4.5"
        />
        <path
          d="M236 186C278 230 288 328 364 378C412 406 458 412 530 412"
          className="hero-field-path hero-field-path-secondary"
          fill="none"
          stroke="rgba(255,94,79,0.6)"
          strokeLinecap="round"
          strokeWidth="2.5"
          pathLength="1"
        />
        <circle
          cx="96"
          cy="124"
          r="7"
          className="hero-field-node hero-field-node-search"
          fill="#060606"
          stroke="rgba(198,255,97,0.92)"
          strokeWidth="2.5"
        />
        <circle
          cx="236"
          cy="186"
          r="7"
          className="hero-field-node hero-field-node-compare"
          fill="#060606"
          stroke="rgba(255,255,255,0.8)"
          strokeWidth="2.5"
        />
        <circle
          cx="520"
          cy="258"
          r="7"
          className="hero-field-node hero-field-node-revisit"
          fill="#060606"
          stroke="rgba(255,255,255,0.8)"
          strokeWidth="2.5"
        />
        <circle
          cx="530"
          cy="412"
          r="7"
          className="hero-field-node hero-field-node-decide"
          fill="#060606"
          stroke="rgba(255,94,79,0.92)"
          strokeWidth="2.5"
        />
        <circle
          cx="530"
          cy="412"
          r="15"
          className="hero-field-node-aura hero-field-node-aura-final"
          fill="none"
          stroke="rgba(255,94,79,0.2)"
          strokeWidth="1.2"
        />
      </svg>

      <div className="hero-field-label hero-field-label-search">search</div>
      <div className="hero-field-label hero-field-label-compare">compare</div>
      <div className="hero-field-label hero-field-label-return">revisit</div>
      <div className="hero-field-label hero-field-label-decide">decide</div>

      <div className="hero-field-caption">Questions become decisions.</div>
    </div>
  );
}
