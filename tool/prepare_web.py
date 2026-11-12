"""Write a versioned service worker for the actual Flutter build artifacts."""

import hashlib
import json
from pathlib import Path
from urllib.parse import quote

root = Path("build/web")
if not (root / "main.dart.js").is_file():
    raise SystemExit("Run a JavaScript Flutter web release build first.")

worker = root / "moneymate-sw.js"
files = [
    path for path in sorted(root.rglob("*"))
    if path.is_file()
    and not path.name.startswith(".")
    and path.name not in {worker.name, "flutter_service_worker.js"}
    and path.suffix not in {".map", ".symbols"}
    and not (path.parent.name == "canvaskit" and path.name.startswith(("skwasm", "wimp")))
]
digest = hashlib.sha256()
for path in files:
    digest.update(path.relative_to(root).as_posix().encode())
    digest.update(path.read_bytes())
urls = [quote(path.relative_to(root).as_posix()) for path in files]
worker.write_text(f"""
const scope = self.registration.scope;
const prefix = 'moneymate:' + scope + ':';
const cacheName = prefix + '{digest.hexdigest()[:20]}';
const paths = {json.dumps(urls)};

self.addEventListener('install', event => {{
  event.waitUntil(caches.open(cacheName).then(cache =>
    cache.addAll(paths.map(path => new Request(new URL(path, scope), {{cache: 'reload'}})))));
}});

self.addEventListener('activate', event => {{
  event.waitUntil((async () => {{
    for (const key of await caches.keys()) {{
      if (key.startsWith(prefix) && key !== cacheName) await caches.delete(key);
    }}
    await self.clients.claim();
  }})());
}});

self.addEventListener('fetch', event => {{
  const url = new URL(event.request.url);
  if (event.request.method !== 'GET' || !url.href.startsWith(scope)) return;
  if (url.pathname.endsWith('/moneymate-sw.js')) return;
  event.respondWith((async () => {{
    const cache = await caches.open(cacheName);
    const key = event.request.mode === 'navigate' ? new URL('index.html', scope) : event.request;
    return await cache.match(key) || fetch(event.request);
  }})());
}});
""", encoding="utf-8")
(root / ".nojekyll").touch()
