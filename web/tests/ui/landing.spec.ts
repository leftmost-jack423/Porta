import { expect, test } from "@playwright/test";
import { installMocks, sampleShare } from "./mocks";

test.describe("landing page", () => {
  test("renders title, input, and submit button", async ({ page }) => {
    await installMocks(page, {});
    await page.goto("/");

    await expect(page.getByTestId("landing-title")).toHaveText("Porta");
    await expect(page.getByTestId("share-input")).toBeVisible();
    await expect(page.getByTestId("share-submit")).toBeVisible();
  });

  test("rejects garbage input with inline error", async ({ page }) => {
    await installMocks(page, {});
    await page.goto("/");

    await page.getByTestId("share-input").fill("this has spaces and /slashes/");
    await page.getByTestId("share-submit").click();

    await expect(page.getByTestId("landing-error")).toContainText(
      "doesn't look like a Porta link",
    );
  });

  test("navigates to /s/<token> when a full URL is pasted", async ({ page }) => {
    await installMocks(page, { share: sampleShare });
    await page.goto("/");

    await page.getByTestId("share-input").fill("https://porta.example/s/tok_abc.123");
    await page.getByTestId("share-submit").click();

    await expect(page).toHaveURL(/\/s\/tok_abc\.123$/);
    await expect(page.getByTestId("share-title")).toBeVisible();
  });

  test("bare token also works (Enter submits)", async ({ page }) => {
    await installMocks(page, { share: sampleShare });
    await page.goto("/");

    await page.getByTestId("share-input").fill("tok_barebones-01");
    await page.getByTestId("share-input").press("Enter");

    await expect(page).toHaveURL(/\/s\/tok_barebones-01$/);
    await expect(page.getByTestId("files-card")).toBeVisible();
  });
});
