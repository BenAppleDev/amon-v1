import { Reveal } from "./Reveal";

export function PageHero({ eyebrow, title, lede, aside }) {
  return (
    <section className="page-hero">
      <div className="frame page-hero-grid">
        <Reveal className="page-hero-copy">
          <span className="eyebrow">{eyebrow}</span>
          <h1 className="page-title">{title}</h1>
          <p className="page-lede">{lede}</p>
        </Reveal>
        {aside ? (
          <Reveal className="page-hero-note" delay={120}>
            {aside}
          </Reveal>
        ) : null}
      </div>
    </section>
  );
}
