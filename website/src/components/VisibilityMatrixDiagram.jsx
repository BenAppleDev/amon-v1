const rows = [
  {
    mode: "Search",
    tone: "neutral",
    amon: "Brokers request",
    destination: "Sees Amon",
    network: "Sees Amon traffic",
    device: "No saved history unless you save"
  },
  {
    mode: "Local",
    tone: "lime",
    amon: "Routes live page",
    destination: "Sees Amon-mediated path",
    network: "Sees Amon",
    device: "Renders live page"
  },
  {
    mode: "Clean",
    tone: "lime",
    amon: "Fetches and extracts text",
    destination: "Sees Amon retrieval",
    network: "Sees Amon",
    device: "Receives readable text"
  },
  {
    mode: "Protected",
    tone: "red",
    amon: "Runs remote session",
    destination: "Sees Amon machine",
    network: "Sees Amon",
    device: "Controls session"
  },
  {
    mode: "Workspace",
    tone: "neutral",
    amon: "Cannot decrypt files",
    destination: "Sees nothing",
    network: "Sees nothing",
    device: "Encrypted local work"
  }
];

export function VisibilityMatrixDiagram() {
  return (
    <div className="visibility-map">
      <div className="visibility-map-header">
        <span>Mode</span>
        <span>Amon</span>
        <span>Destination</span>
        <span>Network</span>
        <span>Device</span>
      </div>

      {rows.map((row) => (
        <div className={`visibility-map-row is-${row.tone}`} key={row.mode}>
          <div className="visibility-map-mode">
            <i />
            <strong>{row.mode}</strong>
          </div>
          <div>{row.amon}</div>
          <div>{row.destination}</div>
          <div>{row.network}</div>
          <div>{row.device}</div>
        </div>
      ))}

      <div className="visibility-map-note">
        <strong>Identity-based services are different.</strong>
        <span> If you log into a third-party account, that service can know who you are.</span>
      </div>
    </div>
  );
}