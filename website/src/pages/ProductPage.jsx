import { useState } from "react";
import { Link } from "react-router-dom";
import { PageHero } from "../components/PageHero";
import { Reveal } from "../components/Reveal";
import { Seo } from "../components/Seo";
import { WorkflowGraphic } from "../components/WorkflowGraphic";
import { modeSteps } from "../content/site";

export function ProductPage() {
  const [activeMode, setActiveMode] = useState(null);

  return (
    <>
      <Seo
        title="Product"
        description="How Amon moves from Search and Browse to Clean View, Protected Session, and Workspace."
      />

      <PageHero
        eyebrow="Product"
        title="How Amon works."
        lede="Amon starts where online inquiry usually starts. Then it deepens as the question becomes more important."
        aside={
          <>
            <span className="note-kicker">Sequence</span>
            <p>Search / Browse → Clean View → Protected Session → Workspace</p>
          </>
        }
      />

      <section className="page-section">
        <div className="frame feature-split">
          <Reveal>
            <WorkflowGraphic compact activeStep={activeMode} />
          </Reveal>

          <div className="stack">
            {modeSteps.map((mode, index) => (
              <Reveal
                key={mode.id}
                className={`mode-detail${activeMode === mode.id ? " is-active" : ""}`}
                delay={index * 70}
                tabIndex={0}
                data-step={mode.id}
                onMouseEnter={() => setActiveMode(mode.id)}
                onMouseLeave={() => setActiveMode(null)}
                onFocus={() => setActiveMode(mode.id)}
                onBlur={() => setActiveMode(null)}
              >
                <div className="mode-detail-label">
                  <span>{mode.number}</span>
                  <strong>{mode.name}</strong>
                </div>
                <p className="mode-line">{mode.line}</p>
                <p>{mode.detail}</p>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      <section className="page-section">
        <div className="frame product-summary-grid">
          <Reveal className="comparison-panel">
            <h3>Starts familiar</h3>
            <p>Search, browse, and open pages as you normally would.</p>
          </Reveal>

          <Reveal className="comparison-panel comparison-panel-muted" delay={80}>
            <h3>Gets deeper when needed</h3>
            <p>Move into cleaner reading and more structured modes only when the question matters.</p>
          </Reveal>

          <Reveal className="comparison-panel" delay={160}>
            <h3>Keeps the work</h3>
            <p>What matters can stay with you in a local workspace instead of a default cloud archive.</p>
          </Reveal>
        </div>
      </section>

      <section className="page-section page-section-cta">
        <div className="frame">
          <Reveal className="cta-panel">
            <div>
              <span className="eyebrow">Next</span>
              <h2>Read the privacy posture.</h2>
            </div>
            <div className="button-row">
              <Link className="button" to="/privacy">
                Read privacy
              </Link>
              <Link className="button button-secondary" to="/contact">
                Request access
              </Link>
            </div>
          </Reveal>
        </div>
      </section>
    </>
  );
}
