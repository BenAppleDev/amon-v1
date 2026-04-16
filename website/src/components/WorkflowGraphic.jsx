import { modeSteps } from "../content/site";

export function WorkflowGraphic({ compact = false }) {
  return (
    <div className={`workflow-graphic${compact ? " is-compact" : ""}`}>
      <svg
        className="workflow-wire"
        viewBox="0 0 720 500"
        role="img"
        aria-label="Amon workflow from Search and Browse to Clean View, Protected Session, and Workspace."
      >
        <defs>
          <linearGradient id="flowStroke" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stopColor="#206B4A" />
            <stop offset="100%" stopColor="#993F2D" />
          </linearGradient>
        </defs>
        <path
          d="M72 118C170 118 170 188 290 188H366C480 188 470 116 598 116"
          fill="none"
          stroke="url(#flowStroke)"
          strokeLinecap="round"
          strokeWidth="4"
        />
        <path
          d="M366 188C366 260 328 300 328 362C328 402 378 412 452 412H604"
          fill="none"
          stroke="url(#flowStroke)"
          strokeLinecap="round"
          strokeWidth="4"
        />
        <circle cx="72" cy="118" r="8" fill="#206B4A" />
        <circle cx="366" cy="188" r="8" fill="#206B4A" />
        <circle cx="598" cy="116" r="8" fill="#993F2D" />
        <circle cx="604" cy="412" r="8" fill="#993F2D" />
      </svg>

      <article className="workflow-plane workflow-plane-search">
        <span>{modeSteps[0].number}</span>
        <strong>{modeSteps[0].name}</strong>
        <p>{modeSteps[0].line}</p>
      </article>

      <article className="workflow-plane workflow-plane-clean">
        <span>{modeSteps[1].number}</span>
        <strong>{modeSteps[1].name}</strong>
        <p>{modeSteps[1].line}</p>
      </article>

      <article className="workflow-plane workflow-plane-protected">
        <span>{modeSteps[2].number}</span>
        <strong>{modeSteps[2].name}</strong>
        <p>{modeSteps[2].line}</p>
      </article>

      <article className="workflow-plane workflow-plane-workspace">
        <span>{modeSteps[3].number}</span>
        <strong>{modeSteps[3].name}</strong>
        <p>{modeSteps[3].line}</p>
      </article>

      <div className="workflow-caption">Not just one tool, but one workflow.</div>
    </div>
  );
}
