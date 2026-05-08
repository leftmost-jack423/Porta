import { downloadURL, getSessionStatus, getShare, requestAccess, ShareInfo, SessionStatus } from "./api";
import { clear, h, humanSize, parseShareToken, tokenFromInput } from "./util";

const app = document.getElementById("app")!;

function renderLanding(initialError?: string): void {
  clear(app);

  const input = h("input", {
    type: "text",
    class: "input",
    placeholder: "Paste a Porta share link or token",
    "data-testid": "share-input",
    autocomplete: "off",
    autocapitalize: "off",
    spellcheck: "false",
  }) as HTMLInputElement;

  const go = h("button", {
    class: "btn",
    "data-testid": "share-submit",
  }, "Open link") as HTMLButtonElement;

  const errSlot = h("p", {
    class: "error",
    "data-testid": "landing-error",
    style: "min-height:18px; margin:8px 0 0;",
  }, initialError || "");

  const submit = () => {
    const tok = tokenFromInput(input.value.trim());
    if (!tok) {
      errSlot.textContent = "That doesn't look like a Porta link.";
      return;
    }
    errSlot.textContent = "";
    history.pushState({}, "", `/s/${encodeURIComponent(tok)}`);
    void boot();
  };
  go.addEventListener("click", submit);
  input.addEventListener("keydown", (e) => {
    if ((e as KeyboardEvent).key === "Enter") submit();
  });

  app.append(
    h("h1", { "data-testid": "landing-title" }, "Porta"),
    h("h2", {}, "Temporary, live links from a phone."),
    h(
      "div",
      { class: "card", "data-testid": "landing-card" },
      h("p", {}, "Open a share link on your phone, or paste one here:"),
      h("div", { class: "row" }, input, go),
      errSlot,
      h("p", { class: "small" }, "Links expire automatically. Only the sender can approve access."),
    ),
  );

  // Focus is a nicety on desktop; harmless on mobile.
  queueMicrotask(() => input.focus());
}

function renderError(msg: string): void {
  clear(app);
  const back = h("button", {
    class: "btn ghost",
    "data-testid": "error-back",
  }, "Back to start") as HTMLButtonElement;
  back.addEventListener("click", () => {
    history.pushState({}, "", "/");
    renderLanding();
  });

  app.append(
    h("h1", {}, "Porta"),
    h(
      "div",
      { class: "card", "data-testid": "error-card" },
      h("p", { class: "error", "data-testid": "error-msg" }, msg),
      back,
    ),
  );
}

function renderShare(token: string, info: ShareInfo): void {
  clear(app);

  const filesCard = h(
    "div",
    { class: "card", "data-testid": "files-card" },
    ...info.files.map((f) =>
      h(
        "div",
        { class: "file-row" },
        h("span", { class: "name" }, f.name),
        h("span", { class: "size" }, humanSize(f.size)),
      ),
    ),
    h(
      "div",
      { class: "meta" },
      h("span", {}, `${info.file_count} file${info.file_count === 1 ? "" : "s"}`),
      h("span", {}, humanSize(info.total_bytes)),
    ),
  );

  const button = h("button", {
    class: "btn",
    "data-testid": "request-btn",
  }, "Request files") as HTMLButtonElement;
  button.addEventListener("click", async () => {
    button.disabled = true;
    button.textContent = "Waiting for approval…";
    try {
      const { session_id } = await requestAccess(token);
      await waitForApproval(session_id, info);
    } catch (e) {
      renderError((e as Error).message);
    }
  });

  app.append(
    h("h1", { "data-testid": "share-title" }, info.title || "Someone shared files with you"),
    h("h2", {}, "Tap below to request access. The sender will approve on their phone."),
    filesCard,
    h("div", { class: "card" }, button),
  );
}

async function waitForApproval(sessionId: string, info: ShareInfo): Promise<void> {
  clear(app);
  const status = h(
    "div",
    { class: "status", "data-testid": "waiting-status" },
    h("span", { class: "dot" }),
    h("span", {}, "Waiting for sender…"),
  );
  app.append(h("h1", {}, "Approve on your phone"), h("div", { class: "card" }, status));

  const deadline = Date.now() + 5 * 60 * 1000;
  while (Date.now() < deadline) {
    const s: SessionStatus = await getSessionStatus(sessionId);
    if (s.status === "approved") {
      renderDownload(sessionId, info);
      return;
    }
    if (s.status === "rejected") {
      renderError("The sender declined the request.");
      return;
    }
    if (s.status === "closed") {
      renderError("The session was closed.");
      return;
    }
    await sleep(1500);
  }
  renderError("Timed out waiting for approval.");
}

function renderDownload(sessionId: string, info: ShareInfo): void {
  clear(app);
  const list = h(
    "div",
    { class: "card", "data-testid": "download-card" },
    ...info.files.map((f) => {
      const row = h("div", { class: "file-row" });
      const link = h("a", {
        href: downloadURL(sessionId, f.name),
        class: "name",
        "data-testid": "download-link",
      }, f.name);
      link.setAttribute("download", f.name);
      row.append(link, h("span", { class: "size" }, humanSize(f.size)));
      return row;
    }),
  );

  app.append(
    h("h1", { "data-testid": "approved-title" }, "Approved"),
    h("h2", {}, "Tap a file to download. Bytes stream from the sender's phone."),
    list,
    h(
      "div",
      { class: "card small" },
      "The link is live only while the sender keeps Porta open on their phone.",
    ),
  );
}

function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}

async function boot(): Promise<void> {
  const token = parseShareToken();
  if (!token) {
    renderLanding();
    return;
  }
  try {
    const info = await getShare(token);
    renderShare(token, info);
  } catch (e) {
    renderError((e as Error).message);
  }
}

window.addEventListener("popstate", () => void boot());

boot();
