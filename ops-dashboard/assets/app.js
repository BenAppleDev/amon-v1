const STORAGE_KEY = 'amon-ops-dashboard-auth';
const DEFAULT_API_BASE =
  window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1'
    ? 'http://127.0.0.1:8000'
    : 'https://api.getamon.com';

const ROUTES = {
  overview: {
    eyebrow: 'Overview',
    title: 'Operations summary',
  },
  sessions: {
    eyebrow: 'Active Sessions',
    title: 'Live session metadata',
  },
  workers: {
    eyebrow: 'Workers',
    title: 'Fleet and assignment health',
  },
  stream: {
    eyebrow: 'Stream Health',
    title: 'Live stream and protocol telemetry',
  },
  policy: {
    eyebrow: 'Policy & Quotas',
    title: 'Decision, quota, and termination counters',
  },
  events: {
    eyebrow: 'Events Feed',
    title: 'Recent metadata-only event stream',
  },
};

const state = {
  auth: loadStoredAuth(),
  route: normalizeRoute(window.location.hash),
  data: {
    overview: null,
    sessions: null,
    workers: null,
    stream: null,
    policy: null,
    quota: null,
    terminations: null,
    events: null,
  },
  errors: {},
  isLoading: false,
  autoRefresh: true,
  intervalId: null,
  lastUpdatedAt: null,
  selectedSessionId: null,
  selectedSessionDetail: null,
  selectedSessionError: null,
};

const elements = {
  appShell: document.getElementById('app-shell'),
  authGate: document.getElementById('auth-gate'),
  authForm: document.getElementById('auth-form'),
  authError: document.getElementById('auth-error'),
  apiBaseInput: document.getElementById('api-base-input'),
  adminTokenInput: document.getElementById('admin-token-input'),
  routeEyebrow: document.getElementById('route-eyebrow'),
  routeTitle: document.getElementById('route-title'),
  connectionPill: document.getElementById('connection-pill'),
  autoRefreshLabel: document.getElementById('auto-refresh-label'),
  apiBaseLabel: document.getElementById('api-base-label'),
  lastSyncLabel: document.getElementById('last-sync-label'),
  alertStrip: document.getElementById('alert-strip'),
  viewRoot: document.getElementById('view-root'),
};

initialize();

function initialize() {
  elements.apiBaseInput.value = state.auth?.apiBase || DEFAULT_API_BASE;
  elements.adminTokenInput.value = state.auth?.token || '';
  bindEvents();
  syncNav();

  if (state.auth?.apiBase && state.auth?.token) {
    connectAndLoad({ showGateOnFailure: true });
  } else {
    updateAuthGate(true);
  }
}

function bindEvents() {
  window.addEventListener('hashchange', () => {
    state.route = normalizeRoute(window.location.hash);
    syncNav();
    render();
  });

  elements.authForm.addEventListener('submit', async (event) => {
    event.preventDefault();
    const formData = new FormData(elements.authForm);
    const apiBase = String(formData.get('apiBase') || '').trim();
    const token = String(formData.get('token') || '').trim();

    if (!apiBase || !token) {
      showAuthError('Enter both the API base URL and the internal admin token.');
      return;
    }

    state.auth = { apiBase: stripTrailingSlash(apiBase), token };
    storeAuth(state.auth);
    await connectAndLoad({ showGateOnFailure: true });
  });

  document.body.addEventListener('click', async (event) => {
    const target = event.target.closest('[data-action]');
    if (!target) {
      return;
    }

    const action = target.dataset.action;
    if (action === 'refresh') {
      await loadDashboardData();
      return;
    }
    if (action === 'sign-out') {
      signOut();
      return;
    }
    if (action === 'toggle-auto-refresh') {
      state.autoRefresh = !state.autoRefresh;
      syncAutoRefresh();
      render();
      return;
    }
    if (action === 'select-session') {
      const sessionId = target.dataset.sessionId;
      if (!sessionId) {
        return;
      }
      state.selectedSessionId = sessionId;
      await loadSessionDetail(sessionId);
      render();
      return;
    }
    if (action === 'clear-session-selection') {
      state.selectedSessionId = null;
      state.selectedSessionDetail = null;
      state.selectedSessionError = null;
      render();
    }
  });
}

