# cleanstrike website

Static landing page (`site/`) + one Cloudflare Pages Function (`functions/api/downloads.js`).

Cloudflare Pages setup: connect this repo, framework preset **None**, build command empty,
build output directory **`site`**, root directory empty (so `functions/` is picked up).
Then add your custom domain under the project's *Custom domains* tab.

Downloads: the button links to `releases/latest/download/Cleanstrike.exe`, so publish each
version as a GitHub Release with an asset named exactly `Cleanstrike.exe`. The counter is the
sum of GitHub's own `download_count` for every release asset (cached 5 min at the edge).
