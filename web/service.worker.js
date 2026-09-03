// KAGURA ASCENT の Service Worker（Godot が生成するものを CI で置き換える）
// 方針：常にネットワーク優先。取れたものは控えとして保存し、オフラインのときだけ控えを返す。
// 新しい版が公開されたら待たずに即座に入れ替わり、古いキャッシュはすべて捨てる。
const CACHE = 'kagura-runtime-v1';
const OLD_PREFIX = 'KAGURA ASCENT-sw-cache-';

self.addEventListener('install', (event) => {
	event.waitUntil(self.skipWaiting());
});

self.addEventListener('activate', (event) => {
	event.waitUntil((async () => {
		const keys = await caches.keys();
		const hadOld = keys.some((k) => k.startsWith(OLD_PREFIX));
		await Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k)));
		await self.clients.claim();
		if (hadOld) {
			// 古い版を表示している画面を最新に読み直す（起動直後にしか起きない）
			const all = await self.clients.matchAll({ type: 'window' });
			all.forEach((c) => c.navigate(c.url));
		}
	})());
});

self.addEventListener('fetch', (event) => {
	const req = event.request;
	if (req.method !== 'GET') return;
	const url = new URL(req.url);
	if (url.origin !== self.location.origin) return;
	event.respondWith((async () => {
		try {
			const res = await fetch(req, { cache: 'no-cache' });
			if (res && res.ok) {
				const copy = res.clone();
				caches.open(CACHE).then((c) => c.put(req, copy)).catch(() => {});
			}
			return res;
		} catch (e) {
			const hit = await caches.match(req);
			if (hit) return hit;
			throw e;
		}
	})());
});
