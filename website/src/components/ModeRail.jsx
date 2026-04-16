export function ModeRail({ steps }) {
  return (
    <div className="mode-rail" aria-label="Amon progression through four modes">
      <div className="mode-rail-line" aria-hidden="true" />
      {steps.map((step, index) => (
        <article key={step.id} className="mode-rail-step">
          <div className="mode-rail-marker" aria-hidden="true">
            <span>{step.number}</span>
          </div>
          <div className="mode-rail-copy">
            <h3>{step.name}</h3>
            <p>{step.line}</p>
          </div>
          {index < steps.length - 1 ? <div className="mode-rail-divider" aria-hidden="true" /> : null}
        </article>
      ))}
    </div>
  );
}
