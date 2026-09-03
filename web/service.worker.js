// KAGURA ASCENT の Service Worker（Godot が生成するものを CI で置き換える）
// 方針：何もキャッシュしない。通信はブラウザに任せる（GitHub Pages の ETag で更新確認される）。
// 役割は 2 つだけ：新しい版が出たら待たずに入れ替わること、以前の版が残したキャッシュを消すこと。
// ※ fetch を横取りして大きなファイルを複製・保存すると iOS Safari で読み込みが止まることがあるため、fetch には触らない。
const OLD_PREFIXES = ['KAGURA ASCENT-sw-cache-', 'kagura-runtime-'];

self.addEventListener('install', (event) => {
	event.waitUntil(self.skipWaiting());
});

self.addEventListener('activate', (event) => {
	event.waitUntil((async () => {
		const keys = await caches.keys();
		const hadOld = keys.some((k) => k.startsWith(OLD_PREFIXES[0]));
		await Promise.all(keys.map((k) => caches.delete(k)));
		await self.clients.claim();
		if (hadOld) {
			// 古い版（Godot 生成 SW のキャッシュ）を表示している画面だけ読み直す
			const all = await self.clients.matchAll({ type: 'window' });
			all.forEach((c) => c.navigate(c.url));
		}
	})());
});
