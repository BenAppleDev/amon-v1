import { PageHero } from "../components/PageHero";
import { Reveal } from "../components/Reveal";
import { Seo } from "../components/Seo";
import { contactPrompts } from "../content/site";

export function ContactPage() {
  return (
    <>
      <Seo
        title="Contact"
        description="Request access to Amon or reach the team."
      />

      <PageHero
        eyebrow="Contact / Waitlist"
        title="Request access."
        lede="The public-site front door is intentionally simple: reach the team directly without adding a half-built public signup flow."
      />

      <section className="page-section">
        <div className="frame comparison-grid">
          <Reveal className="comparison-panel comparison-panel-strong">
            <span className="eyebrow">Primary path</span>
            <h2 className="panel-title">Email the team</h2>
            <p>
              For now, the production-safe CTA is direct email. It is simple, honest, and easy to
              deploy.
            </p>
            <div className="button-row">
              <a
                className="button"
                href="mailto:hello@getamon.com?subject=Request%20access%20to%20Amon"
              >
                hello@getamon.com
              </a>
              <a
                className="button button-secondary"
                href="mailto:hello@getamon.com?subject=Amon%20website%20question"
              >
                General inquiry
              </a>
            </div>
          </Reveal>

          <Reveal className="comparison-panel" delay={100}>
            <span className="eyebrow">Helpful note</span>
            <h3>What to include</h3>
            <ul className="bullet-list">
              {contactPrompts.map((prompt) => (
                <li key={prompt}>{prompt}</li>
              ))}
            </ul>
          </Reveal>
        </div>
      </section>
    </>
  );
}
