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
        lede="Amon is meant to be a normal place to begin online inquiry, then become more useful as the task becomes meaningful."
        aside={
          <p>
            Search / Browse → Clean View → Protected Session → Workspace
          </p>
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
            <span className="eyebrow">What makes it different</span>
            <h2>Progressive depth instead of one browser mode for everything.</h2>
          </Reveal>

          <div className="comparison-grid">
            <Reveal className="comparison-panel">
              <h3>What Amon is</h3>
              <ul className="bullet-list">
                <li>A workflow for inquiry.</li>
                <li>A calmer reading and decision environment.</li>
                <li>A place to keep meaningful work locally.</li>
              </ul>
            </Reveal>

            <Reveal className="comparison-panel comparison-panel-muted" delay={100}>
              <h3>What Amon is not</h3>
              <ul className="bullet-list">
                <li>Not just a search engine.</li>
                <li>Not just a browser.</li>
                <li>Not just a VPN or generic AI wrapper.</li>
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
              <h2>See whether Amon fits your workflow.</h2>
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
