import { expect, test } from "@playwright/test";
import { installMocks, sampleShare } from "./mocks";

test.describe("share → approval → download flow", () => {
  test("shows files, requests access, approves, downloads", async ({ page }) => {
    await installMocks(page, {
      share: sampleShare,
      statusSequence: ["pending", "pending", "approved"],
    });

    await page.goto("/s/tok_demo_001");

    // 1. Share landed.
    await expect(page.getByTestId("share-title")).toHaveText(sampleShare.title!);
    await expect(page.getByTestId("files-card")).toContainText("beach.jpg");
    await expect(page.getByTestId("files-card")).toContainText("3 files");

    // 2. Request access → enters "Waiting" state.
    await page.getByTestId("request-btn").click();
    await expect(page.getByTestId("waiting-status")).toBeVisible();

    // 3. After the sequence hits "approved", the download view renders.
    await expect(page.getByTestId("approved-title")).toBeVisible({ timeout: 10_000 });

    const links = page.getByTestId("download-link");
    await expect(links).toHaveCount(sampleShare.files.length);

    // First link points at /p/<session>/files/<name> and carries download=name.
    const href = await links.first().getAttribute("href");
    expect(href).toMatch(/\/p\/sess_mock_01\/files\/beach\.jpg$/);
    await expect(links.first()).toHaveAttribute("download", "beach.jpg");
  });

  test("rejected session surfaces the sender-declined error", async ({ page }) => {
    await installMocks(page, {
      share: sampleShare,
      statusSequence: ["pending", "rejected"],
    });

    await page.goto("/s/tok_demo_002");
    await page.getByTestId("request-btn").click();

    await expect(page.getByTestId("error-msg")).toContainText(
      "sender declined",
      { timeout: 10_000 },
    );
    await expect(page.getByTestId("error-back")).toBeVisible();
  });

  test("closed session surfaces the closed-session error", async ({ page }) => {
    await installMocks(page, {
      share: sampleShare,
      statusSequence: ["pending", "closed"],
    });

    await page.goto("/s/tok_demo_003");
    await page.getByTestId("request-btn").click();

    await expect(page.getByTestId("error-msg")).toContainText("closed", {
      timeout: 10_000,
    });
  });
});
