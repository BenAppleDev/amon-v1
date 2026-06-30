import { Link } from "react-router-dom";
import { ModeComparisonDiagram } from "../components/ModeComparisonDiagram";
import { PageHero } from "../components/PageHero";
import { Reveal } from "../components/Reveal";
import { Seo } from "../components/Seo";
import { productSections } from "../content/site";

export function ProductPage() {
  return (
    <>
      <Seo
        title="Product"
        description="Amon is a private starting point for web inquiry that routes each page through Open Site, Clean View, Protected Session, or a private workspace."
      />

      <PageHero
        eyebrow="Product"
        title="One web request. Multiple privacy paths."
        lede="When you open something in Amon, the app chooses the least revealing way to handle it: open the site, extract the readable text, or run the site in a protected session."
        aside={
          <>
            <span className="note-kicker">How to read this</span>
            <p>
              Amon is built around practical privacy choices, not a single all-or-nothing mode.
            </p>
          </>
        }
      />

      <section className="page-section">
        <div className="frame comparison-grid comparison-grid-equal">
          <Reveal className="comparison-panel">
            <h3>Search and browse</h3>
            <p>
              Amon is a private starting point for web inquiry. You begin in Amon, search the web
              from there, open what matters, and decide how much of the live site experience the
              task actually needs.
            </p>
          </Reveal>

          <Reveal className="comparison-panel comparison-panel-muted" delay={80}>
            <h3>Clear when privacy limits change</h3>
            <p>
              If a page can stay simple, Amon keeps it simple. If a site needs more interaction or
              identity, Amon moves to a more capable path and makes that change understandable.
            </p>
          </Reveal>
        </div>
      </section>

      <section className="page-section">
        <div className="frame">
          <Reveal className="section-heading">
            <span className="eyebrow">System view</span>
            <h2>One input surface. Four outcomes.</h2>
            <p>
              The product is designed as a routing system, not just a browser window. The question
              starts in Amon, then each page goes through the path that fits the job.
            </p>
          </Reveal>

          <Reveal delay={120}>
            <ModeComparisonDiagram />
          </Reveal>
        </div>
      </section>

      <section className="page-section">
        <div className="frame">
          <Reveal className="section-heading">
            <span className="eyebrow">Modes</span>
            <h2>Plain-language handling for real web tasks.</h2>
            <p>
              The product modes are meant to be understandable. They describe what you are doing,
              what Amon is doing, and why the path changes.
            </p>
          </Reveal>

          <div className="product-section-grid">
            {productSections.map((section, index) => (
              <Reveal
                key={section.id}
                className={`comparison-panel product-section-card${index % 2 === 1 ? " comparison-panel-muted" : ""}`}
                delay={index * 60}
              >
                <h3>{section.name}</h3>
                <p>{section.description}</p>
                <p className="product-section-detail">{section.detail}</p>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      <section className="page-section">
        <div className="frame comparison-grid comparison-grid-equal">
          <Reveal className="comparison-panel">
            <h3>Private where possible. More capable when needed.</h3>
            <p>
              Amon does not assume every page should be treated the same way. It tries the private
              path that fits the task first, then steps up only when the page actually needs more.
            </p>
          </Reveal>

          <Reveal className="comparison-panel comparison-panel-muted" delay={100}>
            <h3>Durable research belongs to the user</h3>
            <p>
              Search and browsing can be transient. The work you choose to keep should live in your
              local encrypted workspace, not as readable service-side memory.
            </p>
          </Reveal>
        </div>
      </section>

      <section className="page-section page-section-cta">
        <div className="frame">
          <Reveal className="cta-panel">
            <div>
              <span className="eyebrow">Next</span>
              <h2>See what each layer can see.</h2>
            </div>
            <div className="button-row">
              <Link className="button" to="/privacy">
                Read privacy
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
