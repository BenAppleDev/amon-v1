import { useState } from "react";

export function ModeRail({ steps }) {
  const [activeId, setActiveId] = useState(null);

  return (
    <div className="mode-rail" aria-label="Amon progression through four modes" data-active-step={activeId || undefined}>
      {steps.map((step, index) => (
        <article
          key={step.id}
          className={`mode-rail-step${index < steps.length - 1 ? " mode-rail-step-connected" : ""}${activeId === step.id ? " is-active" : ""}`}
          data-step={step.id}
          style={{ "--step-index": index }}
          tabIndex={0}
          onMouseEnter={() => setActiveId(step.id)}
          onMouseLeave={() => setActiveId(null)}
          onFocus={() => setActiveId(step.id)}
          onBlur={() => setActiveId(null)}
        >
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
