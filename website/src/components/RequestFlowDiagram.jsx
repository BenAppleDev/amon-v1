import { useState } from "react";

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
  const [activeMode, setActiveMode] = useState("clean");
  const active = modes.find((mode) => mode.id === activeMode) ?? modes[1];

  return (
    <div className={`request-router${compact ? " is-compact" : ""}`} data-mode={activeMode}>
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

          <div className="mode-switcher" aria-label="Choose request handling mode">
            {modes.map((mode) => (
              <button
                key={mode.id}
                type="button"
                className={`mode-switcher-button${activeMode === mode.id ? " is-active" : ""}`}
                onClick={() => setActiveMode(mode.id)}
                aria-pressed={activeMode === mode.id}
              >
                {mode.chip}
              </button>
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