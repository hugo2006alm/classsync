# ClassSync v0.3.24

## What's changed since v0.3.23

- **Verified app updates:** Windows and Android can check the latest public GitHub release, verify the downloaded installer or APK against the release SHA-256 checksums, and start the platform installer. Update checks run at launch and on demand in **Settings → App updates & widget**.
- **Next-class Android widget:** A home-screen widget shows the upcoming class and opens ClassSync. The Overview screen also refreshes its next-class display from the same schedule data.
- **Public contribution checks:** CI and security scans now run for public pull requests and `main`; release tags retain update and deletion protection. Repository ownership is recorded in `.github/CODEOWNERS` so required code-owner review can protect merges.

## Upgrade notes

- Flutter version: `0.3.24+32`.
- No local database or relay migration is required.
- Android updates require the same signing certificate as existing installations.
