import { Link } from "react-router-dom";
import { PageHero } from "../components/PageHero";
import { Reveal } from "../components/Reveal";
import { Seo } from "../components/Seo";
import { WorkflowGraphic } from "../components/WorkflowGraphic";
import { modeDeepDives } from "../content/site";

export function ProductPage() {
  return (
    <>
      <Seo
        title="Product"
        description="How Amon routes inquiry through Search and Browse, Clean View, Protected Session, and Workspace."
      />

      <PageHero
        eyebrow="Product"
        title="How Amon handles inquiry."
        lede="Amon does not treat every search, page open, and saved note as the same kind of request. It can keep a request in the familiar search layer, fetch information cleanly, mediate live browsing, and keep what matters in a local workspace."
        aside={
          <>
            <span className="note-kicker">Privacy paths</span>
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
            <Reveal className="comparison-panel">
              <h3>One workflow. Four modes.</h3>
              <p>Amon starts in a familiar search layer, goes deeper when the task needs cleaner retrieval or mediated browsing, and keeps what matters in a local workspace.</p>
            </Reveal>

            <Reveal className="comparison-panel comparison-panel-muted" delay={80}>
              <h3>What changes when you click</h3>
              <p>A page does not always have to open as a direct visit from your device. Amon can search, fetch, mediate, and save through different privacy paths.</p>
            </Reveal>
          </div>
        </div>
      </section>

      {modeDeepDives.map((mode, modeIndex) => (
        <section className="page-section product-mode-section" key={mode.id}>
          <div className="frame product-mode-layout">
            <Reveal className="product-mode-intro">
              <span className="eyebrow">{mode.number}</span>
              <h2>{mode.name}</h2>
              <p>{mode.summary}</p>
            </Reveal>

            <div className="product-mode-facts">
              {mode.facts.map((fact, factIndex) => (
                <Reveal
                  key={fact.title}
                  className="comparison-panel"
                  delay={(modeIndex * 40) + (factIndex * 50)}
                >
                  <h3>{fact.title}</h3>
                  <p>{fact.text}</p>
                </Reveal>
              ))}
            </div>
          </div>
        </section>
      ))}

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
