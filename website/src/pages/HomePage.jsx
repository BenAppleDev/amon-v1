import { Link } from "react-router-dom";
import { HeroField } from "../components/HeroField";
import { ModeRail } from "../components/ModeRail";
import { Reveal } from "../components/Reveal";
import { Seo } from "../components/Seo";
import {
  everydayDecisions,
  homeMechanics,
  homeBelief,
  modeSteps,
  spaceLines
} from "../content/site";

export function HomePage() {
  return (
    <>
      <Seo description="Amon is a search and browsing app that routes requests through different privacy paths so no single system sees everything you search, open, and keep." />

      <section className="hero hero-home">
        <div className="frame hero-grid">
          <Reveal className="hero-copy">
            <span className="eyebrow">Private by default. Deeper when needed.</span>
            <h1>Search, browse, and think through decisions, privately.</h1>
            <p className="hero-lede">Amon is a search and browsing app that routes requests through different privacy paths, so no single system sees everything you search, open, and keep.</p>
            <p className="hero-support">Built for normal decisions: moving, jobs, purchases, personal research, and figuring out what comes next.</p>
            <div className="button-row">
              <Link className="button" to="/contact">
                Request access
              </Link>
              <Link className="button button-secondary" to="/product">
                Read how requests work
              </Link>
            </div>
          </Reveal>

          <Reveal className="hero-stage" delay={120}>
            <HeroField />
          </Reveal>
        </div>
      </section>

      <section className="page-section mechanics-section">
        <div className="frame response-grid">
          <Reveal className="section-heading">
            <span className="eyebrow">How Amon works</span>
            <h2>Each kind of request can take a different path.</h2>
            <p>Search, clean retrieval, mediated browsing, and saved work are handled differently on purpose.</p>
          </Reveal>

          <div className="mechanics-list">
            {homeMechanics.map((item, index) => (
              <Reveal key={item.number} className="mechanic-item" delay={index * 70}>
                <span className="mechanic-index">{item.number}</span>
                <div className="mechanic-copy">
                  <h3>{item.title}</h3>
                  <p>{item.detail}</p>
                </div>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      <section className="page-section everyday-section">
        <div className="frame everyday-grid">
          <Reveal className="section-heading">
            <span className="eyebrow">Ordinary decisions</span>
            <h2>This is for normal life, not edge cases.</h2>
            <p>Moving, job decisions, large purchases, personal research, and figuring out what comes next all create signals about who someone is and what they may do next.</p>
          </Reveal>

          <div className="everyday-list">
            {everydayDecisions.map((item, index) => (
              <Reveal key={item} className="everyday-item" delay={index * 60}>
                {item}
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      <section className="page-section belief-section">
        <div className="frame belief-stage">
          <Reveal className="belief-copy">
            <span className="eyebrow">The belief</span>
            <p className="belief-quote">{homeBelief}</p>
            <p className="belief-support">
              Amon separates asking a question from the systems that would otherwise remember, connect, and monetize that question.
            </p>
          </Reveal>
        </div>
      </section>

      <section className="page-section response-section">
        <div className="frame response-grid">
          <Reveal className="section-heading">
            <span className="eyebrow">One workflow</span>
            <h2>One workflow, different paths.</h2>
            <p>Amon looks like a normal search and browsing app, but it does not treat every request the same.</p>
          </Reveal>

          <Reveal delay={100}>
            <ModeRail steps={modeSteps} />
          </Reveal>
        </div>
      </section>

      <section className="page-section space-section">
        <div className="frame space-stage">
          <Reveal>
            <span className="eyebrow">Space</span>
            <div className="space-lines">
              {spaceLines.map((line, index) => (
                <p key={line} className={`space-line${index === spaceLines.length - 1 ? " is-last" : ""}`}>
                  {line}
                </p>
              ))}
            </div>
            <p className="space-note">
              The point is not perfect invisibility. It is to stop one system from seeing everything.
            </p>
          </Reveal>
        </div>
      </section>

      <section className="page-section page-section-cta">
        <div className="frame">
          <Reveal className="cta-panel cta-panel-home">
            <div>
              <span className="eyebrow">Request access</span>
              <h2>If you want better boundaries for search and browsing, get in touch.</h2>
            </div>
            <div className="button-row">
              <Link className="button" to="/contact">
                Join the waitlist
              </Link>
              <Link className="button button-secondary" to="/privacy">
                Read the privacy model
              </Link>
            </div>
          </Reveal>
        </div>
      </section>
    </>
  );
}
