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
      <Seo description="Amon is a place to search, browse, and think through meaningful decisions online without giving one system a full view of the whole inquiry." />

      <section className="hero hero-home">
        <div className="frame hero-grid">
          <Reveal className="hero-copy">
            <span className="eyebrow">Private by default. Deeper when needed.</span>
            <h1>A place to think through things online.</h1>
            <p className="hero-lede">Amon changes how requests are handled so no single system sees everything you search, open, and keep.</p>
            <p className="hero-support">For normal decisions: moving, jobs, purchases, personal research, and figuring out what comes next.</p>
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
            <span className="eyebrow">What changes</span>
            <h2>The request path changes.</h2>
            <p>Search, page retrieval, live browsing, and saved work do not all have to go through the same visible stack.</p>
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
            <h2>Different tasks, different paths.</h2>
            <p>Amon is not one private browser mode. It decides how a search, page, live-site interaction, or saved result should be handled.</p>
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
