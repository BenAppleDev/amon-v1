import { Link } from "react-router-dom";
import { PageHero } from "../components/PageHero";
import { Reveal } from "../components/Reveal";
import { Seo } from "../components/Seo";

export function AboutPage() {
  return (
    <>
      <Seo
        title="About"
        description="Why Amon exists and the belief behind its inquiry workflow."
      />

      <PageHero
        eyebrow="About / Vision"
        title="Why Amon exists."
        lede="Questions online used to feel lighter. The systems around them changed. Amon is a response to that shift."
      />

      <section className="page-section belief-section">
        <div className="frame belief-stage belief-stage-page">
          <Reveal className="belief-copy">
            <span className="eyebrow">The idea</span>
            <p className="belief-quote">Important questions deserve a place to stay questions for a little longer.</p>
          </Reveal>
        </div>
      </section>

      <section className="page-section">
        <div className="frame comparison-grid comparison-grid-equal">
          <Reveal className="comparison-panel">
            <h3>What changed</h3>
            <p>Questions no longer just find answers. They get recorded, interpreted, and connected to everything else a person does online.</p>
          </Reveal>

          <Reveal className="comparison-panel comparison-panel-muted" delay={100}>
            <h3>What Amon believes</h3>
            <p>Ordinary people making ordinary decisions should have a place to think without being turned into a profile.</p>
          </Reveal>
        </div>
      </section>

      <section className="page-section page-section-cta">
        <div className="frame">
          <Reveal className="cta-panel">
            <div>
              <span className="eyebrow">Next</span>
              <h2>Read how Amon works.</h2>
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
