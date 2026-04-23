const layers = [
  {
    id: "access",
    eyebrow: "Access",
    title: "Secure account access",
    tags: ["Sign in with Apple", "Session separation"]
  },
  {
    id: "transport",
    eyebrow: "Transport",
    title: "Encrypted path",
    tags: ["TLS 1.3", "ATS"]
  },
  {
    id: "handling",
    eyebrow: "Handling",
    title: "Scoped request paths",
    tags: ["Live", "Text", "Remote"]
  },
  {
    id: "workspace",
    eyebrow: "Workspace",
    title: "Local ownership",
    tags: ["Keychain", "Face ID / Passcode"]
  },
  {
    id: "operations",
    eyebrow: "Operations",
    title: "Metadata-only ops",
    tags: ["Least privilege", "No content tools"]
  }
];

function AccessVisual() {
  return (
    <div className="security-visual" aria-hidden="true">
      <svg className="security-visual-svg" viewBox="0 0 220 150">
        <rect className="security-svg-soft" x="42" y="26" width="76" height="104" rx="24" />
        <path className="security-svg-muted-line" d="M62 62H96" />
        <path className="security-svg-muted-line" d="M62 76H100" />
        <path className="security-svg-muted-line" d="M62 90H86" />
        <circle className="security-svg-lime-soft" cx="156" cy="75" r="32" />
        <path className="security-svg-lime-stroke security-svg-round" d="M143 76L153 86L174 62" />
      </svg>
    </div>
  );
}

function TransportVisual() {
  return (
    <div className="security-visual" aria-hidden="true">
      <svg className="security-visual-svg" viewBox="0 0 220 150">
        <circle className="security-svg-lime-soft" cx="38" cy="75" r="14" />
        <circle className="security-svg-lime-soft" cx="182" cy="75" r="14" />

        <path className="security-svg-lime-stroke security-svg-round" d="M53 75H92" />
        <path className="security-svg-lime-stroke security-svg-round" d="M148 75H167" />

        <path
          className="security-svg-muted-stroke security-svg-round"
          d="M102 72V61C102 49 110 42 120 42C130 42 138 49 138 61V72"
        />
        <rect className="security-svg-soft" x="94" y="72" width="52" height="42" rx="12" />
        <circle className="security-svg-ink-fill" cx="120" cy="91" r="5" />
        <path className="security-svg-muted-stroke security-svg-round" d="M120 96V102" />
      </svg>
    </div>
  );
}

function HandlingVisual() {
  return (
    <div className="security-visual" aria-hidden="true">
      <svg className="security-visual-svg" viewBox="0 0 220 150">
        <rect className="security-svg-lime-soft" x="86" y="14" width="48" height="48" rx="16" />
        <text className="security-svg-amon" x="110" y="48" textAnchor="middle">A</text>

        <path className="security-svg-muted-stroke security-svg-square" d="M110 62V82" />
        <path className="security-svg-muted-stroke security-svg-square" d="M54 82H166" />
        <path className="security-svg-muted-stroke security-svg-square" d="M54 82V96" />
        <path className="security-svg-muted-stroke security-svg-square" d="M110 82V96" />
        <path className="security-svg-muted-stroke security-svg-square" d="M166 82V96" />

        <rect className="security-svg-soft" x="34" y="96" width="40" height="34" rx="12" />
        <rect className="security-svg-soft" x="90" y="96" width="40" height="34" rx="12" />
        <rect className="security-svg-red-soft" x="146" y="96" width="40" height="34" rx="12" />

        <path className="security-svg-muted-line" d="M45 109H63" />
        <path className="security-svg-muted-line" d="M45 119H58" />

        <path className="security-svg-muted-line" d="M101 109H119" />
        <path className="security-svg-muted-line" d="M101 119H114" />

        <path className="security-svg-muted-line" d="M157 109H175" />
        <path className="security-svg-muted-line" d="M157 119H170" />
      </svg>
    </div>
  );
}

function WorkspaceVisual() {
  return (
    <div className="security-visual" aria-hidden="true">
      <svg className="security-visual-svg" viewBox="0 0 220 150">
        <rect className="security-svg-soft" x="42" y="38" width="136" height="86" rx="26" />

        <path
          className="security-svg-lime-soft"
          d="M70 64C70 57 75 52 82 52H98C104 52 108 56 112 61H140C148 61 154 67 154 75V104C154 112 148 118 140 118H82C75 118 70 113 70 106V64Z"
        />

        <path className="security-svg-muted-line" d="M88 82H132" />
        <path className="security-svg-muted-line" d="M88 96H120" />

        <circle className="security-svg-lime-soft" cx="160" cy="106" r="20" />
        <path
          className="security-svg-muted-stroke security-svg-round"
          d="M153 104V99C153 93 156 89 160 89C164 89 167 93 167 99V104"
        />
        <rect className="security-svg-ink-fill" x="151" y="103" width="18" height="15" rx="4" />
      </svg>
    </div>
  );
}

function OperationsVisual() {
  return (
    <div className="security-visual" aria-hidden="true">
      <svg className="security-visual-svg" viewBox="0 0 220 150">
        <rect className="security-svg-soft" x="58" y="30" width="104" height="72" rx="22" />
        <path className="security-svg-muted-line" d="M78 58H142" />
        <path className="security-svg-muted-line" d="M78 74H132" />
        <path className="security-svg-muted-line" d="M78 90H118" />

        <path className="security-svg-red-stroke security-svg-round" d="M80 120C94 105 126 105 140 120C126 135 94 135 80 120Z" />
        <circle className="security-svg-red-fill" cx="110" cy="120" r="5" />
        <path className="security-svg-red-stroke security-svg-round" d="M78 137L142 103" />
      </svg>
    </div>
  );
}

function LayerVisual({ id }) {
  if (id === "access") return <AccessVisual />;
  if (id === "transport") return <TransportVisual />;
  if (id === "handling") return <HandlingVisual />;
  if (id === "workspace") return <WorkspaceVisual />;
  return <OperationsVisual />;
}

export function SecurityLayersGraphic() {
  return (
    <div className="security-layers-graphic" aria-label="Five security layers around Amon requests">
      <div className="security-layers-header">
        <span className="diagram-kicker">Security model</span>
        <strong>Five layers around one request.</strong>
      </div>

      <div className="security-layer-strip">
        {layers.map((layer) => (
          <article className={`security-layer-card security-layer-card-${layer.id}`} key={layer.id}>
            <LayerVisual id={layer.id} />

            <div className="security-layer-copy">
              <span>{layer.eyebrow}</span>
              <strong>{layer.title}</strong>
            </div>

            <div className="security-layer-tags">
              {layer.tags.map((tag) => (
                <span key={tag}>{tag}</span>
              ))}
            </div>
          </article>
        ))}
      </div>

      <div className="security-layers-footer">
        <strong>No layer is implicitly trusted with the whole picture.</strong>
        <span>
          Access, transport, request handling, saved work, and operations each have separate controls.
        </span>
      </div>
    </div>
  );
}