import { useState } from "react";
import {
  CleanViewIcon,
  OpenSiteIcon,
  ProtectedSessionIcon,
  SearchIcon,
  WorkspaceIcon
} from "./ProductIcons";

const destinations = [
  {
    id: "open-site",
    title: "Open Site",
    body: "Use the real page through Amon when normal browsing is enough.",
    note: "Direct page view through Amon.",
    Icon: OpenSiteIcon
  },
  {
    id: "clean-view",
    title: "Clean View",
    body: "Amon retrieves the page, extracts readable content, and presents the information without a full live site visit from your device.",
    note: "Readable content first.",
    Icon: CleanViewIcon
  },
  {
    id: "protected-session",
    title: "Protected Session",
    body: "For sites that need interaction, Amon can run the session in a protected environment rather than exposing your device directly.",
    note: "Interactive pages with stronger separation.",
    Icon: ProtectedSessionIcon
  },
  {
    id: "workspace",
    title: "Saved privately on your device",
    body: "Notes, sources, comparisons, and research stay in your local encrypted workspace.",
    note: "Durable work belongs to you.",
    Icon: WorkspaceIcon
  }
];

export function ModeComparisonDiagram() {
  const [activeId, setActiveId] = useState("clean-view");
  const active = destinations.find((item) => item.id === activeId) ?? destinations[1];

  return (
    <div
      className="product-system-graphic"
      role="img"
      aria-label="Amon input surface routing a request through Open Site, Clean View, Protected Session, or a private workspace."
    >
      <div className="product-system-entry">
        <div className="product-system-entry-top">
          <span className="diagram-kicker">Amon</span>
          <SearchIcon />
        </div>
        <strong>Search, browse, compare, and save from one private starting point.</strong>
        <div className="product-system-query">compare options privately</div>
      </div>

      <div className="product-system-route">
        <span className="diagram-kicker">Routing layer</span>
        <strong>Choose the private path that fits the task.</strong>
        <p>
          Sometimes you need the real site. Sometimes you only need readable content.
          Sometimes a site needs a stronger separation layer.
        </p>
      </div>

      <div className="product-system-grid">
        {destinations.map((destination) => {
          const Icon = destination.Icon;

          return (
            <button
              key={destination.id}
              type="button"
              className={`product-system-card${activeId === destination.id ? " is-active" : ""}`}
              onMouseEnter={() => setActiveId(destination.id)}
              onFocus={() => setActiveId(destination.id)}
            >
              <div className="product-system-card-top">
                <Icon />
                <strong>{destination.title}</strong>
              </div>
              <p>{destination.body}</p>
              <span>{destination.note}</span>
            </button>
          );
        })}
      </div>

      <div className="product-system-caption">
        <strong>{active.title}</strong>
        <span>{active.body}</span>
      </div>
    </div>
  );
}
