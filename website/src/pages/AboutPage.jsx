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
        title="Why Amon exists."
        lede="Important online questions tend to outgrow ordinary browsing. Amon gives that shift a calmer shape."
      />

      <section className="page-section">
        <div className="frame comparison-grid">
          <Reveal className="comparison-panel">
            <h3>The product idea</h3>
            <p>
              Some questions move from quick searching into focused reading, deeper tasks, and
              saved work. Amon gives that progression a clearer structure.
            </p>
          </Reveal>

          <Reveal className="comparison-panel comparison-panel-muted" delay={100}>
            <h3>The public surface</h3>
            <p>The public site explains the product. Internal surfaces stay separate.</p>
          </Reveal>
        </div>
      </section>

      <section className="page-section page-section-cta">
        <div className="frame">
          <Reveal className="cta-panel">
            <div>
              <span className="eyebrow">Next</span>
              <h2>See the workflow.</h2>
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
