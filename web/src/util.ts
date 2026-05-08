export function humanSize(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`;
  const units = ["KB", "MB", "GB", "TB"];
  let n = bytes / 1024;
  let u = 0;
  while (n >= 1024 && u < units.length - 1) {
    n /= 1024;
    u++;
  }
  return `${n.toFixed(n >= 10 ? 0 : 1)} ${units[u]}`;
}

export function parseShareToken(): string | null {
  // Matches /s/<token>.
  const m = location.pathname.match(/^\/s\/(.+)$/);
  if (!m) return null;
  return decodeURIComponent(m[1]);
}

// tokenFromInput accepts either a bare token or a full share URL
// (https://host/s/<token>) pasted into the landing form.
export function tokenFromInput(raw: string): string | null {
  if (!raw) return null;
  // URL shaped?
  try {
    const u = new URL(raw);
    const m = u.pathname.match(/^\/s\/(.+)$/);
    if (m) return decodeURIComponent(m[1]);
  } catch {
    // Not a URL — fall through and treat as raw token.
  }
  // Tokens are HMAC-shaped (letters/digits/dot/underscore/dash). Reject
  // anything with whitespace or slashes that isn't a URL.
  if (/^[A-Za-z0-9._-]+$/.test(raw)) return raw;
  return null;
}

export function h(
  tag: string,
  attrs: Record<string, string | number | EventListener> = {},
  ...children: (Node | string)[]
): HTMLElement {
  const el = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (k.startsWith("on") && typeof v === "function") {
      el.addEventListener(k.slice(2).toLowerCase(), v as EventListener);
    } else if (k === "class") {
      el.className = String(v);
    } else {
      el.setAttribute(k, String(v));
    }
  }
  for (const c of children) {
    el.append(c instanceof Node ? c : document.createTextNode(c));
  }
  return el;
}

export function clear(el: HTMLElement): void {
  while (el.firstChild) el.removeChild(el.firstChild);
}