async function connectAndLoad({ showGateOnFailure }) {
  if (!state.auth?.apiBase || !state.auth?.token) {
    updateAuthGate(true);
    return;
  }

  showAuthError('');
  elements.connectionPill.textContent = 'Connecting';
  elements.connectionPill.className = 'status-pill';

  try {
    await apiRequest('/internal/protected-sessions/overview');
    updateAuthGate(false);
    syncAutoRefresh();
    await loadDashboardData();
  } catch (error) {
    elements.connectionPill.textContent = 'Connection failed';
    if (showGateOnFailure) {
      updateAuthGate(true);
      showAuthError(humanizeError(error));
    }
  }
}

async function loadDashboardData() {
  if (!state.auth) {
    return;
  }

  state.isLoading = true;
  render();

  const endpoints = {
    overview: '/internal/protected-sessions/overview',
    sessions: '/internal/protected-sessions/sessions/active',
    workers: '/internal/protected-sessions/workers',
    stream: '/internal/protected-sessions/counters/stream',
    policy: '/internal/protected-sessions/counters/policy',
    quota: '/internal/protected-sessions/counters/quota',
    terminations: '/internal/protected-sessions/counters/terminations',
    events: '/internal/protected-sessions/events?limit=60',
  };

  const endpointEntries = Object.entries(endpoints);
  const requests = endpointEntries.map(async ([key, path]) => {
    const data = await apiRequest(path);
    return [key, data];
  });

  const results = await Promise.allSettled(requests);
  const nextErrors = {};

  results.forEach((result, index) => {
    if (result.status === 'fulfilled') {
      const [key, data] = result.value;
      state.data[key] = data;
    } else {
      const [key] = endpointEntries[index];
      nextErrors[key] = humanizeError(result.reason);
    }
  });

  state.errors = nextErrors;
  state.lastUpdatedAt = new Date();
  state.isLoading = false;

  if (state.selectedSessionId) {
    await loadSessionDetail(state.selectedSessionId, { quiet: true });
  }

  render();
}

async function loadSessionDetail(sessionId, { quiet = false } = {}) {
  if (!state.auth || !sessionId) {
    return;
  }

  state.selectedSessionError = null;
  if (!quiet) {
    render();
  }

  try {
    state.selectedSessionDetail = await apiRequest(`/internal/protected-sessions/sessions/${sessionId}`);
  } catch (error) {
    state.selectedSessionDetail = null;
    state.selectedSessionError = humanizeError(error);
  }
}

function render() {
  const routeConfig = ROUTES[state.route];
  elements.routeEyebrow.textContent = routeConfig.eyebrow;
  elements.routeTitle.textContent = routeConfig.title;
  elements.autoRefreshLabel.textContent = state.autoRefresh ? 'On' : 'Off';
  elements.apiBaseLabel.textContent = state.auth?.apiBase || 'Not configured';
  elements.lastSyncLabel.textContent = state.lastUpdatedAt ? formatTimestamp(state.lastUpdatedAt) : 'Never';

  if (state.auth) {
    elements.connectionPill.textContent = state.isLoading ? 'Syncing' : 'Connected';
    elements.connectionPill.className = 'status-pill';
  } else {
    elements.connectionPill.textContent = 'Disconnected';
    elements.connectionPill.className = 'status-pill';
  }

  const failedEndpoints = Object.keys(state.errors);
  if (failedEndpoints.length) {
    elements.alertStrip.textContent = `Partial sync issue: ${failedEndpoints.join(', ')}. Rendering the most recent metadata still available.`;
    elements.alertStrip.classList.remove('hidden');
  } else {
    elements.alertStrip.classList.add('hidden');
  }

  elements.viewRoot.innerHTML = renderCurrentRoute();
  syncNav();
}

