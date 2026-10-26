# cleanstrike website

Static landing page (`site/`) plus a download counter (`/api/downloads`).

Deployed as a **Cloudflare Worker** from the repo root: `wrangler.jsonc` serves `site/` and routes
`/api/downloads` through `worker/index.js` (which reuses `functions/api/downloads.js`, so a
Pages deployment works too). Deploy command: `npx wrangler deploy`, no build command.
Attach your domain in the Worker's Settings › Domains & Routes › Add › Custom domain.

Downloads: the button links to `releases/latest/download/Cleanstrike.exe`, so publish each version as
a GitHub Release with an asset named exactly `Cleanstrike.exe`. The counter sums GitHub's own
`download_count` for every release asset (cached 5 min at the edge).
