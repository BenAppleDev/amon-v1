import { useEffect, useState } from "react";

const modes = [
  {
    id: "local",
    label: "Local",
    title: "Live site through Amon",
    caption: "Open the real page in-app through the privacy route.",
    chip: "Live",
    accent: "var(--lime)"
  },
  {
    id: "clean",
    label: "Clean View",
    title: "Text extracted by Amon",
    caption: "Amon retrieves the page and returns readable content.",
    chip: "Text",
    accent: "var(--lime)"
  },
  {
    id: "protected",
    label: "Protected Session",
    title: "Remote-in through Amon",
    caption: "Use the real site from an Amon-controlled machine.",
    chip: "Remote",
    accent: "var(--red)"
  }
];

function PhoneObject() {
  return (
    <div className="object-phone" aria-hidden="true">
      <div className="object-phone-bar" />
      <div className="object-phone-search" />
      <div className="object-phone-result" />
      <div className="object-phone-result short" />
    </div>
  );
}

function AmonMachineObject() {
  return (
    <div className="object-amon-machine" aria-hidden="true">
      <div className="object-amon-mark">A</div>
      <div className="object-machine-lines">
        <span />
        <span />
        <span />
      </div>
    </div>
  );
}

function WebsiteObject() {
  return (
    <div className="object-browser-window" aria-hidden="true">
      <div className="browser-chrome">
        <span />
        <span />
        <span />
      </div>
      <div className="browser-line strong" />
      <div className="browser-line" />
      <div className="browser-line short" />
    </div>
  );
}

function CleanTextObject() {
  return (
    <div className="object-clean-view" aria-hidden="true">
      <div className="source-page-shadow" />
      <div className="clean-page-card">
        <span className="clean-kicker">Text</span>
        <div className="clean-line strong" />
        <div className="clean-line" />
        <div className="clean-line" />
        <div className="clean-line short" />
      </div>
    </div>
  );
}

function RemoteObject() {
  return (
    <div className="object-remote-session" aria-hidden="true">
      <div className="remote-server">
        <span />
        <span />
      </div>
      <div className="remote-screen">
        <div className="browser-chrome">
          <span />
          <span />
          <span />
        </div>
        <div className="remote-dot" />
        <div className="browser-line strong" />
        <div className="browser-line short" />
      </div>
    </div>
  );
}

function OutcomeObject({ mode }) {
  if (mode === "clean") {
    return <CleanTextObject />;
  }

  if (mode === "protected") {
    return <RemoteObject />;
  }

  return <WebsiteObject />;
}

export function RequestFlowDiagram({ compact = false }) {
  const [cycleIndex, setCycleIndex] = useState(1);
  const [hoverMode, setHoverMode] = useState(null);

  useEffect(() => {
    const timer = window.setInterval(() => {
      setCycleIndex((current) => (current + 1) % modes.length);
    }, 10000);

    return () => window.clearInterval(timer);
  }, []);

  const activeMode = hoverMode ?? modes[cycleIndex].id;
  const active = modes.find((mode) => mode.id === activeMode) ?? modes[1];

  return (
    <div
      className={`request-router${compact ? " is-compact" : ""}`}
      data-mode={activeMode}
      style={{ "--active-accent": active.accent }}
    >
      <div className="request-router-header">
        <span className="diagram-kicker">Request handling</span>
        <strong>Every request enters Amon first.</strong>
      </div>

      <div className="request-router-stage">
        <div className="router-object router-object-you">
          <PhoneObject />
          <span>You</span>
          <p>Search, open, save.</p>
        </div>

        <div className="router-connector" aria-hidden="true">
          <span />
        </div>

        <div className="router-core">
          <div className="router-core-object">
            <AmonMachineObject />
            <span>Amon privacy route</span>
            <p>Always on for Amon browsing.</p>
          </div>

          <div
            className="mode-switcher"
            role="listbox"
            aria-label="Preview request handling mode"
            onMouseLeave={() => setHoverMode(null)}
          >
            {modes.map((mode) => (
              <div
                key={mode.id}
                role="option"
                tabIndex={0}
                aria-selected={activeMode === mode.id}
                className={`mode-switcher-option${activeMode === mode.id ? " is-active" : ""}`}
                style={{ "--mode-accent": mode.accent }}
                onMouseEnter={() => setHoverMode(mode.id)}
                onFocus={() => setHoverMode(mode.id)}
                onBlur={() => setHoverMode(null)}
              >
                {mode.chip}
              </div>
            ))}
          </div>
        </div>

        <div className="router-connector" aria-hidden="true">
          <span />
        </div>

        <div className="router-object router-object-outcome">
          <OutcomeObject mode={activeMode} />
          <span>{active.label}</span>
          <p>{active.caption}</p>
        </div>
      </div>

      <div className="workspace-route">
        <div className="workspace-route-line" aria-hidden="true" />
        <div className="router-workspace">
          <div className="workspace-files" aria-hidden="true">
            <span />
            <span />
            <span />
          </div>
          <div>
            <span>Workspace</span>
            <p>Saved locally. Encrypted. Company-unreadable.</p>
          </div>
        </div>
      </div>

      <div className="request-router-footer">
        <strong>{active.title}</strong>
        <span>No single system sees everything you search, open, and keep.</span>
      </div>
    </div>
  );
}