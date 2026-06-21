import { test, expect } from "@playwright/test";

// Browser login through the real Authelia portal UI: authenticates the seeded glauth
// user (john/password). A successful first-factor login lands on the authenticated
// stage and persists the session in libsql (see `mise run verify` for the SQL-level proof).
test("first-factor login via the portal reaches the authenticated stage", async ({ page }) => {
    await page.goto("/");

    await page.locator("#username-textfield").fill("john");
    await page.locator("#password-textfield").fill("password");
    await page.locator("#sign-in-button").click();

    await expect(page.locator("#authenticated-stage").first()).toBeVisible({ timeout: 15_000 });
    await expect(page.locator("#logout-button")).toBeVisible();
});
