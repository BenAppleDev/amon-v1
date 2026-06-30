import { privacyMatrixColumns, privacyMatrixRows } from "../content/site";

const stateLabels = {
  visible: "Visible",
  limited: "Limited",
  "not-stored": "Not stored",
  "local-only": "Local only",
  "metadata-only": "Metadata only"
};

export function VisibilityMatrixDiagram() {
  return (
    <div className="privacy-matrix" aria-label="Visibility matrix showing what each layer can see">
      <div className="privacy-matrix-table" role="table" aria-label="Visibility matrix">
        <div className="privacy-matrix-row privacy-matrix-header" role="row">
          <div className="privacy-matrix-cell privacy-matrix-topic" role="columnheader">
            Data
          </div>

          {privacyMatrixColumns.map((column) => (
            <div key={column.id} className="privacy-matrix-cell" role="columnheader">
              {column.label}
            </div>
          ))}
        </div>

        {privacyMatrixRows.map((row) => (
          <div key={row.label} className="privacy-matrix-row" role="row">
            <div className="privacy-matrix-cell privacy-matrix-topic" role="rowheader">
              {row.label}
            </div>

            {privacyMatrixColumns.map((column) => {
              const value = row.values[column.id];

              return (
                <div key={column.id} className="privacy-matrix-cell" role="cell">
                  <span className={`privacy-status privacy-status-${value.state}`}>
                    <i aria-hidden="true" />
                    {stateLabels[value.state]}
                  </span>
                  <small>{value.detail}</small>
                </div>
              );
            })}
          </div>
        ))}
      </div>

      <div className="privacy-matrix-stack" aria-hidden="true">
        {privacyMatrixRows.map((row) => (
          <article key={row.label} className="privacy-matrix-stack-card">
            <h3>{row.label}</h3>

            <div className="privacy-matrix-stack-items">
              {privacyMatrixColumns.map((column) => {
                const value = row.values[column.id];

                return (
                  <div key={column.id} className="privacy-matrix-stack-item">
                    <strong>{column.label}</strong>
                    <span className={`privacy-status privacy-status-${value.state}`}>
                      <i aria-hidden="true" />
                      {stateLabels[value.state]}
                    </span>
                    <small>{value.detail}</small>
                  </div>
                );
              })}
            </div>
          </article>
        ))}
      </div>

      <p className="privacy-matrix-note">
        Exact handling can vary by feature and release. Amon’s design goal is to minimize durable
        identity-linked inquiry records.
      </p>
    </div>
  );
}
