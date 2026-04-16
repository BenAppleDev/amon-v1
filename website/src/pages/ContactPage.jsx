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
        lede="The public front door is intentionally simple."
      />

      <section className="page-section">
        <div className="frame comparison-grid">
          <Reveal className="comparison-panel comparison-panel-strong contact-panel">
            <span className="eyebrow">Primary path</span>
            <h2 className="panel-title">Email the team</h2>
            <p>For now, the cleanest public CTA is direct email.</p>
            <a
              className="contact-address"
              href="mailto:hello@getamon.com?subject=Request%20access%20to%20Amon"
            >
              hello@getamon.com
            </a>
            <p className="contact-note">A short note about your workflow is enough.</p>
          </Reveal>

          <Reveal className="comparison-panel" delay={100}>
            <span className="eyebrow">Helpful in your note</span>
            <h3>Keep it brief</h3>
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
