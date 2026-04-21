const rows = [
  {
    mode: "Search",
    tone: "neutral",
    cells: {
      amon: "Brokers request",
      destination: "Sees Amon",
      network: "Sees Amon traffic",
      device: "No save unless chosen"
    }
  },
  {
    mode: "Local",
    tone: "lime",
    cells: {
      amon: "Routes live page",
      destination: "Sees Amon-mediated path",
      network: "Sees Amon",
      device: "Renders live page"
    }
  },
  {
    mode: "Clean",
    tone: "lime",
    cells: {
      amon: "Fetches page",
      destination: "Sees Amon retrieval",
      network: "Sees Amon",
      device: "Receives clean content"
    }
  },
  {
    mode: "Protected",
    tone: "red",
    cells: {
      amon: "Runs remote session",
      destination: "Sees remote session",
      network: "Sees Amon",
      device: "Controls session"
    }
  },
  {
    mode: "Workspace",
    tone: "neutral",
    cells: {
      amon: "Cannot read saved files",
      destination: "Sees nothing",
      network: "Sees nothing",
      device: "Encrypted local work"
    }
  }
];

const columns = [
  { id: "amon", label: "Amon" },
  { id: "destination", label: "Destination" },
  { id: "network", label: "Local network" },
  { id: "device", label: "Device" }
];

export function VisibilityMatrixDiagram() {
  return (
    <div className="visibility-matrix-diagram" role="table" aria-label="Who sees what depends on the request path.">
      <div className="visibility-matrix-header" role="row">
        <div className="visibility-cell visibility-cell-mode" role="columnheader">
          Mode
        </div>
        {columns.map((column) => (
          <div className="visibility-cell" role="columnheader" key={column.id}>
            {column.label}
          </div>
        ))}
      </div>

      {rows.map((row) => (
        <div className={`visibility-matrix-row is-${row.tone}`} role="row" key={row.mode}>
          <div className="visibility-cell visibility-cell-mode" role="cell">
            <span className="visibility-dot" />
            <strong>{row.mode}</strong>
          </div>

          {columns.map((column) => (
            <div className="visibility-cell" role="cell" key={column.id}>
              {row.cells[column.id]}
            </div>
          ))}
        </div>
      ))}

      <p className="visibility-matrix-note">
        Signing into a third-party account can still reveal identity to that service.
      </p>
    </div>
  );
}