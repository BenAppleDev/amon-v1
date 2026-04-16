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
        description="A concise view of Amon's privacy posture and scope limits."
      />

      <PageHero
        eyebrow="Privacy"
        title="Different posture. Clear limits."
        lede="The public site should explain the trust boundary quickly: what Amon is designed to minimize, what stays local by default, and what it does not claim."
      />

      <section className="page-section">
        <div className="frame trust-grid">
          <Reveal>
            <BoundaryGraphic />
          </Reveal>

          <div className="stack">
            <Reveal className="trust-block">
              <h3>What we can say plainly</h3>
              <ul className="bullet-list">
                <li>The service direction is to minimize durable query and page content.</li>
                <li>Saved work belongs in a local workspace by default.</li>
                <li>Protected Session is for selected public-web tasks that need more care.</li>
              </ul>
            </Reveal>

            <Reveal className="trust-block trust-block-muted" delay={120}>
              <h3>What we do not claim</h3>
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
            <h3>Protected Session, in user language</h3>
            <p>
              It is a more controlled mode for selected public-web tasks. Use it when the live
              site is necessary, not as the default for everything.
            </p>
          </Reveal>

          <Reveal className="comparison-panel comparison-panel-muted" delay={100}>
            <h3>Scope discipline</h3>
            <p>
              The strongest trust signal is honest scope. Amon should never imply universal site
              support or total anonymity.
            </p>
          </Reveal>
        </div>
      </section>

      <section className="page-section page-section-cta">
        <div className="frame">
          <Reveal className="cta-panel">
            <div>
              <span className="eyebrow">Contact</span>
              <h2>Questions about fit or trust?</h2>
            </div>
            <div className="button-row">
              <Link className="button" to="/contact">
                Request access
              </Link>
              <a
                className="button button-secondary"
                href="mailto:hello@getamon.com?subject=Amon%20privacy%20question"
              >
                Ask by email
              </a>
            </div>
          </Reveal>
        </div>
      </section>
    </>
  );
}
