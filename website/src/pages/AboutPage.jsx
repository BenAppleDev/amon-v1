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
        lede="The modern internet does not just answer questions. It records them, connects them, and turns them into signals about what someone may do next."
      />

      <section className="page-section belief-section">
        <div className="frame belief-stage belief-stage-page">
          <Reveal className="belief-copy">
            <span className="eyebrow">Why Amon exists</span>
            <p className="belief-quote">People deserve a place to search, compare, and think without quietly feeding someone else&apos;s dataset.</p>
            <p className="belief-support">
              The economic model is familiar: demographic data, behavioral data, location data, purchase intent, search history, browsing patterns, inferred preferences. Amon is a response to that model.
            </p>
          </Reveal>
        </div>
      </section>

      <section className="page-section">
        <div className="frame comparison-grid comparison-grid-equal">
          <Reveal className="comparison-panel">
            <h3>What that means in practice</h3>
            <p>Ordinary searches, comparisons, and revisits do not just help someone make a decision. They also become data points about intent, preference, and likely next action.</p>
          </Reveal>

          <Reveal className="comparison-panel comparison-panel-muted" delay={100}>
            <h3>What Amon offers instead</h3>
            <p>Amon gives people a place to search, browse, compare, and make decisions with clearer boundaries. Your curiosity should not automatically become part of someone else&apos;s dataset.</p>
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
