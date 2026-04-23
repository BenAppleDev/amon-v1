import { Link } from "react-router-dom";
import { ModeComparisonDiagram } from "../components/ModeComparisonDiagram";
import { PageHero } from "../components/PageHero";
import { Reveal } from "../components/Reveal";
import { Seo } from "../components/Seo";
import { modeDeepDives, policyBoundaries, productBoundaryCards } from "../content/site";

export function ProductPage() {
  return (
    <>
      <Seo
        title="Product"
        description="How Amon keeps requests as anonymous as the task allows through live browsing, text extraction, protected remote sessions, and local workspace ownership."
      />

      <PageHero
        eyebrow="Product"
        title="Least exposing path first."
        lede="Amon handles each request through the path that preserves anonymity for as long as the task allows: live through the privacy route, cleanly as extracted text, or through a protected remote session."
        aside={
          <>
            <span className="note-kicker">Core model</span>
            <p>Anonymous where possible. Mediated when needed. Explicit when the boundary changes.</p>
          </>
        }
      />

      <section className="page-section">
        <div className="frame">
          <Reveal className="section-heading">
            <span className="eyebrow">Until then</span>
            <h2>What Amon preserves before identity is required.</h2>
            <p>
              Amon is not a promise of invisibility everywhere. It is a system for preserving anonymity where possible and making the exposure tradeoff clear when a task requires more.
            </p>
          </Reveal>

          <div className="policy-grid">
            {productBoundaryCards.map((item, index) => (
              <Reveal
                key={item.title}
                className={`comparison-panel${index % 2 === 1 ? " comparison-panel-muted" : ""}`}
                delay={index * 70}
              >
                <h3>{item.title}</h3>
                <p>{item.text}</p>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      <section className="page-section">
        <div className="frame comparison-grid comparison-grid-equal">
          <Reveal className="comparison-panel">
            <h3>Not a linear flow.</h3>
            <p>
              Local, Clean View, and Protected Session are not steps. They are choices for how to handle a page after the request enters Amon.
            </p>
          </Reveal>

          <Reveal className="comparison-panel comparison-panel-muted" delay={80}>
            <h3>The system recommends. You choose.</h3>
            <p>
              Amon can recommend text extraction or protected remote browsing when a site needs it, but the user stays in control of the path.
            </p>
          </Reveal>
        </div>
      </section>

      <section className="page-section">
        <div className="frame">
          <Reveal className="section-heading">
            <span className="eyebrow">Request paths</span>
            <h2>Use the site live, extract the text, or remote in.</h2>
            <p>
              The privacy route is the baseline. The handling path depends on what the task needs and how much exposure the user is willing to accept.
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
        <div className="frame">
          <Reveal className="section-heading">
            <span className="eyebrow">Policy</span>
            <h2>Privacy without an unlimited free-for-all.</h2>
            <p>
              Amon is designed to protect ordinary inquiry while keeping mediated access bounded, governed, and safe.
            </p>
          </Reveal>

          <div className="policy-grid">
            {policyBoundaries.map((item, index) => (
              <Reveal
                key={item.title}
                className={`comparison-panel${index % 2 === 1 ? " comparison-panel-muted" : ""}`}
                delay={index * 70}
              >
                <h3>{item.title}</h3>
                <p>{item.text}</p>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      <section className="page-section">
        <div className="frame comparison-grid comparison-grid-equal">
          <Reveal className="comparison-panel">
            <h3>Built for decisions, not surveillance</h3>
            <p>
              Search, browsing, comparison, and saved work do not have to collapse into one visible record. Amon separates the path so the whole inquiry is harder to centralize.
            </p>
          </Reveal>

          <Reveal className="comparison-panel comparison-panel-muted" delay={100}>
            <h3>When anonymity stops being possible</h3>
            <p>
              Logging into third-party accounts, submitting personal forms, or completing identity-based workflows can reveal identity to those services. Amon’s role is to keep the path protected until that boundary is reached.
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