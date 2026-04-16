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
            <stop offset="0%" stopColor="#C6FF61" />
            <stop offset="100%" stopColor="#FF5E4F" />
          </linearGradient>
        </defs>
        <path
          d="M76 118C172 118 176 188 290 188H366C476 188 474 116 594 116"
          fill="none"
          stroke="rgba(255,255,255,0.08)"
          strokeLinecap="round"
          strokeWidth="6"
        />
        <path
          d="M76 118C172 118 176 188 290 188H366C476 188 474 116 594 116"
          fill="none"
          stroke="url(#flowStroke)"
          strokeLinecap="round"
          strokeWidth="4"
        />
        <path
          d="M366 188C366 258 330 300 330 362C330 400 380 408 454 408H602"
          fill="none"
          stroke="rgba(255,255,255,0.08)"
          strokeLinecap="round"
          strokeWidth="6"
        />
        <path
          d="M366 188C366 258 330 300 330 362C330 400 380 408 454 408H602"
          fill="none"
          stroke="url(#flowStroke)"
          strokeLinecap="round"
          strokeWidth="4"
        />
        <circle cx="76" cy="118" r="9" fill="#090909" stroke="#C6FF61" strokeWidth="3" />
        <circle cx="366" cy="188" r="9" fill="#090909" stroke="#F5F1EA" strokeWidth="3" />
        <circle cx="594" cy="116" r="9" fill="#090909" stroke="#FF5E4F" strokeWidth="3" />
        <circle cx="602" cy="408" r="9" fill="#090909" stroke="#FF5E4F" strokeWidth="3" />
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

      <div className="workflow-caption">One workflow. Four modes.</div>
    </div>
  );
}
