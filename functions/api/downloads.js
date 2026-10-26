// Cloudflare Pages Function: GET /api/downloads
// Total downloads of every release asset on GitHub (GitHub counts each real
// download of the file, so nothing can be double-counted or lost). Cached at
// the edge for 5 minutes to stay far below GitHub's API rate limit.
const REPO = "project509/cleanstrike";

export async function onRequestGet({ request, waitUntil }) {
  const cache = caches.default;
  const key = new Request(new URL("/api/downloads", request.url).toString());
  const hit = await cache.match(key);
  if (hit) return hit;

  let total = 0;
  for (let page = 1; page <= 10; page++) {
    const r = await fetch(`https://api.github.com/repos/${REPO}/releases?per_page=100&page=${page}`, {
      headers: { "User-Agent": "cleanstrike-site", Accept: "application/vnd.github+json" },
    });
    if (!r.ok) return json({ error: "github " + r.status }, 502, 0);
    const releases = await r.json();
    for (const rel of releases) for (const a of rel.assets || []) total += a.download_count || 0;
    if (releases.length < 100) break;
  }

  const res = json({ downloads: total, updated: new Date().toISOString() }, 200, 300);
  waitUntil(cache.put(key, res.clone()));
  return res;
}

function json(body, status, maxAge) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", "Cache-Control": `public, max-age=${maxAge}` },
  });
}
