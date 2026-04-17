import { modeSteps } from "../content/site";

export function WorkflowGraphic({ compact = false, activeStep = null }) {
  return (
    <div className={`workflow-graphic${compact ? " is-compact" : ""}`} data-active-step={activeStep || undefined}>
      <svg
        className="workflow-wire"
        viewBox="0 0 720 500"
        role="img"
        aria-label="Amon workflow from Search and Browse to Clean View, Protected Session, and Workspace."
      >
        <defs>
          <linearGradient id={compact ? "flowStrokeCompact" : "flowStroke"} x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stopColor="#C6FF61" />
            <stop offset="100%" stopColor="#FF5E4F" />
          </linearGradient>
          {compact ? (
            <radialGradient id="flowFocusCompact" cx="50%" cy="48%" r="42%">
              <stop offset="0%" stopColor="#ffffff" stopOpacity="0.1" />
              <stop offset="72%" stopColor="#ffffff" stopOpacity="0" />
            </radialGradient>
          ) : null}
        </defs>
        {compact ? (
          <>
            <ellipse cx="356" cy="252" rx="168" ry="132" className="workflow-body-mark" fill="url(#flowFocusCompact)" />
            <circle
              cx="356"
              cy="204"
              r="38"
              className="workflow-body-mark"
              fill="rgba(255,255,255,0.035)"
              stroke="rgba(255,255,255,0.12)"
              strokeWidth="2.5"
            />
            <path
              d="M294 334C308 282 336 254 356 254C384 254 412 282 426 334"
              className="workflow-body-mark"
              fill="none"
              stroke="rgba(255,255,255,0.08)"
              strokeLinecap="round"
              strokeWidth="6"
            />
            <path
              d="M294 334C308 282 336 254 356 254C384 254 412 282 426 334"
              className="workflow-body-mark"
              fill="none"
              stroke="rgba(255,255,255,0.16)"
              strokeLinecap="round"
              strokeWidth="2"
            />
            <path
              d="M272 364C300 336 328 322 356 322C388 322 418 336 444 364"
              className="workflow-body-mark"
              fill="none"
              stroke="rgba(255,255,255,0.07)"
              strokeLinecap="round"
              strokeWidth="6"
            />
            <path
              d="M272 364C300 336 328 322 356 322C388 322 418 336 444 364"
              className="workflow-body-mark"
              fill="none"
              stroke="rgba(255,255,255,0.14)"
              strokeLinecap="round"
              strokeWidth="2"
            />
            <path
              d="M84 134C152 134 184 158 214 194C242 226 266 250 308 250"
              className="workflow-track"
              fill="none"
              stroke="rgba(255,255,255,0.08)"
              strokeLinecap="round"
              strokeWidth="6"
            />
            <path
              d="M84 134C152 134 184 158 214 194C242 226 266 250 308 250"
              className="workflow-line"
              data-segment="search"
              pathLength="1"
              fill="none"
              stroke="url(#flowStrokeCompact)"
              strokeLinecap="round"
              strokeWidth="4"
            />
            <path
              d="M308 250H344C408 250 430 134 514 134H590"
              className="workflow-track"
              fill="none"
              stroke="rgba(255,255,255,0.08)"
              strokeLinecap="round"
              strokeWidth="6"
            />
            <path
              d="M308 250H344C408 250 430 134 514 134H590"
              className="workflow-line"
              data-segment="clean"
              pathLength="1"
              fill="none"
              stroke="url(#flowStrokeCompact)"
              strokeLinecap="round"
              strokeWidth="4"
            />
            <path
              d="M590 134C614 134 628 148 628 172V342C628 384 616 404 598 404"
              className="workflow-track"
              fill="none"
              stroke="rgba(255,255,255,0.08)"
              strokeLinecap="round"
              strokeWidth="6"
            />
            <path
              d="M590 134C614 134 628 148 628 172V342C628 384 616 404 598 404"
              className="workflow-line"
              data-segment="protected"
              pathLength="1"
              fill="none"
              stroke="url(#flowStrokeCompact)"
              strokeLinecap="round"
              strokeWidth="4"
            />
            <circle
              cx="84"
              cy="134"
              r="9"
              className="workflow-node"
              data-step="search"
              fill="#090909"
              stroke="#C6FF61"
              strokeWidth="3"
            />
            <circle
              cx="308"
              cy="250"
              r="9"
              className="workflow-node"
              data-step="clean"
              fill="#090909"
              stroke="#F5F1EA"
              strokeWidth="3"
            />
            <circle
              cx="590"
              cy="134"
              r="9"
              className="workflow-node"
              data-step="protected"
              fill="#090909"
              stroke="#FF5E4F"
              strokeWidth="3"
            />
            <circle
              cx="598"
              cy="404"
              r="9"
              className="workflow-node workflow-node-final"
              data-step="workspace"
              fill="#090909"
              stroke="#FF5E4F"
              strokeWidth="3"
            />
            <circle
              cx="598"
              cy="404"
              r="17"
              className="workflow-node-aura workflow-node-aura-final"
              fill="none"
              stroke="rgba(255,94,79,0.18)"
              strokeWidth="1.2"
            />
          </>
        ) : (
          <>
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
          </>
        )}
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