function renderCurrentRoute() {
  switch (state.route) {
    case 'sessions':
      return renderSessionsView();
    case 'workers':
      return renderWorkersView();
    case 'stream':
      return renderStreamView();
    case 'policy':
      return renderPolicyView();
    case 'events':
      return renderEventsView();
    case 'overview':
    default:
      return renderOverviewView();
  }
}

function renderOverviewView() {
  const overview = state.data.overview;
  const sessions = state.data.sessions;
  const workers = state.data.workers;
  const stream = state.data.stream;

  if (!overview || !sessions || !workers || !stream) {
    return renderLoadingState('Loading overview metadata...');
  }

  return `
    <section class="metric-grid">
      ${metricCard('Active sessions', overview.active_sessions, `${overview.total_sessions} total session records`)}
      ${metricCard('Live streams', overview.active_streams, `${overview.users_with_live_streams} users with live streams`)}
      ${metricCard('Healthy workers', overview.healthy_workers, `${overview.degraded_workers} degraded workers`)}
      ${metricCard('Quota rejections', overview.quota_rejections_total, 'Current process lifetime')}
      ${metricCard('Protocol errors', overview.protocol_errors_total, `${overview.heartbeat_timeouts_total} heartbeat timeouts`)}
      ${metricCard('Dropped events', overview.dropped_events_total, `${stream.frame_update_count} frame updates sent`)}
    </section>

    <section class="two-column">
      <article class="panel">
        <div class="panel__header">
          <div>
            <h3>Session state distribution</h3>
            <p>Live metadata by runtime state. No content or frame payloads are exposed here.</p>
          </div>
        </div>
        ${renderDictionaryGrid(sessions.state_counts, 'No active session states reported.')}
      </article>

      <article class="panel">
        <div class="panel__header">
          <div>
            <h3>Worker capacity</h3>
            <p>Assignment and stream capacity across the current in-process worker fleet.</p>
          </div>
        </div>
        <div class="detail-list">
          ${detailRow('Total workers', workers.total_workers)}
          ${detailRow('Session capacity', workers.total_capacity)}
          ${detailRow('Live stream capacity', workers.total_stream_capacity)}
          ${detailRow('Assigned sessions', workers.total_assigned_sessions)}
          ${detailRow('Active streams', workers.total_active_streams)}
        </div>
      </article>
    </section>

    <section class="two-column">
      <article class="panel">
        <div class="panel__header">
          <div>
            <h3>Sessions needing attention</h3>
            <p>Top active sessions with stream churn, protocol issues, or terminal risk signals.</p>
          </div>
        </div>
        ${renderAttentionSessionList(sessions.sessions)}
      </article>

      <article class="panel">
        <div class="panel__header">
          <div>
            <h3>Recent events</h3>
            <p>Latest metadata-only events from the current event buffer.</p>
          </div>
        </div>
        ${renderEventFeed(state.data.events?.events?.slice(0, 8) || [], { compact: true })}
      </article>
    </section>
  `;
}

function renderSessionsView() {
  const sessions = state.data.sessions;
  if (!sessions) {
    return renderLoadingState('Loading active session metadata...');
  }

  const selected = state.selectedSessionDetail;

  return `
    <section class="two-column">
      <article class="panel">
        <div class="panel__header">
          <div>
            <h3>Active sessions</h3>
            <p>${sessions.active_sessions} live sessions across ${sessions.total_sessions} total tracked sessions.</p>
          </div>
          <span class="badge">${sessions.active_sessions} active</span>
        </div>
        ${renderSessionsTable(sessions.sessions)}
      </article>

      <article class="panel">
        <div class="panel__header">
          <div>
            <h3>Session detail</h3>
            <p>Per-session metadata only. No DOM, page text, form fields, or frame contents appear here.</p>
          </div>
          ${
            state.selectedSessionId
              ? '<button class="button button--ghost" type="button" data-action="clear-session-selection">Clear</button>'
              : ''
          }
        </div>
        ${renderSessionDetailPanel(selected, state.selectedSessionError)}
      </article>
    </section>
  `;
}

