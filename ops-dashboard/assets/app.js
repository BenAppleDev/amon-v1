const STORAGE_KEY = 'amon-ops-dashboard-preferences';
const DEFAULT_API_BASE = window.location.pathname.startsWith('/ops') ? '' : 'http://127.0.0.1:8000';

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
  apiBase: loadStoredApiBase(),
  route: normalizeRoute(window.location.hash),
  auth: {
    authenticated: false,
    environment: null,
    operatorId: null,
    authMethod: null,
    sessionExpiresAt: null,
    devTokenLoginEnabled: false,
  },
  data: {
    overview: null,
    sessions: null,
    workers: null,
    stream: null,
    policy: null,
    quota: null,
    terminations: null,
    events: null,
    historySummary: null,
    historySnapshots: null,
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
  operatorIdInput: document.getElementById('operator-id-input'),
  routeEyebrow: document.getElementById('route-eyebrow'),
  routeTitle: document.getElementById('route-title'),
  connectionPill: document.getElementById('connection-pill'),
  autoRefreshLabel: document.getElementById('auto-refresh-label'),
  environmentLabel: document.getElementById('environment-label'),
  operatorLabel: document.getElementById('operator-label'),
  lastSyncLabel: document.getElementById('last-sync-label'),
  alertStrip: document.getElementById('alert-strip'),
  viewRoot: document.getElementById('view-root'),
};

initialize();

async function initialize() {
  elements.apiBaseInput.value = state.apiBase;
  bindEvents();
  syncNav();
  await refreshAuthStatus({ revealGateOnUnauthed: true, loadDataOnSuccess: true });
}

function bindEvents() {
  window.addEventListener('hashchange', () => {
    state.route = normalizeRoute(window.location.hash);
    syncNav();
    render();
  });

  elements.authForm.addEventListener('submit', async (event) => {
    event.preventDefault();
    const apiBase = stripTrailingSlash(String(new FormData(elements.authForm).get('apiBase') || '').trim());
    const adminToken = String(new FormData(elements.authForm).get('adminToken') || '').trim();
    const operatorId = String(new FormData(elements.authForm).get('operatorId') || '').trim();

    if (!adminToken) {
      showAuthError('Enter a dev token for local development, or use the trusted operator session button.');
      return;
    }

    state.apiBase = apiBase || DEFAULT_API_BASE;
    storeApiBase(state.apiBase);
    showAuthError('');

    try {
      const status = await authRequest('/ops/auth/session', {
        method: 'POST',
        body: {
          admin_token: adminToken,
          operator_id: operatorId || 'dev-operator',
        },
      });
      applyAuthStatus(status);
      updateAuthGate(false);
      syncAutoRefresh();
      await loadDashboardData();
      elements.adminTokenInput.value = '';
    } catch (error) {
      showAuthError(humanizeError(error));
    }
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
      await signOut();
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
      return;
    }
    if (action === 'bootstrap-auth') {
      const apiBase = stripTrailingSlash(String(new FormData(elements.authForm).get('apiBase') || '').trim());
      state.apiBase = apiBase || DEFAULT_API_BASE;
      storeApiBase(state.apiBase);
      await refreshAuthStatus({ revealGateOnUnauthed: true, loadDataOnSuccess: true });
    }
  });
}

async function refreshAuthStatus({ revealGateOnUnauthed, loadDataOnSuccess }) {
  showAuthError('');
  try {
    const status = await authRequest('/ops/auth/status');
    applyAuthStatus(status);
    if (status.authenticated) {
      updateAuthGate(false);
      syncAutoRefresh();
      if (loadDataOnSuccess) {
        await loadDashboardData();
      } else {
        render();
      }
      return;
    }
    syncAutoRefresh();
    if (revealGateOnUnauthed) {
      updateAuthGate(true);
    }
    render();
  } catch (error) {
    if (revealGateOnUnauthed) {
      updateAuthGate(true);
      showAuthError(humanizeError(error));
    }
    render();
  }
}

