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
          d="M92 122C164 122 204 146 238 186C278 232 316 260 400 260H512"
          fill="none"
          stroke="rgba(198,255,97,0.72)"
          strokeLinecap="round"
          strokeWidth="2.5"
        />
        <path
          d="M240 186C278 232 286 330 364 378C410 406 456 412 530 412"
          fill="none"
          stroke="rgba(255,94,79,0.6)"
          strokeLinecap="round"
          strokeWidth="2.5"
        />
        <circle cx="92" cy="122" r="6" fill="rgba(198,255,97,0.92)" />
        <circle cx="240" cy="186" r="6" fill="rgba(255,255,255,0.82)" />
        <circle cx="400" cy="260" r="6" fill="rgba(255,255,255,0.82)" />
        <circle cx="530" cy="412" r="6" fill="rgba(255,94,79,0.92)" />
      </svg>

      <div className="hero-field-label hero-field-label-search">search</div>
      <div className="hero-field-label hero-field-label-compare">compare</div>
      <div className="hero-field-label hero-field-label-return">revisit</div>
      <div className="hero-field-label hero-field-label-decide">decide</div>

      <div className="hero-field-caption">Questions become decisions.</div>
    </div>
  );
}
