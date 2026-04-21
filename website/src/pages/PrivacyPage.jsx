import { Link } from "react-router-dom";
import { BoundaryGraphic } from "../components/BoundaryGraphic";
import { PageHero } from "../components/PageHero";
import { Reveal } from "../components/Reveal";
import { Seo } from "../components/Seo";
import { nonClaims, privacyModeMap } from "../content/site";

export function PrivacyPage() {
  return (
    <>
      <Seo
        title="Privacy"
        description="How Amon limits visibility: every request goes through Amon, saved work stays local, and no single system sees the whole path."
      />

      <PageHero
        eyebrow="Privacy"
        title="How Amon limits visibility."
        lede="Amon is designed so no single system sees everything you search, open, and keep. Every request goes through Amon’s privacy layer; what changes is whether it is handled locally, cleanly, or through a protected session."
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
                <li>Centralized visibility across search, browsing, and saved work.</li>
                <li>Durable server-side records of what you searched, opened, and compared.</li>
                <li>Direct exposure of your device to websites during Amon browsing.</li>
              </ul>
            </Reveal>

            <Reveal className="trust-block" delay={80}>
              <h3>How requests are handled</h3>
              <ul className="bullet-list">
                <li>Local opens the real site in-app through Amon’s privacy route.</li>
                <li>Clean View retrieves and presents information without a conventional site visit from your device.</li>
                <li>Protected Session mediates live browsing through a controlled remote environment.</li>
                <li>Workspace keeps saved work local and encrypted on your device.</li>
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
        <div className="frame">
          <Reveal className="section-heading">
            <span className="eyebrow">Mode by mode</span>
            <h2>How the boundary works in practice.</h2>
            <p>
              Amon does not treat every request the same. The goal is to limit what any one party can see while keeping the web usable.
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
              Billing authorizes access to Amon. Inside the product, browsing and session handling use separate request paths so account access does not become a single durable activity spine.
            </p>
          </Reveal>

          <Reveal className="comparison-panel comparison-panel-muted" delay={100}>
            <h3>Identity-based services are different</h3>
            <p>
              If you sign in to a third-party account, that service can know who you are. Amon can protect the path and local storage, but it cannot make account-based services forget your identity.
            </p>
          </Reveal>
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