async function loadDashboardData() {
  if (!state.auth.authenticated) {
    return;
  }

  state.isLoading = true;
  render();

  const endpoints = {
    overview: '/ops/api/protected-sessions/overview',
    sessions: '/ops/api/protected-sessions/sessions/active',
    workers: '/ops/api/protected-sessions/workers',
    stream: '/ops/api/protected-sessions/counters/stream',
    policy: '/ops/api/protected-sessions/counters/policy',
    quota: '/ops/api/protected-sessions/counters/quota',
    terminations: '/ops/api/protected-sessions/counters/terminations',
    events: '/ops/api/protected-sessions/events?limit=60',
    historySummary: '/ops/api/protected-sessions/history/summary?hours=24',
    historySnapshots: '/ops/api/protected-sessions/history/snapshots?limit=24',
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
  if (!state.auth.authenticated || !sessionId) {
    return;
  }

  state.selectedSessionError = null;
  if (!quiet) {
    render();
  }

  try {
    state.selectedSessionDetail = await apiRequest(`/ops/api/protected-sessions/sessions/${sessionId}`);
  } catch (error) {
    state.selectedSessionDetail = null;
    state.selectedSessionError = humanizeError(error);
  }
}

function applyAuthStatus(status) {
  state.auth = {
    authenticated: Boolean(status.authenticated),
    environment: status.environment || null,
    operatorId: status.operator_id || null,
    authMethod: status.auth_method || null,
    sessionExpiresAt: status.session_expires_at || null,
    devTokenLoginEnabled: Boolean(status.dev_token_login_enabled),
  };
}

function render() {
  const routeConfig = ROUTES[state.route];
  elements.routeEyebrow.textContent = routeConfig.eyebrow;
  elements.routeTitle.textContent = routeConfig.title;
  elements.autoRefreshLabel.textContent = state.autoRefresh ? 'On' : 'Off';
  elements.environmentLabel.textContent = state.auth.environment
    ? `${state.auth.environment.label} · ${state.auth.environment.app_env}`
    : 'Unknown';
  elements.operatorLabel.textContent = state.auth.authenticated
    ? `${state.auth.operatorId || 'operator'} · ${state.auth.authMethod || 'session'}`
    : 'Not signed in';
  elements.lastSyncLabel.textContent = state.lastUpdatedAt ? formatTimestamp(state.lastUpdatedAt) : 'Never';

  if (state.auth.authenticated) {
    elements.connectionPill.textContent = state.isLoading ? 'Syncing' : 'Operator session';
    elements.connectionPill.className = 'status-pill';
  } else {
    elements.connectionPill.textContent = 'Sign-in required';
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
  const historySummary = state.data.historySummary;
  const historySnapshots = state.data.historySnapshots;

  if (!overview || !sessions || !workers || !stream || !historySummary || !historySnapshots) {
    return renderLoadingState('Loading overview metadata...');
  }

  const latestSnapshot = historySummary.latest_snapshot;

  return `
    <section class="metric-grid">
      ${metricCard('Active sessions', overview.active_sessions, `${overview.total_sessions} total session records`)}
      ${metricCard('Live streams', overview.active_streams, `${overview.users_with_live_streams} users with live streams`)}
      ${metricCard('Healthy workers', overview.healthy_workers, `${overview.degraded_workers} degraded workers`)}
      ${metricCard('Quota rejections', overview.quota_rejections_total, 'Current process lifetime')}
      ${metricCard('Protocol errors', overview.protocol_errors_total, `${overview.heartbeat_timeouts_total} heartbeat timeouts`)}
      ${metricCard('24h metadata events', historySummary.total_events, `${historySnapshots.snapshots.length} persisted snapshots`)}
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
            <h3>Durable ops history</h3>
            <p>Persisted metadata summary for this environment over the last 24 hours.</p>
          </div>
        </div>
        <div class="detail-list">
          ${detailRow('Environment', historySummary.environment.label)}
          ${detailRow('Window', `${historySummary.window_hours} hours`)}
          ${detailRow('Persisted events', historySummary.total_events)}
          ${detailRow('Latest snapshot', latestSnapshot ? formatTimestamp(latestSnapshot.recorded_at) : 'No snapshot yet')}
          ${detailRow('Snapshot active streams', latestSnapshot ? latestSnapshot.active_streams : 0)}
          ${detailRow('Snapshot protocol errors', latestSnapshot ? latestSnapshot.protocol_errors_total : 0)}
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
            <h3>Recent persisted snapshots</h3>
            <p>Metadata-only snapshot points used for later trend views and operational history.</p>
          </div>
        </div>
        ${renderSnapshotList(historySnapshots.snapshots)}
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
  const historySummary = state.data.historySummary;

  if (!stream || !sessions || !historySummary) {
    return renderLoadingState('Loading stream telemetry...');
  }

  return `
    <section class="metric-grid">
      ${metricCard('Active streams', stream.active_streams_total, `${stream.total_live_stream_capacity} total live-stream capacity`)}
      ${metricCard('Attaches / detaches', `${stream.attach_count} / ${stream.detach_count}`, `${stream.reconnect_attempts} reconnect attempts`)}
      ${metricCard('Resumes', stream.successful_resumes, `${stream.heartbeat_timeout_count} heartbeat timeouts`)}
      ${metricCard('Dropped events', stream.dropped_events_total, `${stream.protocol_error_count} protocol errors`)}
      ${metricCard('State / frame updates', `${stream.state_update_count} / ${stream.frame_update_count}`, formatDuration(stream.average_action_duration_ms))}
      ${metricCard('24h stream reasons', Object.keys(historySummary.stream_error_counts || {}).length, 'Persisted protocol/stream reason categories')}
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
            <h3>Persisted stream error reasons</h3>
            <p>Recent durable stream/protocol error categories across the current environment.</p>
          </div>
        </div>
        ${renderDictionaryGrid(historySummary.stream_error_counts, 'No persisted stream error reasons yet.')}
      </article>
    </section>

    <section class="panel">
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
    </section>
  `;
}

function renderPolicyView() {
  const policy = state.data.policy;
  const quota = state.data.quota;
  const terminations = state.data.terminations;
  const historySummary = state.data.historySummary;

  if (!policy || !quota || !terminations || !historySummary) {
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
            <h3>Persisted reason counts</h3>
            <p>Durable metadata-only reason categories across the last 24 hours.</p>
          </div>
        </div>
        ${renderDictionaryGrid(historySummary.reason_counts, 'No durable reason counts recorded yet.')}
      </article>

      <article class="panel">
        <div class="panel__header">
          <div>
            <h3>Recent policy events</h3>
            <p>Most recent metadata-only policy-related events from the persistent event store.</p>
          </div>
        </div>
        ${renderEventFeed((state.data.events?.events || []).slice(0, 10), { compact: true })}
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
          <p>${events.total_events} persisted events currently shown for this environment.</p>
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

function renderSnapshotList(snapshots) {
  if (!snapshots?.length) {
    return '<div class="empty-state">No durable snapshots have been written yet.</div>';
  }

  const recent = snapshots.slice(-8).reverse();
  return `
    <div class="stat-list">
      ${recent
        .map(
          (snapshot) => `
            <div class="stat-row">
              <span>
                <strong>${formatTimestamp(snapshot.recorded_at)}</strong>
                <span class="soft"> · ${snapshot.active_sessions} sessions · ${snapshot.active_streams} streams</span>
              </span>
              <span class="soft">
                ${snapshot.protocol_errors_total} protocol · ${snapshot.quota_rejections_total} quota
              </span>
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
  if (state.autoRefresh && state.auth.authenticated) {
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

async function signOut() {
  if (state.auth.authenticated) {
    try {
      await authRequest('/ops/auth/logout', { method: 'POST' });
    } catch {
      // best-effort logout
    }
  }

  state.auth = {
    authenticated: false,
    environment: state.auth.environment,
    operatorId: null,
    authMethod: null,
    sessionExpiresAt: null,
    devTokenLoginEnabled: state.auth.devTokenLoginEnabled,
  };
  state.data = {
    overview: null,
    sessions: null,
    workers: null,
    stream: null,
    policy: null,
    quota: null,
    terminations: null,
    events: null,
    historySummary: null,
    historySnapshots: null,
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

async function authRequest(path, { method = 'GET', body } = {}) {
  const response = await fetch(composeUrl(path), {
    method,
    credentials: 'include',
    headers: {
      'Accept': 'application/json',
      ...(body ? { 'Content-Type': 'application/json' } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
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

async function apiRequest(path) {
  const response = await fetch(composeUrl(path), {
    credentials: 'include',
    headers: {
      'Accept': 'application/json',
    },
  });

  if (response.status === 401) {
    state.auth.authenticated = false;
    updateAuthGate(true);
    syncAutoRefresh();
    throw new Error('Operator session required.');
  }

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

function composeUrl(path) {
  return `${state.apiBase}${path}`;
}

function loadStoredApiBase() {
  try {
    const raw = window.sessionStorage.getItem(STORAGE_KEY);
    if (!raw) {
      return DEFAULT_API_BASE;
    }
    const parsed = JSON.parse(raw);
    return stripTrailingSlash(parsed.apiBase || DEFAULT_API_BASE);
  } catch {
    return DEFAULT_API_BASE;
  }
}

function storeApiBase(apiBase) {
  window.sessionStorage.setItem(STORAGE_KEY, JSON.stringify({ apiBase }));
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
  return 'Unable to reach the ops API.';
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
