const modeCards = [
  {
    id: "local",
    name: "Local",
    kicker: "Fast",
    title: "Live browsing through Amon",
    path: "You → Amon → Site",
    body: "Open the real site in-app while the request runs through Amon’s privacy route.",
    bestFor: "Normal browsing",
    tone: "lime"
  },
  {
    id: "clean",
    name: "Clean View",
    kicker: "Cleaner",
    title: "Information without the site visit",
    path: "You → Amon → Clean page",
    body: "Amon fetches the page, removes clutter, and presents the information directly.",
    bestFor: "Reading and research",
    tone: "lime"
  },
  {
    id: "protected",
    name: "Protected Session",
    kicker: "Most mediated",
    title: "Fully mediated interaction",
    path: "You → Amon → Remote session → Site",
    body: "Amon runs the session remotely so the destination site does not interact with your device.",
    bestFor: "Dynamic or sensitive tasks",
    tone: "red"
  }
];

function ModeScene({ id }) {
  if (id === "clean") {
    return (
      <svg className="mode-scene" viewBox="0 0 320 170" role="img" aria-label="Clean View request path">
        <rect x="8" y="48" width="74" height="72" rx="18" fill="rgba(255,255,255,0.035)" stroke="rgba(255,255,255,0.12)" />
        <text x="45" y="88" textAnchor="middle" className="diagram-svg-mini">You</text>

        <path d="M86 84 H132" stroke="rgba(255,255,255,0.28)" strokeWidth="2" />

        <rect x="136" y="36" width="84" height="96" rx="22" fill="rgba(198,255,97,0.08)" stroke="rgba(198,255,97,0.36)" />
        <text x="178" y="78" textAnchor="middle" className="diagram-svg-mini">Amon</text>
        <text x="178" y="100" textAnchor="middle" className="diagram-svg-micro">fetches</text>

        <path d="M222 84 H264" stroke="rgba(198,255,97,0.5)" strokeWidth="2" />

        <rect x="242" y="38" width="66" height="72" rx="14" fill="rgba(255,255,255,0.02)" stroke="rgba(255,255,255,0.08)" opacity="0.55" />
        <rect x="252" y="58" width="88" height="96" rx="18" fill="rgba(198,255,97,0.1)" stroke="rgba(198,255,97,0.36)" />
        <rect x="270" y="82" width="50" height="7" rx="3.5" fill="rgba(244,239,232,0.7)" />
        <rect x="270" y="102" width="62" height="6" rx="3" fill="rgba(244,239,232,0.28)" />
        <rect x="270" y="118" width="44" height="6" rx="3" fill="rgba(244,239,232,0.2)" />
      </svg>
    );
  }

  if (id === "protected") {
    return (
      <svg className="mode-scene" viewBox="0 0 320 170" role="img" aria-label="Protected Session request path">
        <rect x="2" y="48" width="62" height="72" rx="18" fill="rgba(255,255,255,0.035)" stroke="rgba(255,255,255,0.12)" />
        <text x="33" y="88" textAnchor="middle" className="diagram-svg-mini">You</text>

        <path d="M66 84 H104" stroke="rgba(255,255,255,0.28)" strokeWidth="2" />

        <rect x="108" y="42" width="70" height="84" rx="20" fill="rgba(255,94,79,0.08)" stroke="rgba(255,94,79,0.34)" />
        <text x="143" y="80" textAnchor="middle" className="diagram-svg-mini">Amon</text>

        <path d="M180 84 H212" stroke="rgba(255,94,79,0.52)" strokeWidth="2" />

        <rect x="216" y="34" width="78" height="100" rx="18" fill="rgba(255,94,79,0.08)" stroke="rgba(255,94,79,0.34)" />
        <text x="255" y="72" textAnchor="middle" className="diagram-svg-mini">Remote</text>
        <rect x="238" y="92" width="34" height="20" rx="5" fill="rgba(255,255,255,0.06)" />

        <path d="M294 84 H314" stroke="rgba(255,94,79,0.42)" strokeWidth="2" />
      </svg>
    );
  }

  return (
    <svg className="mode-scene" viewBox="0 0 320 170" role="img" aria-label="Local request path">
      <rect x="10" y="48" width="74" height="72" rx="18" fill="rgba(255,255,255,0.035)" stroke="rgba(255,255,255,0.12)" />
      <text x="47" y="88" textAnchor="middle" className="diagram-svg-mini">You</text>

      <path d="M88 84 H132" stroke="rgba(255,255,255,0.28)" strokeWidth="2" />

      <rect x="136" y="42" width="84" height="84" rx="22" fill="rgba(198,255,97,0.07)" stroke="rgba(198,255,97,0.28)" />
      <text x="178" y="80" textAnchor="middle" className="diagram-svg-mini">Amon</text>
      <text x="178" y="100" textAnchor="middle" className="diagram-svg-micro">route</text>

      <path d="M224 84 H262" stroke="rgba(198,255,97,0.42)" strokeWidth="2" />

      <rect x="266" y="46" width="88" height="78" rx="16" fill="rgba(255,255,255,0.035)" stroke="rgba(255,255,255,0.12)" />
      <rect x="282" y="68" width="52" height="8" rx="4" fill="rgba(244,239,232,0.5)" />
      <rect x="282" y="90" width="38" height="6" rx="3" fill="rgba(244,239,232,0.2)" />
    </svg>
  );
}

export function ModeComparisonDiagram() {
  return (
    <div className="mode-comparison-diagram">
      {modeCards.map((mode) => (
        <article className={`mode-card mode-card-${mode.id}`} key={mode.id}>
          <div className="mode-card-top">
            <span>{mode.kicker}</span>
            <strong>{mode.name}</strong>
          </div>

          <ModeScene id={mode.id} />

          <div className="mode-card-copy">
            <h3>{mode.title}</h3>
            <p>{mode.body}</p>
          </div>

          <div className="mode-card-path">{mode.path}</div>

          <div className="mode-card-best">
            <span>Best for</span>
            <strong>{mode.bestFor}</strong>
          </div>
        </article>
      ))}
    </div>
  );
}