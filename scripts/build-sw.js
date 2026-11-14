import { readdir, readFile, writeFile } from "node:fs/promises";
import { createHash } from "node:crypto";
const files = [
  "index.html",
  "icon.svg",
  "manifest.webmanifest",
  ...(await readdir("dist/assets")).map((f) => "assets/" + f),
];
const hash = createHash("sha256");
for (const f of files) hash.update(await readFile("dist/" + f));
const version = "red-veil-" + hash.digest("hex").slice(0, 16);
await writeFile(
  "dist/sw.js",
  `
const CACHE=${JSON.stringify(version)};
const FILES=${JSON.stringify(files)};
self.addEventListener('install',event=>event.waitUntil(caches.open(CACHE).then(cache=>cache.addAll(FILES))));
self.addEventListener('activate',event=>event.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(key=>key.startsWith('red-veil-')&&key!==CACHE).map(key=>caches.delete(key)))).then(()=>self.clients.claim())));
self.addEventListener('fetch',event=>{
 const url=new URL(event.request.url);
 if(event.request.method!=='GET'||url.origin!==self.location.origin)return;
 event.respondWith(caches.match(event.request).then(cached=>cached||fetch(event.request).catch(error=>{
  if(event.request.mode==='navigate')return caches.match(new URL('index.html',self.registration.scope));
  throw error;
 })));
});
`,
);
console.log(`Offline cache: ${files.length} files, ${version}`);
