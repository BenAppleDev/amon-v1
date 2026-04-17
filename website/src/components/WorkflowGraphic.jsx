import { modeSteps } from "../content/site";

function CompactWorkflowGraphic({ activeStep }) {
  return (
    <div
      className="workflow-graphic workflow-graphic-descent is-compact"
      data-active-step={activeStep || undefined}
      role="img"
      aria-label="Amon progression from Search and Browse to Clean View, Protected Session, and Workspace, descending deeper when needed."
    >
      <div className="workflow-descent-axis" aria-hidden="true" />

      {modeSteps.map((step, index) => (
        <article
          key={step.id}
          className="workflow-descent-stage"
          data-step={step.id}
          style={{ "--stage-index": index }}
        >
          <div className={`workflow-descent-node${step.id === "workspace" ? " is-final" : ""}`} aria-hidden="true">
            {step.id === "workspace" ? <span className="workflow-descent-node-aura" /> : null}
          </div>

          <div className="workflow-descent-copy">
            <span>{step.number}</span>
            <strong>{step.name}</strong>
            <p>{step.caption}</p>
          </div>
        </article>
      ))}

      <div className="workflow-caption">Deeper when needed.</div>
    </div>
  );
}

export function WorkflowGraphic({ compact = false, activeStep = null }) {
  if (compact) {
    return <CompactWorkflowGraphic activeStep={activeStep} />;
  }

  return (
    <div className="workflow-graphic" data-active-step={activeStep || undefined}>
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
          d="M76 118C172 118 176 188 290 188H366"
          className="workflow-track"
          fill="none"
          stroke="rgba(255,255,255,0.08)"
          strokeLinecap="round"
          strokeWidth="6"
        />
        <path
          d="M76 118C172 118 176 188 290 188H366"
          className="workflow-line"
          data-segment="search"
          pathLength="1"
          fill="none"
          stroke="url(#flowStroke)"
          strokeLinecap="round"
          strokeWidth="4"
        />
        <path
          d="M366 188C476 188 474 116 594 116"
          className="workflow-track"
          fill="none"
          stroke="rgba(255,255,255,0.08)"
          strokeLinecap="round"
          strokeWidth="6"
        />
        <path
          d="M366 188C476 188 474 116 594 116"
          className="workflow-line"
          data-segment="clean"
          pathLength="1"
          fill="none"
          stroke="url(#flowStroke)"
          strokeLinecap="round"
          strokeWidth="4"
        />
        <path
          d="M366 188C366 258 330 300 330 362C330 400 380 408 454 408H602"
          className="workflow-track"
          fill="none"
          stroke="rgba(255,255,255,0.08)"
          strokeLinecap="round"
          strokeWidth="6"
        />
        <path
          d="M366 188C366 258 330 300 330 362C330 400 380 408 454 408H602"
          className="workflow-line"
          data-segment="protected"
          pathLength="1"
          fill="none"
          stroke="url(#flowStroke)"
          strokeLinecap="round"
          strokeWidth="4"
        />
        <circle cx="76" cy="118" r="9" className="workflow-node" data-step="search" fill="#090909" stroke="#C6FF61" strokeWidth="3" />
        <circle cx="366" cy="188" r="9" className="workflow-node" data-step="clean" fill="#090909" stroke="#F5F1EA" strokeWidth="3" />
        <circle
          cx="594"
          cy="116"
          r="9"
          className="workflow-node"
          data-step="protected"
          fill="#090909"
          stroke="#FF5E4F"
          strokeWidth="3"
        />
        <circle
          cx="602"
          cy="408"
          r="9"
          className="workflow-node workflow-node-final"
          data-step="workspace"
          fill="#090909"
          stroke="#FF5E4F"
          strokeWidth="3"
        />
        <circle
          cx="602"
          cy="408"
          r="17"
          className="workflow-node-aura workflow-node-aura-final"
          fill="none"
          stroke="rgba(255,94,79,0.18)"
          strokeWidth="1.2"
        />
      </svg>

      <article className="workflow-plane workflow-plane-search" data-step="search">
        <span>{modeSteps[0].number}</span>
        <strong>{modeSteps[0].name}</strong>
        <p>{modeSteps[0].line}</p>
      </article>

      <article className="workflow-plane workflow-plane-clean" data-step="clean">
        <span>{modeSteps[1].number}</span>
        <strong>{modeSteps[1].name}</strong>
        <p>{modeSteps[1].line}</p>
      </article>

      <article className="workflow-plane workflow-plane-protected" data-step="protected">
        <span>{modeSteps[2].number}</span>
        <strong>{modeSteps[2].name}</strong>
        <p>{modeSteps[2].line}</p>
      </article>

      <article className="workflow-plane workflow-plane-workspace" data-step="workspace">
        <span>{modeSteps[3].number}</span>
        <strong>{modeSteps[3].name}</strong>
        <p>{modeSteps[3].line}</p>
      </article>

      <div className="workflow-caption">One workflow. Four modes.</div>
    </div>
  );
}
