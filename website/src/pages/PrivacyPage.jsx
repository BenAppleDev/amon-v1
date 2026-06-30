import { Link } from "react-router-dom";
import { PageHero } from "../components/PageHero";
import { Reveal } from "../components/Reveal";
import { Seo } from "../components/Seo";
import { VisibilityMatrixDiagram } from "../components/VisibilityMatrixDiagram";
import { privacyHighlights, privacyMechanismsPublic } from "../content/site";

export function PrivacyPage() {
  return (
    <>
      <Seo
        title="Privacy"
        description="What Amon can see, what sites can see, and what stays on your device."
      />

      <PageHero
        eyebrow="Privacy"
        title="What Amon can see, what sites can see, and what stays on your device."
        lede="Amon is designed so no single layer has the full picture. Your account authorizes access, your browsing requests use separate session handling, destination sites see the selected Amon path, and saved work stays encrypted on your device."
      />

      <section className="page-section">
        <div className="frame trust-grid">
          <Reveal>
            <VisibilityMatrixDiagram />
          </Reveal>

          <div className="stack">
            {privacyHighlights.map((item, index) => (
              <Reveal
                key={item.title}
                className={`trust-block${index === 2 ? " trust-block-muted" : ""}`}
                delay={index * 80}
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
            <span className="eyebrow">How it works</span>
            <h2>Designed so no single layer has the whole picture.</h2>
            <p>
              Amon separates access, request handling, destination exposure, and saved work so the
              entire flow does not collapse into one durable identity-linked record.
            </p>
          </Reveal>

          <div className="mechanism-grid">
            {privacyMechanismsPublic.map((item, index) => (
              <Reveal
                key={item.title}
                className={`comparison-panel${index === 1 ? " comparison-panel-muted" : ""}`}
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
        <div className="frame comparison-grid comparison-grid-equal">
          <Reveal className="comparison-panel">
            <h3>What Amon does claim</h3>
            <p>
              Amon is designed to minimize durable identity-linked inquiry records, protect saved
              work on your device, and keep operational visibility focused on metadata rather than
              readable research content.
            </p>
          </Reveal>

          <Reveal className="comparison-panel comparison-panel-muted" delay={100}>
            <h3>What Amon does not claim</h3>
            <p>
              Amon does not claim perfect anonymity, invisibility, or the power to make
              third-party accounts forget who you are once you choose to identify yourself to them.
            </p>
          </Reveal>
        </div>
      </section>

      <section className="page-section page-section-cta">
        <div className="frame">
          <Reveal className="cta-panel">
            <div>
              <span className="eyebrow">Next</span>
              <h2>See the product paths in plain language.</h2>
            </div>
            <div className="button-row">
              <Link className="button" to="/product">
                Read product
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
