/**
 * Imperva Cloud WAF Demo App - Interactive Frontend Logic
 */

document.addEventListener('DOMContentLoaded', () => {
  initTabs();
  initHeaderInspectors();
});

// Tab Navigation
function initTabs() {
  const tabBtns = document.querySelectorAll('.tab-btn');
  const tabContents = document.querySelectorAll('.tab-content');

  tabBtns.forEach(btn => {
    btn.addEventListener('click', () => {
      tabBtns.forEach(b => b.classList.remove('active'));
      tabContents.forEach(c => c.classList.remove('active'));

      btn.classList.add('active');
      const targetId = btn.getAttribute('data-tab');
      const targetContent = document.getElementById(targetId);
      if (targetContent) {
        targetContent.classList.add('active');
      }
    });
  });
}

// Live Header Inspector
function initHeaderInspectors() {
  const refreshBtn = document.getElementById('refreshHeadersBtn');
  if (refreshBtn) {
    refreshBtn.addEventListener('click', loadLiveHeaders);
  }
}

async function loadLiveHeaders() {
  try {
    const res = await fetch('/api/debug/headers');
    const data = await res.json();
    
    // Update summary pills
    if (data.imperva_origin_header) {
      document.getElementById('hdr-origin').textContent = data.imperva_origin_header;
    }
    if (data.cloudfront_viewer_country) {
      document.getElementById('hdr-country').textContent = data.cloudfront_viewer_country;
    }
    if (data.client_ip) {
      document.getElementById('hdr-ip').textContent = data.client_ip;
    }

    // Update table
    const tbody = document.querySelector('#headersTable tbody');
    if (tbody && data.all_headers) {
      tbody.innerHTML = '';
      for (const [key, val] of Object.entries(data.all_headers)) {
        const row = document.createElement('tr');
        
        let tagHtml = '<span class="tag-std">Standard Header</span>';
        if (key.toLowerCase().includes('impv')) {
          tagHtml = '<span class="tag-imperva">Imperva vPoP Injection</span>';
        } else if (key.toLowerCase().includes('cloudfront')) {
          tagHtml = '<span class="tag-cf">AWS CloudFront Header</span>';
        }

        row.innerHTML = `
          <td class="code-cell">${escapeHtml(key)}</td>
          <td class="code-val-cell">${escapeHtml(val)}</td>
          <td>${tagHtml}</td>
        `;
        tbody.appendChild(row);
      }
    }
  } catch (err) {
    console.error('Error fetching live headers:', err);
  }
}

// Attack Runner Engine
async function triggerAttack(endpoint, method = 'GET', params = {}) {
  let url = endpoint;
  if (method === 'GET' && Object.keys(params).length > 0) {
    const queryStr = new URLSearchParams(params).toString();
    url += (url.includes('?') ? '&' : '?') + queryStr;
  }

  const reqHeaders = {
    'Accept': 'application/json, text/html, */*'
  };

  const reqDump = `${method} ${url} HTTP/1.1\nHost: ${window.location.host}\nUser-Agent: ${navigator.userAgent}\nAccept: application/json`;
  updateConsoleReq(reqDump);
  updateConsoleMeta('Sending request through CloudFront & Imperva Cloud WAF...');

  try {
    const startTime = performance.now();
    const response = await fetch(url, {
      method: method,
      headers: reqHeaders
    });
    const elapsed = Math.round(performance.now() - startTime);

    const status = response.status;
    const statusText = response.statusText;
    const resHeaders = {};
    response.headers.forEach((val, key) => { resHeaders[key] = val; });

    let bodyText = await response.text();
    let isJson = false;
    try {
      const parsedJson = JSON.parse(bodyText);
      bodyText = JSON.stringify(parsedJson, null, 2);
      isJson = true;
    } catch (_) {}

    const isBlocked = (status === 403 || status === 400 || bodyText.toLowerCase().includes('incapsula incident id') || bodyText.toLowerCase().includes('imperva'));

    let resDump = `HTTP/1.1 ${status} ${statusText} (${elapsed}ms)\n`;
    for (const [k, v] of Object.entries(resHeaders)) {
      resDump += `${k}: ${v}\n`;
    }
    resDump += `\n${bodyText}`;

    updateConsoleRes(resDump, isBlocked);
    updateConsoleMeta(isBlocked 
      ? `🛡️ BLOCKED BY IMPERVA CLOUD WAF (HTTP ${status}) in ${elapsed}ms`
      : `⚠️ EXECUTED ON BACKEND (HTTP ${status}) in ${elapsed}ms`
    );

    // Scroll to console
    document.getElementById('responseConsole').scrollIntoView({ behavior: 'smooth', block: 'nearest' });
  } catch (err) {
    updateConsoleRes(`Network/Request Error: ${err.message}`, true);
    updateConsoleMeta('Connection error or blocked at transport layer');
  }
}