function renderWorkersView() {
  const workers = state.data.workers;
  if (!workers) {
    return renderLoadingState('Loading worker metadata...');
  }

  return `
    <section class="metric-grid">
      ${metricCard('Workers', workers.total_workers, `${workers.total_assigned_sessions} assigned sessions`)}
      ${metricCard('Session capacity', workers.total_capacity, 'Maximum concurrent runtime slots')}
      ${metricCard('Stream capacity', workers.total_stream_capacity, `${workers.total_active_streams} streams currently attached`)}
      ${metricCard('Active streams', workers.total_active_streams, 'Across the worker fleet')}
    </section>

    <section class="panel">
      <div class="panel__header">
        <div>
          <h3>Worker and fleet overview</h3>
          <p>Worker health, assignment counts, and stream load without content inspection.</p>
        </div>
      </div>
      ${renderWorkersTable(workers.workers)}
    </section>
  `;
}

function renderStreamView() {
  const stream = state.data.stream;
  const sessions = state.data.sessions;

  if (!stream || !sessions) {
    return renderLoadingState('Loading stream telemetry...');
  }

  return `
    <section class="metric-grid">
      ${metricCard('Active streams', stream.active_streams_total, `${stream.total_live_stream_capacity} total live-stream capacity`)}
      ${metricCard('Attaches / detaches', `${stream.attach_count} / ${stream.detach_count}`, `${stream.reconnect_attempts} reconnect attempts`)}
      ${metricCard('Resumes', stream.successful_resumes, `${stream.heartbeat_timeout_count} heartbeat timeouts`)}
      ${metricCard('Dropped events', stream.dropped_events_total, `${stream.protocol_error_count} protocol errors`)}
      ${metricCard('State / frame updates', `${stream.state_update_count} / ${stream.frame_update_count}`, formatDuration(stream.average_action_duration_ms))}
      ${metricCard('Action acks', renderAckSummary(stream.action_ack_counts), renderResultSummary(stream.action_result_counts))}
    </section>

    <section class="two-column">
      <article class="panel">
        <div class="panel__header">
          <div>
            <h3>Protocol error categories</h3>
            <p>Metadata-only stream/protocol failure groupings tracked by the control plane.</p>
          </div>
        </div>
        ${renderDictionaryGrid(stream.protocol_error_codes, 'No protocol errors recorded in this process yet.')}
      </article>

      <article class="panel">
        <div class="panel__header">
          <div>
            <h3>Sessions with stream churn</h3>
            <p>Active sessions showing dropped events, protocol errors, or heartbeat timeouts.</p>
          </div>
        </div>
        ${renderAttentionSessionList(
          sessions.sessions.filter(
            (session) =>
              session.heartbeat_timeout_count > 0 ||
              session.protocol_error_count > 0 ||
              session.dropped_events_total > 0 ||
              session.reconnect_attempts > 0
          ),
          'No active sessions are currently showing stream churn.'
        )}
      </article>
    </section>
  `;
}

