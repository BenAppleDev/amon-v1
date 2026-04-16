import { Link } from "react-router-dom";
import { PageHero } from "../components/PageHero";
import { Reveal } from "../components/Reveal";
import { Seo } from "../components/Seo";

export function AboutPage() {
  return (
    <>
      <Seo
        title="About"
        description="Why Amon exists and the vision behind its inquiry workflow."
      />

      <PageHero
        eyebrow="About / Vision"
        title="Built around a simple discomfort."
        lede="The public web is useful. The default workflow around it often is not. Amon exists to give inquiry a calmer shape."
      />

      <section className="page-section">
        <div className="frame comparison-grid">
          <Reveal className="comparison-panel">
            <h3>Why it exists</h3>
            <p>
              Important questions usually move from quick searching into focused reading, deeper
              tasks, and saved work. Amon gives that progression a clearer structure.
            </p>
          </Reveal>

          <Reveal className="comparison-panel comparison-panel-muted" delay={100}>
            <h3>Why the public site is separate</h3>
            <p>
              The public website should explain the product and invite interest. It should stay
              separate from internal surfaces.
            </p>
          </Reveal>
        </div>
      </section>

      <section className="page-section page-section-cta">
        <div className="frame">
          <Reveal className="cta-panel">
            <div>
              <span className="eyebrow">Next</span>
              <h2>See the workflow, then get in touch.</h2>
            </div>
            <div className="button-row">
              <Link className="button" to="/product">
                View product modes
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
