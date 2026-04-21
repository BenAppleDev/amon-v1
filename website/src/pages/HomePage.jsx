import { Link } from "react-router-dom";
import { ModeComparisonDiagram } from "../components/ModeComparisonDiagram";
import { RequestFlowDiagram } from "../components/RequestFlowDiagram";
import { Reveal } from "../components/Reveal";
import { Seo } from "../components/Seo";
import { homeBelief, spaceLines } from "../content/site";

export function HomePage() {
  return (
    <>
      <Seo description="Amon routes every request through its own privacy layer, then lets you browse live, extract text, remote into protected sessions, or save work locally." />

      <section className="hero hero-home hero-home-thesis">
        <div className="frame hero-grid hero-grid-with-diagram">
          <Reveal className="hero-copy hero-copy-thesis">
            <span className="eyebrow">Private by default. Deeper when needed.</span>
            <h1>Search, browse, and think through decisions — privately.</h1>
            <p className="hero-lede">
              Amon routes every request through its own privacy layer. From there, you can browse live, extract readable text, remote into protected sessions, or save work locally.
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

      <section className="page-section response-section">
        <div className="frame">
          <Reveal className="section-heading">
            <span className="eyebrow">How Amon works</span>
            <h2>One privacy route. Three ways to handle the web.</h2>
            <p>
              Amon does not treat every page the same. Use the live site, extract the readable text, or remote into the site from an Amon-controlled machine.
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
              Amon separates the path from question to page to saved work so your activity does not collapse into one server-side profile.
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
              These are ordinary questions. They are also highly revealing. Amon gives them better boundaries.
            </p>
          </Reveal>
        </div>
      </section>

      <section className="page-section page-section-cta">
        <div className="frame">
          <Reveal className="cta-panel cta-panel-home">
            <div>
              <span className="eyebrow">Request access</span>
              <h2>Use the web without collapsing your activity into one profile.</h2>
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