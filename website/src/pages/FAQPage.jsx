import { PageHero } from "../components/PageHero";
import { Reveal } from "../components/Reveal";
import { Seo } from "../components/Seo";
import { faqItems } from "../content/site";

export function FAQPage() {
  return (
    <>
      <Seo
        title="FAQ"
        description="Short answers about Amon's scope, privacy posture, and workflow."
      />

      <PageHero
        eyebrow="FAQ"
        title="Short answers."
        lede="A few quick clarifications."
      />

      <section className="page-section">
        <div className="frame faq-list">
          {faqItems.map((item, index) => (
            <Reveal key={item.question} delay={index * 40}>
              <details className="faq-item">
                <summary>{item.question}</summary>
                <p>{item.answer}</p>
              </details>
            </Reveal>
          ))}
        </div>
      </section>
    </>
  );
}
