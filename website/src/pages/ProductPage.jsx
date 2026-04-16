import { Link } from "react-router-dom";
import { PageHero } from "../components/PageHero";
import { Reveal } from "../components/Reveal";
import { Seo } from "../components/Seo";
import { WorkflowGraphic } from "../components/WorkflowGraphic";
import { modeSteps } from "../content/site";

export function ProductPage() {
  return (
    <>
      <Seo
        title="Product"
        description="How Amon works across Search and Browse, Clean View, Protected Session, and Workspace."
      />

      <PageHero
        eyebrow="Product"
        title="One workflow. Four modes."
        lede="Amon starts as a normal place to begin, then deepens as the question becomes more important."
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
            <WorkflowGraphic compact />
          </Reveal>

          <div className="stack">
            {modeSteps.map((mode, index) => (
              <Reveal key={mode.id} className="mode-detail" delay={index * 70}>
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
        <div className="frame">
          <Reveal className="section-heading">
            <span className="eyebrow">Difference</span>
            <h2>The modes are meant to work together.</h2>
          </Reveal>

          <div className="comparison-grid">
            <Reveal className="comparison-panel">
              <h3>What Amon is</h3>
              <ul className="bullet-list">
                <li>A workflow for inquiry.</li>
                <li>A calmer reading surface.</li>
                <li>A local place for meaningful work.</li>
              </ul>
            </Reveal>

            <Reveal className="comparison-panel comparison-panel-muted" delay={100}>
              <h3>What Amon is not</h3>
              <ul className="bullet-list">
                <li>Not a browser replacement.</li>
                <li>Not just search.</li>
                <li>Not a generic AI wrapper.</li>
              </ul>
            </Reveal>
          </div>
        </div>
      </section>

      <section className="page-section page-section-cta">
        <div className="frame">
          <Reveal className="cta-panel">
            <div>
              <span className="eyebrow">Next</span>
              <h2>See whether the workflow fits.</h2>
            </div>
            <div className="button-row">
              <Link className="button" to="/contact">
                Request access
              </Link>
              <Link className="button button-secondary" to="/privacy">
                Read the privacy posture
              </Link>
            </div>
          </Reveal>
        </div>
      </section>
    </>
  );
}