async function triggerHeaderAttack(endpoint, customHeaders = {}) {
  const reqHeaders = {
    'Accept': 'application/json, text/html, */*',
    ...customHeaders
  };

  let headersString = '';
  for (const [k, v] of Object.entries(reqHeaders)) {
    headersString += `${k}: ${v}\n`;
  }

  const reqDump = `GET ${endpoint} HTTP/1.1\nHost: ${window.location.host}\n${headersString}`;
  updateConsoleReq(reqDump);
  updateConsoleMeta('Dispatching malicious header payload through CloudFront...');

  try {
    const startTime = performance.now();
    const response = await fetch(endpoint, {
      method: 'GET',
      headers: reqHeaders
    });
    const elapsed = Math.round(performance.now() - startTime);
    const status = response.status;
    let bodyText = await response.text();

    try {
      bodyText = JSON.stringify(JSON.parse(bodyText), null, 2);
    } catch (_) {}

    const isBlocked = (status === 403 || bodyText.toLowerCase().includes('incapsula') || bodyText.toLowerCase().includes('imperva'));

    let resDump = `HTTP/1.1 ${status} ${response.statusText} (${elapsed}ms)\n\n${bodyText}`;
    updateConsoleRes(resDump, isBlocked);
    updateConsoleMeta(isBlocked 
      ? `🛡️ BLOCKED BY IMPERVA WAF (HTTP ${status})`
      : `⚠️ REACHED BACKEND (HTTP ${status})`
    );
  } catch (err) {
    updateConsoleRes(`Request Error: ${err.message}`, true);
  }
}

async function triggerJsonAttack(endpoint, method = 'POST', jsonString = '{}') {
  let parsed;
  try {
    parsed = JSON.parse(jsonString);
  } catch (e) {
    alert('Invalid JSON in payload: ' + e.message);
    return;
  }

  const reqDump = `${method} ${endpoint} HTTP/1.1\nHost: ${window.location.host}\nContent-Type: application/json\n\n${JSON.stringify(parsed, null, 2)}`;
  updateConsoleReq(reqDump);
  updateConsoleMeta('Dispatching REST API JSON payload...');

  try {
    const startTime = performance.now();
    const response = await fetch(endpoint, {
      method: method,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      },
      body: JSON.stringify(parsed)
    });
    const elapsed = Math.round(performance.now() - startTime);
    const status = response.status;
    let bodyText = await response.text();
    try { bodyText = JSON.stringify(JSON.parse(bodyText), null, 2); } catch (_) {}

    const isBlocked = (status === 403 || bodyText.toLowerCase().includes('incapsula'));
    let resDump = `HTTP/1.1 ${status} ${response.statusText} (${elapsed}ms)\n\n${bodyText}`;

    updateConsoleRes(resDump, isBlocked);
    updateConsoleMeta(isBlocked ? `🛡️ BLOCKED BY IMPERVA API SECURITY (HTTP ${status})` : `⚠️ EXECUTED (HTTP ${status})`);
  } catch (err) {
    updateConsoleRes(`Request Error: ${err.message}`, true);
  }
}

