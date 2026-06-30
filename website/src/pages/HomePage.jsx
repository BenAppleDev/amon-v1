import { Link } from "react-router-dom";
import { ModeComparisonDiagram } from "../components/ModeComparisonDiagram";
import { RequestFlowDiagram } from "../components/RequestFlowDiagram";
import { Reveal } from "../components/Reveal";
import { Seo } from "../components/Seo";
import {
  homeHowItWorks,
  ordinaryUseCases,
  privacyModeCards,
  trustPrinciples
} from "../content/site";

export function HomePage() {
  return (
    <>
      <Seo
        description="Amon is a private entry point to the web for search, browsing, and research. It keeps your questions from becoming a profile."
      />

      <section className="hero hero-home">
        <div className="frame hero-grid hero-grid-home">
          <Reveal className="hero-copy hero-copy-home">
            <span className="eyebrow">Inquiry before identity.</span>
            <h1>A private entry point to the web.</h1>
            <p className="hero-lede hero-lede-home">
              Amon lets you search, browse, compare, and save research without turning every
              question into a lasting profile.
            </p>
            <p className="hero-support-line">
              Start with Amon when the question should not follow you.
            </p>

            <div className="button-row hero-action-row">
              <Link className="button" to="/contact">
                Request access
              </Link>
              <a className="button button-secondary" href="#how-it-works">
                See how it works
              </a>
            </div>
          </Reveal>

          <Reveal className="hero-graphic-shell" delay={120}>
            <RequestFlowDiagram compact />
          </Reveal>
        </div>

        <div className="frame">
          <Reveal className="thesis-band" delay={160}>
            <div>
              <span className="eyebrow">Why it matters</span>
              <h2>Amon keeps your questions from becoming a profile.</h2>
            </div>
            <p>
              The web is built to remember. Searches, clicks, pages, and saved links can become
              signals that outlive the moment. Amon gives you a private starting point for inquiry,
              so you can explore before your question is attached to who you are.
            </p>
          </Reveal>
        </div>
      </section>

      <section id="how-it-works" className="page-section page-section-tight">
        <div className="frame">
          <Reveal className="section-heading">
            <span className="eyebrow">How you use Amon</span>
            <h2>Search first. Decide later.</h2>
            <p>
              Amon is meant to feel simple: ask the question, open what matters, choose the right
              path for the page, and keep the work you want to save.
            </p>
          </Reveal>

          <div className="step-grid">
            {homeHowItWorks.map((step, index) => (
              <Reveal key={step.title} className="step-card" delay={index * 70}>
                <span className="step-index">0{index + 1}</span>
                <h3>{step.title}</h3>
                <p>{step.text}</p>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      <section className="page-section">
        <div className="frame">
          <Reveal className="section-heading">
            <span className="eyebrow">Product flow</span>
            <h2>Question in. Research out. Privacy choices in between.</h2>
            <p>
              Amon gives you one place to start, then handles each page in the way that fits the
              task.
            </p>
          </Reveal>

          <Reveal delay={120}>
            <ModeComparisonDiagram />
          </Reveal>
        </div>
      </section>

      <section className="page-section">
        <div className="frame problem-grid">
          <Reveal className="section-heading">
            <span className="eyebrow">The boundary</span>
            <h2>You should be able to explore before you are identified.</h2>
            <p>
              Most tools collapse question, identity, and intent too early. A search is rarely
              just a search. It can become an ad signal, a recommendation signal, a risk signal, or
              part of a profile that outlives the moment.
            </p>
          </Reveal>

          <Reveal className="comparison-panel comparison-panel-muted" delay={100}>
            <h3>What Amon protects</h3>
            <p>
              Amon is built for the part before a question is linked to identity, interpreted as
              intent, and turned into durable behavioral signal.
            </p>
          </Reveal>
        </div>
      </section>

      <section className="page-section">
        <div className="frame">
          <Reveal className="section-heading">
            <span className="eyebrow">Modes</span>
            <h2>One web request. Multiple privacy paths.</h2>
            <p>
              Amon handles each page based on what the task needs. Sometimes you need the real
              site. Sometimes you only need the readable content. Sometimes interaction is
              necessary, but the site should not meet your device directly.
            </p>
          </Reveal>

          <div className="mode-overview-grid">
            {privacyModeCards.map((mode, index) => (
              <Reveal
                key={mode.id}
                className={`comparison-panel${index % 2 === 1 ? " comparison-panel-muted" : ""}`}
                delay={index * 60}
              >
                <h3>{mode.name}</h3>
                <p>{mode.detail}</p>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      <section className="page-section">
        <div className="frame">
          <Reveal className="section-heading">
            <span className="eyebrow">Trust</span>
            <h2>Designed so no single layer has the whole picture.</h2>
            <p>
              Your account authorizes access. Your browsing session handles the task. Destination
              sites see the selected Amon path. Saved research stays encrypted on your device.
            </p>
          </Reveal>

          <div className="trust-principle-grid">
            {trustPrinciples.map((item, index) => (
              <Reveal
                key={item.title}
                className={`comparison-panel${index === 1 || index === 2 ? " comparison-panel-muted" : ""}`}
                delay={index * 60}
              >
                <h3>{item.title}</h3>
                <p>{item.text}</p>
              </Reveal>
            ))}
          </div>

          <Reveal className="trust-link-row" delay={120}>
            <Link className="button button-secondary" to="/privacy">
              Read privacy
            </Link>
          </Reveal>
        </div>
      </section>

      <section className="page-section">
        <div className="frame">
          <Reveal className="section-heading">
            <span className="eyebrow">Use cases</span>
            <h2>Ordinary questions can still be revealing.</h2>
            <p>
              Moving, work, purchases, research, and life decisions are ordinary. They are also
              revealing. Amon is built for the searches and sessions you want to keep separate from
              a lasting profile.
            </p>
          </Reveal>

          <div className="use-case-grid">
            {ordinaryUseCases.map((item, index) => (
              <Reveal
                key={item}
                className={`comparison-panel${index % 2 === 1 ? " comparison-panel-muted" : ""}`}
                delay={index * 50}
              >
                <h3>{item}</h3>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      <section className="page-section page-section-cta">
        <div className="frame">
          <Reveal className="cta-panel cta-panel-home">
            <div>
              <span className="eyebrow">Request access</span>
              <h2>Start where the question stays yours.</h2>
            </div>
            <div className="button-row">
              <Link className="button" to="/contact">
                Request access
              </Link>
            </div>
          </Reveal>
        </div>
      </section>
    </>
  );
}
