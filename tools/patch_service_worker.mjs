// Hace que una versión nueva de la app instalada tome el control enseguida. El service worker que genera Godot deja la
// nueva "esperando" hasta que se cierren todas las ventanas del juego, y en iPhone (app en la pantalla de inicio o
// pestaña de Safari que nunca se cierra) eso puede no pasar: la gente se quedaba en la versión vieja. Como el arreglo
// va en el service worker nuevo, también destraba a quienes ya estaban atascados.
//
//   node tools/patch_service_worker.mjs <carpeta del export>/index.service.worker.js
//
// Lo corre el flujo de GitHub Pages sobre cada export (tomando este archivo de main, sea cual sea la etiqueta).
import fs from 'node:fs';

const MARK = '// pozo-profundo: actualización inmediata';
const PATCH = `
${MARK}
// Si había una versión anterior, se la reemplaza ya y se recargan las ventanas abiertas (la partida se guarda al irse
// la página). En la primera instalación no hay ventanas controladas y no se recarga nada.
self.addEventListener('install', () => { self.skipWaiting(); });
self.addEventListener('activate', (event) => {
	event.waitUntil(self.clients.matchAll({ type: 'window' }).then((windows) => {
		// Sin esperar a navigate(): la navegación no avanza hasta que termina la activación.
		windows.forEach((client) => {
			if (client.navigate) {
				client.navigate(client.url).catch(() => {});
			}
		});
	}));
});
`;

const file = process.argv[2];
if (!file) {
	throw new Error('Falta la ruta del service worker.');
}
const text = fs.readFileSync(file, 'utf8');
// Si Godot cambia su plantilla, mejor que el flujo falle antes que publicar sin el arreglo.
if (!text.includes("self.addEventListener('install'") || !text.includes('CACHE_VERSION')) {
	throw new Error(`${file} no parece el service worker de Godot.`);
}
if (text.includes(MARK)) {
	console.log('El service worker ya tenía el arreglo.');
} else {
	fs.writeFileSync(file, text + PATCH);
	console.log('Service worker con actualización inmediata.');
}
