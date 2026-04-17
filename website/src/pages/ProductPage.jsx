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
        description="How Amon routes inquiry through Search and Browse, Clean View, Protected Session, and Workspace."
      />

      <PageHero
        eyebrow="Product"
        title="How Amon handles inquiry."
        lede="Amon does not treat every search, page open, and saved note as the same kind of request. It routes inquiry through different paths depending on what you are doing."
        aside={
          <>
            <span className="note-kicker">Request paths</span>
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
            <h3>Not one kind of click</h3>
            <p>Opening something does not always have to mean the same type of request from your own device to the destination site.</p>
          </Reveal>

          <Reveal className="comparison-panel comparison-panel-muted" delay={80}>
            <h3>Handled by task</h3>
            <p>Amon can search, broker retrieval, mediate live browsing, or keep the result local depending on what the task actually needs.</p>
          </Reveal>

          <Reveal className="comparison-panel" delay={160}>
            <h3>No single system sees everything</h3>
            <p>Search, page access, live interaction, and saved work do not all collapse into one centralized record.</p>
          </Reveal>
        </div>
      </section>

      <section className="page-section page-section-cta">
        <div className="frame">
          <Reveal className="cta-panel">
            <div>
              <span className="eyebrow">Next</span>
              <h2>Read the privacy model.</h2>
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
