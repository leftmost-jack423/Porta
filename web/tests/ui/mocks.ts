import { Page, Route } from "@playwright/test";

// Shared mock for Porta's /v1/* + /p/* endpoints. Each test installs
// installMocks(page, scenario) before navigating, so pages render with
// predictable, deterministic backend behavior.

export type Scenario = {
  token?: string;            // token the page is loaded with (for lookup)
  share?: ShareFixture;      // /v1/shares/by-token/:token
  shareError?: number;       // force a non-2xx on /v1/shares/by-token/:token
  requestError?: number;     // force a non-2xx on POST /requests
  // Status progression (poll answers). The last entry repeats forever.
  statusSequence?: Array<"pending" | "approved" | "rejected" | "closed">;
  // Simulated file bytes served by /p/:sid/files/:name (default "hello\n").
  fileBody?: string;
};

export type ShareFixture = {
  share_id: string;
  title?: string;
  files: { name: string; size: number }[];
  file_count: number;
  total_bytes: number;
  expires_at: string;
};

export const sampleShare: ShareFixture = {
  share_id: "share_mock_01",
  title: "Trip photos",
  files: [
    { name: "beach.jpg", size: 2_345_678 },
    { name: "sunset.jpg", size: 987_654 },
    { name: "notes.txt", size: 412 },
  ],
  file_count: 3,
  total_bytes: 2_345_678 + 987_654 + 412,
  expires_at: new Date(Date.now() + 3600_000).toISOString(),
};

export async function installMocks(page: Page, scenario: Scenario): Promise<void> {
  let pollIdx = 0;
  const statusSeq = scenario.statusSequence ?? ["approved"];

  await page.route(/\/v1\/shares\/by-token\/[^/]+$/, (route: Route) => {
    if (scenario.shareError) {
      return route.fulfill({ status: scenario.shareError, body: "" });
    }
    const body = scenario.share ?? sampleShare;
    return route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify(body),
    });
  });

  await page.route(/\/v1\/shares\/by-token\/[^/]+\/requests$/, (route: Route) => {
    if (scenario.requestError) {
      return route.fulfill({ status: scenario.requestError, body: "" });
    }
    return route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({ session_id: "sess_mock_01", status: "pending" }),
    });
  });

  await page.route(/\/v1\/sessions\/[^/]+\/status$/, (route: Route) => {
    const status = statusSeq[Math.min(pollIdx, statusSeq.length - 1)];
    pollIdx++;
    return route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({ session_id: "sess_mock_01", status }),
    });
  });

  await page.route(/\/p\/[^/]+\/files\/.+$/, (route: Route) => {
    return route.fulfill({
      status: 200,
      contentType: "application/octet-stream",
      body: scenario.fileBody ?? "hello\n",
    });
  });
}
