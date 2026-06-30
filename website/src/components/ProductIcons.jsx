function IconFrame({ children, title }) {
  return (
    <span className="product-icon" aria-hidden="true" title={title}>
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round">
        {children}
      </svg>
    </span>
  );
}

export function SearchIcon() {
  return (
    <IconFrame title="Search">
      <circle cx="11" cy="11" r="5.25" />
      <path d="M15.2 15.2 19 19" />
      <path d="M8.5 11h5" />
    </IconFrame>
  );
}

export function OpenSiteIcon() {
  return (
    <IconFrame title="Open site">
      <rect x="4.5" y="5.5" width="15" height="13" rx="2.5" />
      <path d="M4.5 9h15" />
      <path d="M8 13h7.5" />
      <path d="M8 16h5.25" />
    </IconFrame>
  );
}

export function CleanViewIcon() {
  return (
    <IconFrame title="Clean view">
      <rect x="5.25" y="4.5" width="13.5" height="15" rx="2.5" />
      <path d="M8.5 9h7" />
      <path d="M8.5 12.25h7" />
      <path d="M8.5 15.5h4.5" />
    </IconFrame>
  );
}

export function ProtectedSessionIcon() {
  return (
    <IconFrame title="Protected session">
      <rect x="8" y="5.5" width="11" height="12" rx="2.5" strokeDasharray="2.5 2.5" />
      <rect x="5" y="8.5" width="11" height="10" rx="2.5" />
      <path d="M8.25 12h4.75" />
      <path d="M8.25 15h3" />
    </IconFrame>
  );
}

export function WorkspaceIcon() {
  return (
    <IconFrame title="Workspace">
      <rect x="5" y="6" width="11.5" height="12.5" rx="2.5" />
      <path d="M8.25 10h5" />
      <path d="M8.25 13.25h5" />
      <path d="M18.5 12.25v4.5" />
      <path d="M16.75 12.25h3.5" />
      <path d="M17.2 11.25a1.3 1.3 0 1 1 2.6 0v1" />
    </IconFrame>
  );
}
