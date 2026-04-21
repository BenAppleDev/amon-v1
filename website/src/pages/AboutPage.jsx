import { Link } from "react-router-dom";
import { PageHero } from "../components/PageHero";
import { Reveal } from "../components/Reveal";
import { Seo } from "../components/Seo";

export function AboutPage() {
  return (
    <>
      <Seo
        title="About"
        description="Why Amon exists: every meaningful question online now produces data, and Amon offers a different way to search, browse, and think through decisions."
      />

      <PageHero
        eyebrow="About / Vision"
        title="Why Amon exists."
        lede="Every meaningful question online now produces data. Amon was built for a different way to search, browse, compare, and decide."
      />

      <section className="page-section belief-section">
        <div className="frame belief-stage belief-stage-page">
          <Reveal className="belief-copy">
            <span className="eyebrow">Why Amon exists</span>
            <p className="belief-quote">Every meaningful question now produces data.</p>
            <p className="belief-support">
              Search history, browsing patterns, comparison behavior, purchase intent, and revisits are used to build profiles that predict what people care about and what they may do next.
            </p>
          </Reveal>
        </div>
      </section>

      <section className="page-section">
        <div className="frame comparison-grid comparison-grid-equal">
          <Reveal className="comparison-panel">
            <h3>What that does to inquiry</h3>
            <p>
              The default internet stack collapses search, browsing, comparison, and saved work into one visible behavioral record. That is useful for systems that predict people. It is not always good for the person trying to think clearly.
            </p>
          </Reveal>

          <Reveal className="comparison-panel comparison-panel-muted" delay={100}>
            <h3>What Amon changes</h3>
            <p>
              Amon routes requests through its own privacy layer, then handles them locally, cleanly, or through a protected session. The goal is not perfect invisibility. The goal is to stop one system from seeing the whole path from question to page to saved work.
            </p>
          </Reveal>
        </div>
      </section>

      <section className="page-section">
        <div className="frame comparison-grid comparison-grid-equal">
          <Reveal className="comparison-panel comparison-panel-muted">
            <h3>For normal decisions</h3>
            <p>
              Amon is not just for edge cases. It is for moving, jobs, purchases, personal research, and the everyday questions that become decisions. These moments are ordinary. They are also highly revealing.
            </p>
          </Reveal>

          <Reveal className="comparison-panel" delay={100}>
            <h3>What Amon is for</h3>
            <p>
              Amon gives people a place to search, browse, compare, and decide with stronger boundaries: requests move through different privacy paths, and what you choose to keep stays with you locally.
            </p>
          </Reveal>
        </div>
      </section>

      <section className="page-section page-section-cta">
        <div className="frame">
          <Reveal className="cta-panel">
            <div>
              <span className="eyebrow">Next</span>
              <h2>See how requests are handled.</h2>
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