import { Link } from "react-router-dom";
import { HeroField } from "../components/HeroField";
import { ModeRail } from "../components/ModeRail";
import { Reveal } from "../components/Reveal";
import { Seo } from "../components/Seo";
import {
  everydayDecisions,
  homeBelief,
  modeSteps,
  shiftNowLines,
  shiftThenLines,
  spaceLines
} from "../content/site";

export function HomePage() {
  return (
    <>
      <Seo description="Amon is a place to think through things online — without someone looking over your shoulder." />

      <section className="hero hero-home">
        <div className="frame hero-grid">
          <Reveal className="hero-copy">
            <span className="eyebrow">Private by default. Deeper when needed.</span>
            <h1>A place to think through things online.</h1>
            <p className="hero-lede">Without someone looking over your shoulder.</p>
            <div className="button-row">
              <Link className="button" to="/contact">
                Request access
              </Link>
              <Link className="button button-secondary" to="/product">
                Read how it works
              </Link>
            </div>
          </Reveal>

          <Reveal className="hero-stage" delay={120}>
            <HeroField />
          </Reveal>
        </div>
      </section>

      <section className="page-section shift-section">
        <div className="frame shift-grid">
          <Reveal className="shift-column">
            <span className="shift-label">Once</span>
            {shiftThenLines.map((line) => (
              <p key={line} className="shift-line">
                {line}
              </p>
            ))}
          </Reveal>

          <Reveal className="shift-column shift-column-now" delay={120}>
            <span className="shift-label">Now</span>
            {shiftNowLines.map((line) => (
              <p key={line} className="shift-line">
                {line}
              </p>
            ))}
            <p className="shift-note">
              Online inquiry no longer just finds answers. It builds a profile.
            </p>
          </Reveal>
        </div>
      </section>

      <section className="page-section everyday-section">
        <div className="frame everyday-grid">
          <Reveal className="section-heading">
            <span className="eyebrow">Ordinary life</span>
            <h2>These are not edge cases.</h2>
            <p>Moving. Jobs. Purchases. Personal questions. Next steps.</p>
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
            <span className="eyebrow">Why Amon exists</span>
            <p className="belief-quote">{homeBelief}</p>
            <p className="belief-support">
              Not just for privacy experts. For ordinary people making real decisions.
            </p>
          </Reveal>
        </div>
      </section>

      <section className="page-section response-section">
        <div className="frame response-grid">
          <Reveal className="section-heading">
            <span className="eyebrow">How Amon responds</span>
            <h2>It starts familiar. Then it deepens.</h2>
            <p>Amon does not replace the internet. It changes how you move through it.</p>
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
              A meaningful question should not immediately become a permanent record.
            </p>
          </Reveal>
        </div>
      </section>

      <section className="page-section page-section-cta">
        <div className="frame">
          <Reveal className="cta-panel cta-panel-home">
            <div>
              <span className="eyebrow">Request access</span>
              <h2>If that sounds right, get in touch.</h2>
            </div>
            <div className="button-row">
              <Link className="button" to="/contact">
                Join the waitlist
              </Link>
              <Link className="button button-secondary" to="/privacy">
                Read the privacy posture
              </Link>
            </div>
          </Reveal>
        </div>
      </section>
    </>
  );
}
