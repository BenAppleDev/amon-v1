import { Link } from "react-router-dom";
import { PageHero } from "../components/PageHero";
import { Reveal } from "../components/Reveal";
import { Seo } from "../components/Seo";
import { VisibilityMatrixDiagram } from "../components/VisibilityMatrixDiagram";
import { nonClaims, privacyMechanisms, privacyModeMap } from "../content/site";

export function PrivacyPage() {
  return (
    <>
      <Seo
        title="Privacy"
        description="How Amon limits visibility: requests go through Amon, saved work stays local, and no durable query-to-account history is retained."
      />

      <PageHero
        eyebrow="Privacy"
        title="How Amon limits visibility."
        lede="Amon is designed so no single system sees everything you search, open, and keep. Requests enter through Amon’s privacy route; what changes is whether the page is live, text-extracted, or remote-in."
      />

      <section className="page-section">
        <div className="frame trust-grid">
          <Reveal>
            <VisibilityMatrixDiagram />
          </Reveal>

          <div className="stack">
            <Reveal className="trust-block">
              <h3>No durable query-to-account record</h3>
              <p>
                Amon does not store query text, result sets, destination URLs, page bodies, protected-session content, or workspace data as server-side history.
              </p>
            </Reveal>

            <Reveal className="trust-block" delay={80}>
              <h3>Company-unreadable saved work</h3>
              <p>
                What you save stays locally encrypted on your device. Amon cannot decrypt your local workspace files.
              </p>
            </Reveal>

            <Reveal className="trust-block trust-block-muted" delay={160}>
              <h3>Metadata-only operations</h3>
              <p>
                Operations are designed around health, quota, policy, and abuse-prevention metadata—not readable user content.
              </p>
            </Reveal>
          </div>
        </div>
      </section>

      <section className="page-section">
        <div className="frame">
          <Reveal className="section-heading">
            <span className="eyebrow">Mechanisms</span>
            <h2>Short, explicit boundaries.</h2>
            <p>
              These are the product-level mechanisms Amon uses to avoid turning inquiry into a durable server-side profile.
            </p>
          </Reveal>

          <div className="mechanism-grid">
            {privacyMechanisms.map((item, index) => (
              <Reveal
                key={item.title}
                className={`comparison-panel${index % 2 === 1 ? " comparison-panel-muted" : ""}`}
                delay={index * 60}
              >
                <h3>{item.title}</h3>
                <p>{item.text}</p>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      <section className="page-section">
        <div className="frame">
          <Reveal className="section-heading">
            <span className="eyebrow">Mode by mode</span>
            <h2>What changes depends on the path.</h2>
            <p>
              The privacy route is the baseline. Local, Clean View, Protected Session, and Workspace each change what gets exposed and what gets retained.
            </p>
          </Reveal>

          <div className="privacy-mode-grid">
            {privacyModeMap.map((item, index) => (
              <Reveal
                key={item.id}
                className={`comparison-panel${index % 2 === 1 ? " comparison-panel-muted" : ""}`}
                delay={index * 60}
              >
                <h3>{item.name}</h3>
                <p>{item.detail}</p>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      <section className="page-section">
        <div className="frame comparison-grid comparison-grid-equal">
          <Reveal className="comparison-panel">
            <h3>Account access is not your browsing identity</h3>
            <p>
              Billing authorizes access to Amon. Browsing and request sessions use separate internal identities so billing does not become the internal browsing identity.
            </p>
          </Reveal>

          <Reveal className="comparison-panel comparison-panel-muted" delay={100}>
            <h3>Identity-based services are different</h3>
            <p>
              If you sign in to a third-party account, that service can know who you are. Amon can protect the path and your local saved work, but it cannot make account-based services anonymous.
            </p>
          </Reveal>
        </div>
      </section>

      <section className="page-section">
        <div className="frame">
          <Reveal className="section-heading">
            <span className="eyebrow">Boundaries</span>
            <h2>What Amon does not claim.</h2>
            <p>
              Strong privacy requires clear limits. Amon is designed to minimize visibility, not promise magic invisibility everywhere.
            </p>
          </Reveal>

          <div className="nonclaim-grid">
            {nonClaims.map((claim, index) => (
              <Reveal
                key={claim}
                className={`comparison-panel${index % 2 === 1 ? " comparison-panel-muted" : ""}`}
                delay={index * 50}
              >
                <h3>{claim}</h3>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      <section className="page-section page-section-cta">
        <div className="frame">
          <Reveal className="cta-panel">
            <div>
              <span className="eyebrow">FAQ</span>
              <h2>Want the plain-language version?</h2>
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