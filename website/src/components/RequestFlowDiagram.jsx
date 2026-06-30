import { useState } from "react";
import {
  CleanViewIcon,
  OpenSiteIcon,
  ProtectedSessionIcon,
  SearchIcon,
  WorkspaceIcon
} from "./ProductIcons";

const paths = [
  {
    id: "open-site",
    name: "Open Site",
    detail: "Use the real page through Amon when normal browsing is enough.",
    summary: "Real page view through Amon.",
    Icon: OpenSiteIcon
  },
  {
    id: "clean-view",
    name: "Clean View",
    detail: "Read the page as extracted text when you only need the information.",
    summary: "Readable content without the full site experience.",
    Icon: CleanViewIcon
  },
  {
    id: "protected-session",
    name: "Protected Session",
    detail: "Use a protected Amon-controlled session when a site needs interaction.",
    summary: "Interactive browsing with stronger separation.",
    Icon: ProtectedSessionIcon
  }
];

const results = [
  "Neighborhood comparison guide",
  "Rent trends and commute notes",
  "School options and local services"
];

export function RequestFlowDiagram({ compact = false }) {
  const [activePath, setActivePath] = useState("clean-view");
  const active = paths.find((path) => path.id === activePath) ?? paths[1];

  return (
    <div
      className={`entry-flow${compact ? " is-compact" : ""}`}
      role="img"
      aria-label="Amon flow from a question, through Amon search results, into a chosen privacy path, and finally into a private workspace."
    >
      <div className="entry-flow-rail" aria-hidden="true">
        <span>Question</span>
        <span>Amon</span>
        <span>Search Results</span>
        <span>Choose Path</span>
        <span>Save Privately</span>
      </div>

      <div className="entry-flow-card entry-flow-input">
        <div className="entry-flow-card-top">
          <span className="entry-flow-step-label">Ask through Amon</span>
          <SearchIcon />
        </div>
        <strong>research a move without building a profile</strong>
        <p>Start the question in Amon instead of handing it directly to the open web.</p>
      </div>

      <div className="entry-flow-link" aria-hidden="true" />

      <div className="entry-flow-card entry-flow-results">
        <div className="entry-flow-card-top">
          <span className="entry-flow-step-label">Search Results</span>
          <span className="entry-flow-mini-label">Open through Amon</span>
        </div>
        <div className="entry-flow-result-list">
          {results.map((result, index) => (
            <div
              key={result}
              className={`entry-flow-result${index === 1 ? " is-selected" : ""}`}
            >
              <strong>{result}</strong>
              <span>{index === 1 ? "Selected result" : "Result"}</span>
            </div>
          ))}
        </div>
      </div>

      <div className="entry-flow-link" aria-hidden="true" />

      <div className="entry-flow-choice-area">
        <div className="entry-flow-card entry-flow-choice-card">
          <div className="entry-flow-card-top">
            <span className="entry-flow-step-label">Choose Path</span>
            <span className="entry-flow-mini-label">Private where possible</span>
          </div>
          <strong>Amon starts with the private option that fits the task.</strong>
          <p>Amon tells you when a page needs more exposure than a simple read.</p>
          <div className="entry-flow-paths">
            {paths.map((path) => {
              const Icon = path.Icon;

              return (
                <button
                  key={path.id}
                  type="button"
                  className={`entry-flow-path${activePath === path.id ? " is-active" : ""}`}
                  onMouseEnter={() => setActivePath(path.id)}
                  onFocus={() => setActivePath(path.id)}
                >
                  <Icon />
                  <span>{path.name}</span>
                </button>
              );
            })}
          </div>
        </div>

        <div className="entry-flow-card entry-flow-active-path">
          <div className="entry-flow-card-top">
            <span className="entry-flow-step-label">{active.name}</span>
            <span className="entry-flow-mini-label">Selected</span>
          </div>
          <strong>{active.summary}</strong>
          <p>{active.detail}</p>
        </div>
      </div>

      <div className="entry-flow-save-link" aria-hidden="true" />

      <div className="entry-flow-card entry-flow-save">
        <div className="entry-flow-card-top">
          <span className="entry-flow-step-label">Saved privately on your device</span>
          <WorkspaceIcon />
        </div>
        <strong>Workspace</strong>
        <p>Notes, sources, comparisons, and research stay in your local encrypted workspace.</p>
      </div>
    </div>
  );
}
