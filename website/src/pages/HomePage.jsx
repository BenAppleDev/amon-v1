import { Link } from "react-router-dom";
import { ModeComparisonDiagram } from "../components/ModeComparisonDiagram";
import { RequestFlowDiagram } from "../components/RequestFlowDiagram";
import { Reveal } from "../components/Reveal";
import { Seo } from "../components/Seo";
import { homeBelief, homeBoundaryCards, spaceLines } from "../content/site";

export function HomePage() {
  return (
    <>
      <Seo description="Amon keeps your questions from becoming a profile by separating inquiry from identity and starting with the least exposing path first." />

      <section className="hero hero-home hero-home-thesis">
        <div className="frame hero-grid hero-grid-with-diagram">
          <Reveal className="hero-copy hero-copy-thesis">
            <span className="eyebrow">Inquiry before identity.</span>
            <h1>Amon keeps your questions from becoming a profile.</h1>
            <p className="hero-lede">
              Separate your questions from your identity. Search, browse, compare, and go deeper through the least exposing path first — before the internet decides what your curiosity means.
            </p>
            <div className="button-row">
              <Link className="button" to="/contact">
                Request access
              </Link>
              <Link className="button button-secondary" to="/product">
                Read how Amon works
              </Link>
            </div>
          </Reveal>

          <Reveal className="hero-stage hero-stage-wide" delay={120}>
            <RequestFlowDiagram compact />
          </Reveal>
        </div>
      </section>

      <section className="page-section">
        <div className="frame">
          <Reveal className="section-heading">
            <span className="eyebrow">Before the profile</span>
            <h2>You should be able to explore before you are identified.</h2>
            <p>
              Most tools collapse question, identity, and intent too early. Amon is built for the space before that happens: the part where you are still searching, comparing, reading, and deciding.
            </p>
          </Reveal>

          <div className="policy-grid">
            {homeBoundaryCards.map((item, index) => (
              <Reveal
                key={item.title}
                className={`comparison-panel${index % 2 === 1 ? " comparison-panel-muted" : ""}`}
                delay={index * 70}
              >
                <h3>{item.title}</h3>
                <p>{item.text}</p>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      <section className="page-section response-section">
        <div className="frame">
          <Reveal className="section-heading">
            <span className="eyebrow">Proof layer</span>
            <h2>One privacy route. Three ways to handle the web.</h2>
            <p>
              Amon starts with the least exposing path and then handles the task live, cleanly as readable text, or through a protected remote session when the site requires interaction.
            </p>
          </Reveal>

          <Reveal delay={100}>
            <ModeComparisonDiagram />
          </Reveal>
        </div>
      </section>

      <section className="page-section belief-section">
        <div className="frame belief-stage">
          <Reveal className="belief-copy">
            <span className="eyebrow">The belief</span>
            <p className="belief-quote">{homeBelief}</p>
            <p className="belief-support">
              A person’s inquiry should not be automatically linked to identity, interpreted as intent, and turned into a profile before they have even finished thinking.
            </p>
          </Reveal>
        </div>
      </section>

      <section className="page-section space-section">
        <div className="frame space-stage">
          <Reveal>
            <span className="eyebrow">For normal life</span>
            <div className="space-lines">
              {spaceLines.map((line, index) => (
                <p key={line} className={`space-line${index === spaceLines.length - 1 ? " is-last" : ""}`}>
                  {line}
                </p>
              ))}
            </div>
            <p className="space-note">
              Moving, work, purchases, research, and life decisions are ordinary. They are also revealing. Amon gives them better boundaries until you choose to step forward.
            </p>
          </Reveal>
        </div>
      </section>

      <section className="page-section page-section-cta">
        <div className="frame">
          <Reveal className="cta-panel cta-panel-home">
            <div>
              <span className="eyebrow">Request access</span>
              <h2>Separate your questions from your identity.</h2>
            </div>
            <div className="button-row">
              <Link className="button" to="/contact">
                Join the waitlist
              </Link>
              <Link className="button button-secondary" to="/security">
                Read security
              </Link>
            </div>
          </Reveal>
        </div>
      </section>
    </>
  );
}