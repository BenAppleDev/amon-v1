import { privacyPillars } from "../content/site";

export function BoundaryGraphic() {
  return (
    <div className="boundary-graphic" aria-label="Amon trust boundaries">
      <div className="boundary-track" aria-hidden="true" />
      {privacyPillars.map((pillar, index) => (
        <article
          key={pillar.label}
          className={`boundary-node boundary-node-${pillar.tone}`}
          style={{ "--node-index": index }}
        >
          <span>{pillar.label}</span>
          <strong>{pillar.title}</strong>
        </article>
      ))}
    </div>
  );
}
