import { Link } from "react-router-dom";
import { PageHero } from "../components/PageHero";
import { Reveal } from "../components/Reveal";
import { Seo } from "../components/Seo";

export function AboutPage() {
  return (
    <>
      <Seo
        title="About"
        description="Why Amon exists: the modern internet turns curiosity into behavioral data, and Amon offers a different environment for inquiry."
      />

      <PageHero
        eyebrow="About / Vision"
        title="Why Amon exists."
        lede="The modern economy runs on data and inference. Every meaningful question now produces signals: search history, browsing patterns, purchase intent, location data, and inferred preferences."
      />

      <section className="page-section belief-section">
        <div className="frame belief-stage belief-stage-page">
          <Reveal className="belief-copy">
            <span className="eyebrow">Why Amon exists</span>
            <p className="belief-quote">Every meaningful question now produces data.</p>
            <p className="belief-support">
              Researching a move, comparing jobs, evaluating a major purchase, or revisiting a personal question does not just return information. It also creates signals about intent, preference, and likely next action.
            </p>
          </Reveal>
        </div>
      </section>

      <section className="page-section">
        <div className="frame comparison-grid comparison-grid-equal">
          <Reveal className="comparison-panel">
            <h3>What that does to inquiry</h3>
            <p>The default internet stack makes it easy for search, browsing, comparison, and revisits to collapse into one visible behavioral record. That is useful for systems that predict people. It is not always good for the person trying to think clearly.</p>
          </Reveal>

          <Reveal className="comparison-panel comparison-panel-muted" delay={100}>
            <h3>What Amon is for</h3>
            <p>Amon is a search and browsing app for those moments. It routes requests through different privacy paths so no single system sees everything, and what you keep stays with you locally.</p>
          </Reveal>
        </div>
      </section>

      <section className="page-section page-section-cta">
        <div className="frame">
          <Reveal className="cta-panel">
            <div>
              <span className="eyebrow">Next</span>
              <h2>See how the system works.</h2>
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