function renderPolicyView() {
  const policy = state.data.policy;
  const quota = state.data.quota;
  const terminations = state.data.terminations;

  if (!policy || !quota || !terminations) {
    return renderLoadingState('Loading policy and quota counters...');
  }

  return `
    <section class="three-column">
      <article class="panel">
        <div class="panel__header">
          <div>
            <h3>Policy outcomes</h3>
            <p>ServeDecision outcomes observed by the current control plane process.</p>
          </div>
        </div>
        ${renderDictionaryGrid(policy.policy_decisions, 'No policy outcomes recorded yet.')}
      </article>

      <article class="panel">
        <div class="panel__header">
          <div>
            <h3>Quota rejections</h3>
            <p>Bounded controls for sessions, actions, and stream availability.</p>
          </div>
        </div>
        ${renderDictionaryGrid(quota.quota_rejections, 'No quota rejections recorded yet.')}
        <div class="detail-list">
          ${detailRow('Total rejections', quota.total_rejections)}
          ${detailRow('Active sessions', quota.active_sessions_total)}
          ${detailRow('Users with active sessions', quota.users_with_active_sessions)}
        </div>
      </article>

      <article class="panel">
        <div class="panel__header">
          <div>
            <h3>Termination reasons</h3>
            <p>Terminal reasons and failure categories, with no session content attached.</p>
          </div>
        </div>
        ${renderDictionaryGrid(terminations.terminal_reason_counts, 'No terminal reasons recorded yet.')}
      </article>
    </section>

    <section class="two-column">
      <article class="panel">
        <div class="panel__header">
          <div>
            <h3>Failure reason categories</h3>
            <p>Failure-side reasons for runtime or stream termination.</p>
          </div>
        </div>
        ${renderDictionaryGrid(terminations.failure_reason_counts, 'No failure reasons recorded yet.')}
      </article>

      <article class="panel">
        <div class="panel__header">
          <div>
            <h3>Recent policy events</h3>
            <p>Most recent metadata-only policy-related events from the event sink.</p>
          </div>
        </div>
        ${renderEventFeed(policy.recent_events || [], { compact: true })}
      </article>
    </section>
  `;
}

function renderEventsView() {
  const events = state.data.events;
  if (!events) {
    return renderLoadingState('Loading recent metadata-only events...');
  }

  return `
    <section class="panel">
      <div class="panel__header">
        <div>
          <h3>Recent metadata-only event feed</h3>
          <p>${events.total_events} events currently retained in the in-process buffer.</p>
        </div>
        <span class="badge">${events.events.length} shown</span>
      </div>
      ${renderEventFeed(events.events)}
    </section>
  `;
}

function renderLoadingState(message) {
  return `
    <section class="panel">
      <div class="empty-state">${message}</div>
    </section>
  `;
}

function renderSessionsTable(sessions) {
  if (!sessions.length) {
    return '<div class="empty-state">No active sessions are currently attached to the control plane.</div>';
  }

  const rows = sessions
    .map((session) => {
      const isSelected = state.selectedSessionId === session.session_id;
      return `
        <tr class="${isSelected ? 'is-selected' : ''}" data-action="select-session" data-session-id="${escapeHtml(
          session.session_id
        )}">
          <td>
            <div class="stack">
              <strong>${escapeHtml(session.domain)}</strong>
              <span class="soft code">${escapeHtml(session.session_id)}</span>
            </div>
          </td>
          <td>
            <div class="stack">
              <strong>${escapeHtml(session.user_id)}</strong>
              <span class="soft">${formatRelativeTime(session.last_activity_at)}</span>
            </div>
          </td>
          <td>${renderStatePill(session.state)}</td>
          <td>
            <div class="stack">
              <span>${escapeHtml(session.worker_id || 'unassigned')}</span>
              <span class="soft">${escapeHtml(session.worker_health || 'unknown')}</span>
            </div>
          </td>
          <td>${session.active_streams}</td>
          <td>${session.action_count}</td>
          <td>${session.protocol_error_count + session.heartbeat_timeout_count + session.dropped_events_total}</td>
        </tr>
      `;
    })
    .join('');

  return `
    <div class="table-wrap">
      <table>
        <thead>
          <tr>
            <th>Domain</th>
            <th>User</th>
            <th>State</th>
            <th>Worker</th>
            <th>Streams</th>
            <th>Actions</th>
            <th>Issues</th>
          </tr>
        </thead>
        <tbody>${rows}</tbody>
      </table>
    </div>
  `;
}

