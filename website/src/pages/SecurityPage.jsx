import { Link } from "react-router-dom";
import { PageHero } from "../components/PageHero";
import { Reveal } from "../components/Reveal";
import { SecurityLayersGraphic } from "../components/SecurityLayersGraphic";
import { Seo } from "../components/Seo";
import {
  securityFoundations,
  securityLaunchFeatures,
  securityLayers,
  securityRetentionList,
  securityRoadmapLater,
  securityRoadmapSoon
} from "../content/site";

export function SecurityPage() {
  return (
    <>
      <Seo
        title="Security"
        description="How Amon is secured: zero-trust principles, encrypted transport, local encrypted workspaces, metadata-only operations, and minimal retained visibility."
      />

      <PageHero
        eyebrow="Security"
        title="How Amon is secured."
        lede="Amon is built to protect both the path of inquiry and the work you keep. At launch, that means secure account access, encrypted transport, isolated request handling, a local encrypted workspace, and a system designed not to retain durable server-side inquiry history."
        aside={
          <>
            <span className="note-kicker">Architecture stance</span>
            <p>Designed around zero-trust principles. Not marketed as zero-trust certified.</p>
          </>
        }
      />

      <section className="page-section">
        <div className="frame security-model-frame">
          <Reveal>
            <SecurityLayersGraphic />
          </Reveal>

          <div className="security-intro-panels">
            <Reveal className="comparison-panel">
              <h3>Security is layered.</h3>
              <p>
                Amon does not rely on one boundary. Account access, transport, request handling, saved work, and operations each have separate controls.
              </p>
            </Reveal>

            <Reveal className="comparison-panel comparison-panel-muted" delay={80}>
              <h3>Zero trust is a posture.</h3>
              <p>
                Zero trust is not a badge. It means no identity, network location, operator surface, or request path is implicitly trusted with the full picture.
              </p>
            </Reveal>
          </div>
        </div>
      </section>

      <section className="page-section">
        <div className="frame">
          <Reveal className="section-heading">
            <span className="eyebrow">Launch security</span>
            <h2>What the launch product includes.</h2>
            <p>
              Amon’s launch security model is built around secure account access, encrypted transport, isolated request handling, local encrypted ownership of saved work, and minimal retained visibility.
            </p>
          </Reveal>

          <div className="security-feature-grid">
            {securityLaunchFeatures.map((feature, index) => (
              <Reveal
                key={feature.title}
                className={`comparison-panel${index % 2 === 1 ? " comparison-panel-muted" : ""}`}
                delay={index * 60}
              >
                <h3>{feature.title}</h3>
                <p>{feature.text}</p>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      <section className="page-section">
        <div className="frame">
          <Reveal className="section-heading">
            <span className="eyebrow">Security by layer</span>
            <h2>How each part of Amon is protected.</h2>
            <p>
              Different parts of the product have different security requirements. Amon is designed so each layer has its own controls.
            </p>
          </Reveal>

          <div className="security-layer-list">
            {securityLayers.map((layer, index) => (
              <Reveal
                key={layer.title}
                className="security-layer-row"
                delay={index * 70}
              >
                <span>{layer.number}</span>
                <div>
                  <h3>{layer.title}</h3>
                  <p>{layer.text}</p>
                </div>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      <section className="page-section">
        <div className="frame comparison-grid comparison-grid-equal">
          <Reveal className="comparison-panel">
            <span className="eyebrow">Retention model</span>
            <h2>What Amon is designed not to store.</h2>
            <p>
              A core part of Amon’s security model is reducing what exists to be exposed in the first place.
            </p>
          </Reveal>

          <Reveal className="security-retention-panel comparison-panel comparison-panel-muted" delay={100}>
            <ul className="security-retention-list">
              {securityRetentionList.map((item) => (
                <li key={item}>{item}</li>
              ))}
            </ul>
            <p>
              Limited metadata is retained for account access, billing entitlement, system health, quotas, abuse prevention, and policy enforcement. That metadata is designed not to function as readable inquiry history.
            </p>
          </Reveal>
        </div>
      </section>

      <section className="page-section">
        <div className="frame">
          <Reveal className="section-heading">
            <span className="eyebrow">Foundations</span>
            <h2>The standards we build around.</h2>
            <p>
              Amon’s security model is grounded in established platform protections and industry-standard security practices.
            </p>
          </Reveal>

          <div className="security-foundation-grid">
            {securityFoundations.map((foundation, index) => (
              <Reveal
                key={foundation.title}
                className={`security-foundation-card${foundation.emphasis ? " is-emphasis" : ""}`}
                delay={index * 45}
              >
                <span>{foundation.label}</span>
                <h3>{foundation.title}</h3>
                <p>{foundation.text}</p>
              </Reveal>
            ))}
          </div>
        </div>
      </section>

      <section className="page-section">
        <div className="frame comparison-grid comparison-grid-equal">
          <Reveal className="comparison-panel">
            <span className="eyebrow">Architecture stance</span>
            <h2>Designed around zero-trust principles.</h2>
            <p>
              Amon’s launch architecture is aligned with core zero-trust ideas: explicit access decisions, separated identities, encrypted transport, least-privilege handling, local encrypted workspaces, and minimal retained visibility.
            </p>
          </Reveal>

          <Reveal className="comparison-panel comparison-panel-muted" delay={100}>
            <h3>Not “zero-trust certified.”</h3>
            <p>
              Zero trust is not a certification. It is an architecture and operating posture. Amon is designed around zero-trust principles, and the roadmap includes stronger documentation, review, and external assessment over time.
            </p>
          </Reveal>
        </div>
      </section>

      <section className="page-section">
        <div className="frame">
          <Reveal className="section-heading">
            <span className="eyebrow">Roadmap</span>
            <h2>What comes next.</h2>
            <p>
              Security is part of the product roadmap, not just a launch checklist.
            </p>
          </Reveal>

          <div className="security-roadmap-grid">
            <Reveal className="comparison-panel">
              <h3>Planned shortly after launch</h3>
              <ul className="bullet-list">
                {securityRoadmapSoon.map((item) => (
                  <li key={item}>{item}</li>
                ))}
              </ul>
            </Reveal>

            <Reveal className="comparison-panel comparison-panel-muted" delay={100}>
              <h3>Planned later</h3>
              <ul className="bullet-list">
                {securityRoadmapLater.map((item) => (
                  <li key={item}>{item}</li>
                ))}
              </ul>
            </Reveal>
          </div>
        </div>
      </section>

      <section className="page-section">
        <div className="frame comparison-grid comparison-grid-equal">
          <Reveal className="comparison-panel">
            <span className="eyebrow">Limits</span>
            <h2>What security does not mean.</h2>
            <p>
              Security does not mean magic anonymity everywhere. If you sign into a third-party account, that service can know who you are.
            </p>
          </Reveal>

          <Reveal className="comparison-panel comparison-panel-muted" delay={100}>
            <h3>What Amon can and cannot do</h3>
            <p>
              Amon can protect the transport path, reduce retention, isolate request handling, and secure your local saved work. It cannot make identity-based services forget your identity.
            </p>
          </Reveal>
        </div>
      </section>

      <section className="page-section page-section-cta">
        <div className="frame">
          <Reveal className="cta-panel">
            <div>
              <span className="eyebrow">Questions</span>
              <h2>Want to review the model in more detail?</h2>
            </div>
            <div className="button-row">
              <Link className="button" to="/contact">
                Contact
              </Link>
              <Link className="button button-secondary" to="/privacy">
                Read privacy
              </Link>
            </div>
          </Reveal>
        </div>
      </section>
    </>
  );
}