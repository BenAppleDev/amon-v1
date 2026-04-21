import { Link } from "react-router-dom";
import { ModeComparisonDiagram } from "../components/ModeComparisonDiagram";
import { PageHero } from "../components/PageHero";
import { RequestFlowDiagram } from "../components/RequestFlowDiagram";
import { Reveal } from "../components/Reveal";
import { Seo } from "../components/Seo";
import { modeDeepDives } from "../content/site";

export function ProductPage() {
  return (
    <>
      <Seo
        title="Product"
        description="How Amon routes requests through Local, Clean View, Protected Session, and Workspace."
      />

      <PageHero
        eyebrow="Product"
        title="How Amon handles requests."
        lede="Every request goes through Amon’s privacy layer. What changes is how it is handled: locally through the privacy route, cleanly as retrieved information, or through a protected remote session."
        aside={
          <>
            <span className="note-kicker">Privacy paths</span>
            <p>Local → Clean View → Protected Session → Workspace</p>
          </>
        }
      />

      <section className="page-section">
        <div className="frame feature-split">
          <Reveal>
            <RequestFlowDiagram compact />
          </Reveal>

          <div className="stack">
            <Reveal className="comparison-panel">
              <h3>Same entry point. Different handling.</h3>
              <p>
                Amon looks like a normal search and browsing app, but it does not treat every request the same. The system can recommend the right path based on what the task needs.
              </p>
            </Reveal>

            <Reveal className="comparison-panel comparison-panel-muted" delay={80}>
              <h3>The system recommends. You choose.</h3>
              <p>
                Clean View is the default for reading and research. Protected Session is available when the real site is needed. Local browsing still runs through Amon’s privacy route.
              </p>
            </Reveal>
          </div>
        </div>
      </section>

      <section className="page-section">
        <div className="frame">
          <Reveal className="section-heading">
            <span className="eyebrow">Modes</span>
            <h2>One request. Three privacy paths.</h2>
            <p>
              Each path changes what happens between you, Amon, and the web.
            </p>
          </Reveal>

          <Reveal delay={100}>
            <ModeComparisonDiagram />
          </Reveal>
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

      <section className="page-section">
        <div className="frame comparison-grid comparison-grid-equal">
          <Reveal className="comparison-panel">
            <h3>Built for decisions, not surveillance</h3>
            <p>
              Search, browsing, comparison, and saved work do not have to collapse into one visible record. Amon separates the path so the whole inquiry is harder to centralize.
            </p>
          </Reveal>

          <Reveal className="comparison-panel comparison-panel-muted" delay={100}>
            <h3>Not every workflow is in scope</h3>
            <p>
              Amon works best for public-web inquiry, comparison, research, and decision-making. Logging into third-party accounts, completing identity-based workflows, or using personal services can reveal identity to those services.
            </p>
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