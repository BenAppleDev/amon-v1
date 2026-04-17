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
        description="How Amon limits centralized visibility, what it does not store, what stays local, and what it does not claim."
      />

      <PageHero
        eyebrow="Privacy"
        title="How Amon limits visibility."
        lede="Amon is designed so no single system sees everything you search, open, and keep. What happens depends on mode, and what you save stays with you locally."
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
                <li>Centralized visibility across the full inquiry.</li>
                <li>Server-side retention of query text, result sets, and page content.</li>
                <li>A single durable record of everything you searched, opened, and compared.</li>
              </ul>
            </Reveal>

            <Reveal className="trust-block" delay={80}>
              <h3>What depends on mode</h3>
              <ul className="bullet-list">
                <li>Search and browsing start through Amon rather than the default stack tied to your device.</li>
                <li>Some pages can be handled as clean retrieval instead of a conventional site visit.</li>
                <li>Some live interactions can be mediated through a controlled remote session.</li>
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
            <h3>We do not store browsing history.</h3>
            <p>Your searches and page history do not become a server-side history log inside Amon.</p>
          </Reveal>

          <Reveal className="comparison-panel comparison-panel-muted" delay={100}>
            <h3>What you keep stays local.</h3>
            <p>Saved work lives in a local encrypted workspace on your device instead of becoming part of a centralized server-side profile.</p>
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