function renderSessionDetailPanel(session, error) {
  if (error) {
    return `<div class="empty-state">${escapeHtml(error)}</div>`;
  }

  if (!session) {
    return '<div class="empty-state">Choose an active session to inspect its metadata detail.</div>';
  }

  return `
    <div class="stack">
      <div class="detail-list">
        ${detailRow('Session ID', session.session_id, true)}
        ${detailRow('User', session.user_id)}
        ${detailRow('Domain', session.domain)}
        ${detailRow('State', session.state)}
        ${detailRow('Worker', session.worker_id || 'unassigned')}
        ${detailRow('Runtime kind', session.runtime_kind || 'unknown')}
        ${detailRow('Policy disposition', session.policy.disposition)}
        ${detailRow('Policy reason', session.policy.reason_code)}
        ${detailRow('Policy confidence', `${Math.round(session.policy.confidence * 100)}%`)}
        ${detailRow('Budget tier', session.quota.budget_tier || 'default')}
        ${detailRow('Action count', session.action_count)}
        ${detailRow('Frame revision', session.frame_revision || 0)}
        ${detailRow('Frames emitted', session.frames_emitted)}
        ${detailRow('Active streams', session.active_streams)}
        ${detailRow('Reconnect attempts', session.reconnect_attempts)}
        ${detailRow('Dropped events', session.dropped_events_total)}
        ${detailRow('Protocol errors', session.protocol_error_count)}
        ${detailRow('Heartbeat timeouts', session.heartbeat_timeout_count)}
        ${detailRow('Average action time', formatDuration(session.average_action_duration_ms))}
        ${detailRow('Created', formatTimestamp(session.created_at))}
        ${detailRow('Last activity', formatTimestamp(session.last_activity_at))}
      </div>
      ${
        session.termination_reason
          ? `<span class="pill pill--warning">Termination reason: ${escapeHtml(session.termination_reason)}</span>`
          : ''
      }
    </div>
  `;
}

function renderWorkersTable(workers) {
  if (!workers.length) {
    return '<div class="empty-state">No workers are currently registered.</div>';
  }

  const rows = workers
    .map(
      (worker) => `
        <tr>
          <td>
            <div class="stack">
              <strong>${escapeHtml(worker.worker_id)}</strong>
              <span class="soft">${escapeHtml(worker.worker_type)}</span>
            </div>
          </td>
          <td>${renderWorkerHealthPill(worker.health, worker.degraded_reason)}</td>
          <td>${worker.assigned_count} / ${worker.capacity}</td>
          <td>${worker.active_streams} / ${worker.stream_capacity}</td>
          <td>${worker.assignment_count} / ${worker.release_count}</td>
          <td>${worker.attach_count} / ${worker.detach_count}</td>
          <td>${worker.protocol_error_count + worker.heartbeat_timeout_count}</td>
        </tr>
      `
    )
    .join('');

  return `
    <div class="table-wrap">
      <table>
        <thead>
          <tr>
            <th>Worker</th>
            <th>Health</th>
            <th>Assignments</th>
            <th>Streams</th>
            <th>Assign / release</th>
            <th>Attach / detach</th>
            <th>Issues</th>
          </tr>
        </thead>
        <tbody>${rows}</tbody>
      </table>
    </div>
  `;
}

function renderDictionaryGrid(dictionary, emptyMessage) {
  const entries = Object.entries(dictionary || {});
  if (!entries.length) {
    return `<div class="empty-state">${emptyMessage}</div>`;
  }
  return `
    <div class="dict-grid">
      ${entries
        .sort((a, b) => b[1] - a[1])
        .map(
          ([key, value]) => `
            <div class="dict-chip">
              <span>${escapeHtml(key)}</span>
              <strong>${value}</strong>
            </div>
          `
        )
        .join('')}
    </div>
  `;
}

