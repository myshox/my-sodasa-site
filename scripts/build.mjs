import { cp, mkdir, readdir, rm, writeFile } from "node:fs/promises";
import { extname, join } from "node:path";
const root = process.cwd(), dist = join(root, "dist"), client = join(dist, "client");
const publicDirs = ["images", "music"];
const publicExtensions = new Set([".html", ".json", ".xml", ".txt", ".js"]);
const publicFiles = new Set(["_headers", "_redirects", ".htaccess"]);
await rm(dist, { recursive: true, force: true }); await mkdir(client, { recursive: true });
for (const directory of publicDirs) await cp(join(root, directory), join(client, directory), { recursive: true });
for (const entry of await readdir(root, { withFileTypes: true })) {
  if (entry.isFile() && (publicExtensions.has(extname(entry.name)) || publicFiles.has(entry.name))) await cp(join(root, entry.name), join(client, entry.name));
}
await mkdir(join(dist, "server"), { recursive: true });
await writeFile(join(dist, "server", "index.js"), `export default { async fetch(request, env) { return env.ASSETS.fetch(request); } };\n`);