async function triggerBurstAttack(endpoint, count = 10) {
  updateConsoleReq(`Dispatching ${count} concurrent burst requests to ${endpoint} to simulate API Rate Abuse...`);
  updateConsoleMeta(`Running ${count} parallel requests...`);

  const results = [];
  const promises = [];

  for (let i = 1; i <= count; i++) {
    promises.push(
      fetch(endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ phone: `+1-555-01${i.toString().padStart(2, '0')}` })
      }).then(r => ({ req: i, status: r.status, statusText: r.statusText }))
        .catch(err => ({ req: i, status: 'ERR', statusText: err.message }))
    );
  }

  const responses = await Promise.all(promises);
  let summaryText = `Burst Flood Simulation Results (${count} Requests):\n\n`;
  let blockedCount = 0;

  responses.forEach(r => {
    if (r.status === 403 || r.status === 429) blockedCount++;
    summaryText += `Request #${r.req.toString().padStart(2, ' ')} ➔ HTTP ${r.status} (${r.statusText})\n`;
  });

  summaryText += `\nTotal Blocked/Throttled: ${blockedCount}/${count}`;
  updateConsoleRes(summaryText, blockedCount > 0);
  updateConsoleMeta(`Burst Test Complete: ${blockedCount} blocked/throttled`);
}

// Console UI Helpers
function updateConsoleReq(text) {
  const el = document.getElementById('consoleReqText');
  if (el) el.textContent = text;
}

function updateConsoleRes(text, isBlocked) {
  const el = document.getElementById('consoleResText');
  const resContainer = document.querySelector('.console-res');
  if (el) el.textContent = text;
  if (resContainer) {
    resContainer.className = 'console-res ' + (isBlocked ? 'status-blocked' : 'status-passed');
  }
}

function updateConsoleMeta(text) {
  const el = document.getElementById('consoleMeta');
  if (el) el.textContent = text;
}

// Clipboard Helpers
function copyCurl(path, method = 'GET') {
  const host = window.location.origin;
  const cmd = `curl -i -s ${method === 'POST' ? '-X POST ' : ''}"${host}${path}"`;
  copyToClipboard(cmd);
}

function copyCurlWithHeader(path, headerName, headerVal) {
  const host = window.location.origin;
  const cmd = `curl -i -s -H "${headerName}: ${headerVal}" "${host}${path}"`;
  copyToClipboard(cmd);
}

function copyCurlPostJson(path, jsonBody) {
  const host = window.location.origin;
  const cmd = `curl -i -s -X POST "${host}${path}" -H "Content-Type: application/json" -d '${jsonBody}'`;
  copyToClipboard(cmd);
}

function copyCode(elementId) {
  const code = document.getElementById(elementId)?.textContent;
  if (code) copyToClipboard(code);
}

function copyToClipboard(text) {
  navigator.clipboard.writeText(text).then(() => {
    showToast('cURL command copied to clipboard!');
  }).catch(err => {
    alert('Copy failed: ' + err);
  });
}

function showToast(msg) {
  const toast = document.createElement('div');
  toast.textContent = msg;
  toast.style.cssText = `
    position: fixed;
    bottom: 24px;
    right: 24px;
    background: #00f2fe;
    color: #0a0e1a;
    font-weight: 700;
    padding: 0.8rem 1.2rem;
    border-radius: 8px;
    box-shadow: 0 4px 16px rgba(0, 242, 254, 0.4);
    z-index: 1000;
    font-family: var(--font-sans);
    transition: opacity 0.3s ease;
  `;
  document.body.appendChild(toast);
  setTimeout(() => {
    toast.style.opacity = '0';
    setTimeout(() => toast.remove(), 300);
  }, 2200);
}

function escapeHtml(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}