function renderEventFeed(events, { compact = false } = {}) {
  if (!events.length) {
    return '<div class="empty-state">No metadata-only events are currently buffered.</div>';
  }

  return `
    <div class="event-list">
      ${events
        .map(
          (event) => `
            <div class="event-row">
              <div class="event-row__meta">
                <strong>${escapeHtml(event.event_type)}</strong>
                <span class="muted">
                  ${compact ? `${escapeHtml(event.reason_code || event.state || 'metadata')}` : renderEventSummary(event)}
                </span>
              </div>
              <div class="event-row__stamp">
                <div>${formatTimestamp(event.occurred_at)}</div>
                ${event.session_id ? `<div class="code">${escapeHtml(event.session_id)}</div>` : ''}
              </div>
            </div>
          `
        )
        .join('')}
    </div>
  `;
}

function renderAttentionSessionList(sessions, emptyMessage = 'No sessions currently match the attention filters.') {
  if (!sessions.length) {
    return `<div class="empty-state">${emptyMessage}</div>`;
  }

  const topSessions = [...sessions]
    .sort(
      (a, b) =>
        b.protocol_error_count +
        b.heartbeat_timeout_count +
        b.dropped_events_total -
        (a.protocol_error_count + a.heartbeat_timeout_count + a.dropped_events_total)
    )
    .slice(0, 8);

  return `
    <div class="stat-list">
      ${topSessions
        .map(
          (session) => `
            <button class="stat-row" type="button" data-action="select-session" data-session-id="${escapeHtml(
              session.session_id
            )}">
              <span>
                <strong>${escapeHtml(session.domain)}</strong>
                <span class="soft"> · ${escapeHtml(session.state)} · ${escapeHtml(session.worker_health || 'unknown')}</span>
              </span>
              <span class="soft">
                ${session.protocol_error_count} protocol · ${session.heartbeat_timeout_count} heartbeat · ${session.dropped_events_total} dropped
              </span>
            </button>
          `
        )
        .join('')}
    </div>
  `;
}

function renderStatePill(stateValue) {
  const variant =
    stateValue === 'active'
      ? 'pill pill--success'
      : stateValue === 'failed' || stateValue === 'closed'
        ? 'pill pill--danger'
        : 'pill pill--warning';
  return `<span class="${variant}">${escapeHtml(stateValue)}</span>`;
}

function renderWorkerHealthPill(health, reason) {
  const variant = health === 'healthy' ? 'pill pill--success' : 'pill pill--warning';
  return `<span class="${variant}">${escapeHtml(health)}${reason ? ` · ${escapeHtml(reason)}` : ''}</span>`;
}

function renderAckSummary(counts) {
  if (!counts) {
    return '0';
  }
  return `${counts.accepted || 0} accepted · ${counts.rejected || 0} rejected · ${counts.failed || 0} failed`;
}

function renderResultSummary(counts) {
  if (!counts) {
    return 'No action results yet';
  }
  return `${counts.completed || 0} completed · ${counts.failed || 0} failed`;
}

function renderEventSummary(event) {
  const bits = [event.reason_code, event.state, event.disposition, event.worker_id]
    .filter(Boolean)
    .map((value) => escapeHtml(value));
  return bits.length ? bits.join(' · ') : 'metadata-only event';
}

function detailRow(label, value, code = false) {
  const renderedValue = code
    ? `<span class="code">${escapeHtml(String(value))}</span>`
    : `<strong>${escapeHtml(String(value))}</strong>`;
  return `
    <div class="detail-row">
      <span class="muted">${escapeHtml(label)}</span>
      ${renderedValue}
    </div>
  `;
}

function metricCard(label, value, meta) {
  return `
    <article class="metric-card">
      <p class="metric-card__label">${escapeHtml(String(label))}</p>
      <p class="metric-card__value">${escapeHtml(String(value))}</p>
      <p class="metric-card__meta">${escapeHtml(String(meta))}</p>
    </article>
  `;
}

function syncNav() {
  document.querySelectorAll('.nav__link').forEach((link) => {
    const route = normalizeRoute(link.getAttribute('href') || '');
    link.classList.toggle('is-active', route === state.route);
  });
}

function syncAutoRefresh() {
  if (state.intervalId) {
    window.clearInterval(state.intervalId);
    state.intervalId = null;
  }
  if (state.autoRefresh && state.auth) {
    state.intervalId = window.setInterval(() => {
      loadDashboardData();
    }, 15000);
  }
}

