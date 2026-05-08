import { expect, test } from "@playwright/test";
import { installMocks } from "./mocks";

test.describe("error states on /s/<token>", () => {
  test("404 → 'This link is invalid.'", async ({ page }) => {
    await installMocks(page, { shareError: 404 });
    await page.goto("/s/nope");
    await expect(page.getByTestId("error-msg")).toContainText("invalid");
  });

  test("410 → 'expired or been revoked'", async ({ page }) => {
    await installMocks(page, { shareError: 410 });
    await page.goto("/s/expired");
    await expect(page.getByTestId("error-msg")).toContainText("expired");
  });

  test("502 → 'Sender appears to be offline'", async ({ page }) => {
    await installMocks(page, { shareError: 502 });
    await page.goto("/s/offline");
    await expect(page.getByTestId("error-msg")).toContainText("offline");
  });

  test("'Back to start' returns to the landing page", async ({ page }) => {
    await installMocks(page, { shareError: 404 });
    await page.goto("/s/nope");
    await page.getByTestId("error-back").click();
    await expect(page).toHaveURL(/\/$/);
    await expect(page.getByTestId("landing-title")).toBeVisible();
  });
});
