import { Link } from "react-router-dom";
import { BoundaryGraphic } from "../components/BoundaryGraphic";
import { Reveal } from "../components/Reveal";
import { Seo } from "../components/Seo";
import { WorkflowGraphic } from "../components/WorkflowGraphic";
import { homeScenarios, modeSteps, nonClaims, positioningStatements } from "../content/site";

export function HomePage() {
  return (
    <>
      <Seo
        description="Amon is a private decision environment for searching, browsing, and thinking through meaningful questions online."
      />

      <section className="hero">
        <div className="frame hero-grid">
          <Reveal className="hero-copy">
            <span className="eyebrow">Private decision environment</span>
            <h1>Private by default. Deeper when needed.</h1>
            <p className="hero-lede">A private workflow for meaningful questions online.</p>
            <p className="hero-support">Start normally. Go deeper only when the question deserves it.</p>
            <div className="button-row">
              <Link className="button" to="/contact">
                Request access
              </Link>
              <Link className="button button-secondary" to="/product">
                See how it works
              </Link>
            </div>
            <p className="hero-flow">Search / Browse → Clean View → Protected Session → Workspace</p>
          </Reveal>

          <Reveal delay={120}>
            <WorkflowGraphic />
          </Reveal>
        </div>
      </section>

      <section className="position-band">
        <div className="frame position-band-grid">
          {positioningStatements.map((statement, index) => (
            <Reveal
              key={statement}
              className={`position-band-item${index === positioningStatements.length - 1 ? " is-strong" : ""}`}
              delay={index * 50}
            >
              {statement}
            </Reveal>
          ))}
        </div>
      </section>

      <section className="page-section">
        <div className="frame">
          <Reveal className="section-heading">
            <span className="eyebrow">Workflow</span>
            <h2>One question. Four modes.</h2>
            <p>Amon stays quiet at the start, then becomes more useful as the stakes rise.</p>
          </Reveal>

          <div className="mode-grid">
            {modeSteps.map((mode, index) => (
              <Reveal key={mode.id} className="mode-tile" delay={index * 60}>
                <span className="mode-number">{mode.number}</span>
                <h3>{mode.name}</h3>
                <p className="mode-line">{mode.line}</p>
                <p>{mode.detail}</p>
              </Reveal>
            ))}
          </div>

          <Reveal className="section-note" delay={180}>
            Protected Session is the deeper mode, not the default for everything.
          </Reveal>
        </div>
      </section>

      <section className="page-section">
        <div className="frame">
          <Reveal className="section-heading">
            <span className="eyebrow">When this matters</span>
            <h2>More useful when the question matters more.</h2>
            <p>Not every search needs more. Some do.</p>
          </Reveal>

          <div className="scenario-grid">
            {homeScenarios.map((scenario, index) => (
              <Reveal key={scenario.title} className="scenario" delay={index * 70}>
                <h3>{scenario.title}</h3>
                <p>{scenario.copy}</p>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      <section className="page-section">
        <div className="frame trust-grid">
          <div>
            <Reveal className="section-heading">
              <span className="eyebrow">Trust</span>
              <h2>A calmer trust posture.</h2>
              <p>Minimize what should not linger. Keep what matters local.</p>
            </Reveal>

            <Reveal delay={100}>
              <BoundaryGraphic />
            </Reveal>
          </div>

          <div className="trust-copy">
            <Reveal className="trust-block" delay={80}>
              <h3>Designed to minimize</h3>
              <ul className="bullet-list">
                <li>Minimize durable service-side query and page content.</li>
                <li>Keep saved work in a local workspace by default.</li>
                <li>Use deeper modes selectively instead of making everything equally exposed.</li>
              </ul>
            </Reveal>

            <Reveal className="trust-block trust-block-muted" delay={150}>
              <h3>Not claimed</h3>
              <ul className="bullet-list">
                {nonClaims.map((claim) => (
                  <li key={claim}>{claim}</li>
                ))}
              </ul>
            </Reveal>
          </div>
        </div>
      </section>

      <section className="page-section page-section-cta">
        <div className="frame">
          <Reveal className="cta-panel">
            <div>
              <span className="eyebrow">Request access</span>
              <h2>If this fits your workflow, get in touch.</h2>
              <p>A short note is enough.</p>
            </div>
            <div className="button-row">
              <Link className="button" to="/contact">
                Join the waitlist
              </Link>
              <a
                className="button button-secondary"
                href="mailto:hello@getamon.com?subject=Request%20access%20to%20Amon"
              >
                hello@getamon.com
              </a>
            </div>
          </Reveal>
        </div>
      </section>
    </>
  );
}
