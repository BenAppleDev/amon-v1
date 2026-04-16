import { Link } from "react-router-dom";
import { BoundaryGraphic } from "../components/BoundaryGraphic";
import { PageHero } from "../components/PageHero";
import { Reveal } from "../components/Reveal";
import { Seo } from "../components/Seo";
import { nonClaims } from "../content/site";

export function PrivacyPage() {
  return (
    <>
      <Seo
        title="Privacy"
        description="What Amon minimizes, what stays with the user, and what it does not claim."
      />

      <PageHero
        eyebrow="Privacy"
        title="What Amon minimizes."
        lede="A sober view of what the service is meant to minimize, what stays with the user, and what Amon does not claim."
      />

      <section className="page-section">
        <div className="frame trust-grid">
          <Reveal>
            <BoundaryGraphic />
          </Reveal>

          <div className="stack">
            <Reveal className="trust-block">
              <h3>What Amon minimizes</h3>
              <ul className="bullet-list">
                <li>Durable query text.</li>
                <li>Durable result sets.</li>
                <li>Durable page content on its servers.</li>
              </ul>
            </Reveal>

            <Reveal className="trust-block" delay={80}>
              <h3>What stays with you</h3>
              <ul className="bullet-list">
                <li>Saved work belongs in a local workspace by default.</li>
                <li>Meaningful inquiry should not automatically become a server-side archive.</li>
              </ul>
            </Reveal>

            <Reveal className="trust-block trust-block-muted" delay={160}>
              <h3>What Amon does not claim</h3>
              <ul className="bullet-list">
                {nonClaims.map((claim) => (
                  <li key={claim}>{claim}</li>
                ))}
              </ul>
            </Reveal>
          </div>
        </div>
      </section>

      <section className="page-section">
        <div className="frame comparison-grid">
          <Reveal className="comparison-panel">
            <h3>Protected Session</h3>
            <p>A deeper, more controlled mode for selected public-web tasks that need more structure and care.</p>
          </Reveal>

          <Reveal className="comparison-panel comparison-panel-muted" delay={100}>
            <h3>Scope</h3>
            <p>Amon should stay explicit about scope. It is not promising universal support or total anonymity.</p>
          </Reveal>
        </div>
      </section>

      <section className="page-section page-section-cta">
        <div className="frame">
          <Reveal className="cta-panel">
            <div>
              <span className="eyebrow">FAQ</span>
              <h2>Still comparing the category?</h2>
            </div>
            <div className="button-row">
              <Link className="button" to="/faq">
                Read FAQ
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
