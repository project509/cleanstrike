// Serves the static site; /api/downloads goes to the counter.
import { onRequestGet } from "../functions/api/downloads.js";

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    if (url.pathname === "/api/downloads" && request.method === "GET")
      return onRequestGet({ request, waitUntil: p => ctx.waitUntil(p) });
    return env.ASSETS.fetch(request);
  },
};
