import { PageHero } from "../components/PageHero";
import { Reveal } from "../components/Reveal";
import { Seo } from "../components/Seo";
import { faqItems } from "../content/site";

export function FAQPage() {
  return (
    <>
      <Seo
        title="FAQ"
        description="Plain answers about how long Amon keeps you anonymous, when that boundary changes, what Amon protects, and what it does not claim."
      />

      <PageHero
        eyebrow="FAQ"
        title="Questions people will ask."
        lede="Plain answers about what Amon protects, how long that protection lasts, and when a task requires more exposure."
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