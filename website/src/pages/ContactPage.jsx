import { PageHero } from "../components/PageHero";
import { Reveal } from "../components/Reveal";
import { Seo } from "../components/Seo";

export function ContactPage() {
  return (
    <>
      <Seo
        title="Contact"
        description="Request access to Amon."
      />

      <PageHero
        eyebrow="Contact / Waitlist"
        title="Request access."
        lede="A controlled invitation, kept simple."
      />

      <section className="page-section contact-section">
        <div className="frame contact-stage">
          <Reveal className="contact-invite">
            <span className="eyebrow">Write to us</span>
            <a
              className="contact-address"
              href="mailto:hello@getamon.com?subject=Request%20access%20to%20Amon"
            >
              hello@getamon.com
            </a>
            <p className="contact-note">
              Tell us a little about the kinds of decisions you work through and why Amon seems relevant.
            </p>
          </Reveal>
        </div>
      </section>
    </>
  );
}
