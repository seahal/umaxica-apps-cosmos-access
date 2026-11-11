# Access: No Service Worker (2026-11-10)

Owner: Access (`auth`, `visa`). Status: decided (owner), queued; run at any time.

## Decision (owner, 2026-11-10)

Access registers no Service Worker. When one was installed, sign-in failed repeatedly and clearing
cookies did not help, because the worker kept intercepting requests; the owner found the worker was
usually the cause. On the OpenID Provider origin a worker can intercept `/authorize`, redirects and
ceremony pages, serve stale pages or flow state, and stays in browsers after a deploy.

## Observed on 2026-11-10

- `src/pwa/` is empty and no source in `src/`, `app/` or `config/` registers a worker.
- Built leftovers remain: `public/vite*/assets/register-*.js` (and source maps), and a
  `core_org-*.js` bundle that mentions a worker, in `public/vite`, `public/vite-dev`,
  `public/vite-test` and `public/vite-e2e-test`.
- `app/controllers/concerns/sign_out_clear_site_data.rb` already sends `Clear-Site-Data` on
  sign-out.

## Work order (Codex, this repository)

```
Make Access free of Service Workers and remove any worker left in users' browsers.
Read AGENTS.md and the rules it requires for config/**, app/controllers/**, src/** and test/**.

1. Remove built leftovers that register a worker (public/vite*/assets/register-*.js and maps, and
   any other built asset that registers one). Confirm these directories are build output and
   whether they are tracked or ignored; do not commit build output. Make sure no build
   configuration (vite config, plugins, package.json) produces a worker.
2. Unregister leftover workers: Auth and Visa responses for document requests send
   `Clear-Site-Data: "cache", "storage"` only if that does not delete state an active ceremony
   needs; otherwise propose the narrowest safe trigger (for example a fixed, short rollout window
   or a dedicated endpoint) and report before implementing. Reuse the existing
   sign_out_clear_site_data concern where it fits. If a scope is chosen that must end, record
   its exit condition.
3. Add a static guard test: no source under src/ or app/ for Access calls
   navigator.serviceWorker.register, and no Access route serves a worker script.
4. Run bun run check, bin/rubocop and the affected tests. Record evidence/. No commit.
```
