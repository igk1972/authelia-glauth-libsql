import { defineConfig, devices } from "@playwright/test";

// Authelia mandates an https authelia_url, so the portal is served over TLS with a
// self-signed cert for auth.example.com. We map that host to 127.0.0.1 at the browser
// level (host-resolver-rules) and ignore the self-signed cert — no /etc/hosts needed.
const PORT = process.env.PORT_AUTHELIA ?? "10010";

export default defineConfig({
    testDir: "./e2e",
    timeout: 30_000,
    reporter: [["list"]],
    use: {
        baseURL: `https://auth.example.com:${PORT}`,
        ignoreHTTPSErrors: true,
        launchOptions: {
            args: ["--host-resolver-rules=MAP auth.example.com 127.0.0.1"],
        },
    },
    projects: [{ name: "chromium", use: { ...devices["Desktop Chrome"] } }],
});
