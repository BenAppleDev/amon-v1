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
    <div className="security-visual security-visual-access" aria-hidden="true">
      <div className="security-device-card">
        <span />
        <span />
      </div>
      <div className="security-token-card">
        <strong>ID</strong>
      </div>
    </div>
  );
}

function TransportVisual() {
  return (
    <div className="security-visual security-visual-transport" aria-hidden="true">
      <div className="security-tunnel-line" />
      <div className="security-tunnel-pill">TLS</div>
      <div className="security-tunnel-pill">ATS</div>
    </div>
  );
}

function HandlingVisual() {
  return (
    <div className="security-visual security-visual-handling" aria-hidden="true">
      <div className="security-amon-node">A</div>
      <div className="security-handling-chips">
        <span>Live</span>
        <span>Text</span>
        <span>Remote</span>
      </div>
    </div>
  );
}

function WorkspaceVisual() {
  return (
    <div className="security-visual security-visual-workspace" aria-hidden="true">
      <div className="security-workspace-stack">
        <span />
        <span />
        <span />
      </div>
      <div className="security-unlock-dot" />
    </div>
  );
}

function OperationsVisual() {
  return (
    <div className="security-visual security-visual-operations" aria-hidden="true">
      <div className="security-ops-panel">
        <span />
        <span />
        <span />
      </div>
      <div className="security-ops-metadata">meta</div>
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
        <span>Access, transport, request handling, saved work, and operations each have separate controls.</span>
      </div>
    </div>
  );
}