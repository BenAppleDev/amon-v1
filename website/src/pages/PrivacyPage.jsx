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
        description="How Amon limits centralized visibility, what it does not store, what stays local, and what it does not claim."
      />

      <PageHero
        eyebrow="Privacy"
        title="How Amon limits visibility."
        lede="Amon is designed so no single system sees everything you search, open, and keep. Search goes through Amon, some pages are fetched cleanly, some browsing is mediated, and what you save stays local."
      />

      <section className="page-section">
        <div className="frame trust-grid">
          <Reveal>
            <BoundaryGraphic />
          </Reveal>

          <div className="stack">
            <Reveal className="trust-block">
              <h3>What Amon does not keep</h3>
              <ul className="bullet-list">
                <li>Browsing history.</li>
                <li>A single server-side record of everything you searched, opened, and compared.</li>
                <li>Saved work as centralized service-side history.</li>
              </ul>
            </Reveal>

            <Reveal className="trust-block" delay={80}>
              <h3>What changes by mode</h3>
              <ul className="bullet-list">
                <li>Search starts through Amon.</li>
                <li>Pages can be handled cleanly when you only need the information.</li>
                <li>Live browsing can be mediated when you need the actual site.</li>
                <li>Saved work stays local in Workspace.</li>
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
            <p>The Product page explains each mode in full. This is the short privacy map.</p>
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