function updateAuthGate(visible) {
  elements.authGate.classList.toggle('hidden', !visible);
  elements.appShell.classList.toggle('app-shell--locked', visible);
}

function showAuthError(message) {
  if (!message) {
    elements.authError.textContent = '';
    elements.authError.classList.add('hidden');
    return;
  }
  elements.authError.textContent = message;
  elements.authError.classList.remove('hidden');
}

function signOut() {
  state.auth = null;
  clearStoredAuth();
  state.data = {
    overview: null,
    sessions: null,
    workers: null,
    stream: null,
    policy: null,
    quota: null,
    terminations: null,
    events: null,
  };
  state.errors = {};
  state.lastUpdatedAt = null;
  state.selectedSessionId = null;
  state.selectedSessionDetail = null;
  state.selectedSessionError = null;
  syncAutoRefresh();
  elements.adminTokenInput.value = '';
  updateAuthGate(true);
  render();
}

async function apiRequest(path) {
  const response = await fetch(`${state.auth.apiBase}${path}`, {
    headers: {
      'Accept': 'application/json',
      'X-Amon-Internal-Token': state.auth.token,
    },
  });

  if (!response.ok) {
    const maybeJson = await response.json().catch(() => null);
    const detail =
      maybeJson?.detail?.message ||
      maybeJson?.detail ||
      maybeJson?.message ||
      `${response.status} ${response.statusText}`;
    throw new Error(String(detail));
  }

  return response.json();
}

function loadStoredAuth() {
  try {
    const raw = window.sessionStorage.getItem(STORAGE_KEY);
    if (!raw) {
      return null;
    }
    const parsed = JSON.parse(raw);
    if (!parsed?.apiBase || !parsed?.token) {
      return null;
    }
    return {
      apiBase: stripTrailingSlash(parsed.apiBase),
      token: parsed.token,
    };
  } catch {
    return null;
  }
}

function storeAuth(auth) {
  window.sessionStorage.setItem(STORAGE_KEY, JSON.stringify(auth));
}

function clearStoredAuth() {
  window.sessionStorage.removeItem(STORAGE_KEY);
}

function normalizeRoute(hash) {
  const route = String(hash || '').replace(/^#/, '').trim().toLowerCase();
  return ROUTES[route] ? route : 'overview';
}

function stripTrailingSlash(value) {
  return value.replace(/\/+$/, '');
}

function humanizeError(error) {
  if (error instanceof Error && error.message) {
    return error.message;
  }
  return 'Unable to reach the internal metadata API.';
}

function formatTimestamp(value) {
  if (!value) {
    return 'N/A';
  }
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) {
    return 'N/A';
  }
  return new Intl.DateTimeFormat(undefined, {
    month: 'short',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  }).format(date);
}

function formatRelativeTime(value) {
  if (!value) {
    return 'N/A';
  }
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return 'N/A';
  }
  const diffMs = date.getTime() - Date.now();
  const diffMinutes = Math.round(diffMs / 60000);
  if (Math.abs(diffMinutes) < 1) {
    return 'just now';
  }
  if (Math.abs(diffMinutes) < 60) {
    return new Intl.RelativeTimeFormat(undefined, { numeric: 'auto' }).format(diffMinutes, 'minute');
  }
  const diffHours = Math.round(diffMinutes / 60);
  if (Math.abs(diffHours) < 24) {
    return new Intl.RelativeTimeFormat(undefined, { numeric: 'auto' }).format(diffHours, 'hour');
  }
  const diffDays = Math.round(diffHours / 24);
  return new Intl.RelativeTimeFormat(undefined, { numeric: 'auto' }).format(diffDays, 'day');
}

function formatDuration(value) {
  if (value === null || value === undefined || Number.isNaN(Number(value))) {
    return 'No action timing yet';
  }
  return `${Math.round(Number(value))} ms avg action`;
}

function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}
