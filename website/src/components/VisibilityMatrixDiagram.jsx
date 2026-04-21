import { useState } from "react";

const columns = [
  { id: "amon", label: "Amon" },
  { id: "destination", label: "Destination" },
  { id: "network", label: "Network" },
  { id: "device", label: "Device" }
];

const rows = [
  {
    mode: "Search",
    tone: "neutral",
    cells: {
      amon: "Brokers request",
      destination: "Sees Amon",
      network: "Sees Amon traffic",
      device: "No saved history unless you save"
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
      amon: "Fetches and extracts text",
      destination: "Sees Amon retrieval",
      network: "Sees Amon",
      device: "Receives readable text"
    }
  },
  {
    mode: "Protected",
    tone: "red",
    cells: {
      amon: "Runs remote session",
      destination: "Sees Amon machine",
      network: "Sees Amon",
      device: "Controls session"
    }
  },
  {
    mode: "Workspace",
    tone: "neutral",
    cells: {
      amon: "Cannot decrypt files",
      destination: "Sees nothing",
      network: "Sees nothing",
      device: "Encrypted local work"
    }
  }
];

export function VisibilityMatrixDiagram() {
  const [hovered, setHovered] = useState(null);

  const isColumnActive = (columnId) => hovered?.column === columnId;
  const isRowActive = (rowIndex) => hovered?.row === rowIndex;

  return (
    <div
      className="visibility-map"
      onMouseLeave={() => setHovered(null)}
      role="table"
      aria-label="Who sees what depends on the request path."
    >
      <div className="visibility-map-header" role="row">
        <div
          className={`visibility-map-cell visibility-map-heading visibility-map-mode-heading${isColumnActive("mode") ? " is-col-hover" : ""}`}
          role="columnheader"
          onMouseEnter={() => setHovered({ row: null, column: "mode" })}
        >
          Mode
        </div>

        {columns.map((column) => (
          <div
            key={column.id}
            className={`visibility-map-cell visibility-map-heading${isColumnActive(column.id) ? " is-col-hover" : ""}`}
            role="columnheader"
            onMouseEnter={() => setHovered({ row: null, column: column.id })}
          >
            {column.label}
          </div>
        ))}
      </div>

      {rows.map((row, rowIndex) => (
        <div
          className={`visibility-map-row is-${row.tone}${isRowActive(rowIndex) ? " is-row-hover" : ""}`}
          role="row"
          key={row.mode}
          onMouseEnter={() => setHovered({ row: rowIndex, column: null })}
        >
          <div
            className={`visibility-map-cell visibility-map-mode${isRowActive(rowIndex) ? " is-row-hover" : ""}${isColumnActive("mode") ? " is-col-hover" : ""}${hovered?.row === rowIndex && hovered?.column === "mode" ? " is-target" : ""}`}
            role="cell"
            onMouseEnter={() => setHovered({ row: rowIndex, column: "mode" })}
          >
            <i />
            <strong>{row.mode}</strong>
          </div>

          {columns.map((column) => (
            <div
              key={column.id}
              className={`visibility-map-cell${isRowActive(rowIndex) ? " is-row-hover" : ""}${isColumnActive(column.id) ? " is-col-hover" : ""}${hovered?.row === rowIndex && hovered?.column === column.id ? " is-target" : ""}`}
              role="cell"
              data-column={column.label}
              onMouseEnter={() => setHovered({ row: rowIndex, column: column.id })}
            >
              {row.cells[column.id]}
            </div>
          ))}
        </div>
      ))}

      <div className="visibility-map-note">
        <strong>Identity-based services are different.</strong>
        <span> If you log into a third-party account, that service can know who you are.</span>
      </div>
    </div>
  );
}