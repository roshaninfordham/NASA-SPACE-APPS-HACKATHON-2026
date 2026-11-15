import fs from "node:fs";
const root = new URL("../", import.meta.url);
const openspace = JSON.parse(
  fs.readFileSync(new URL("data/openspace.json", root), "utf8"),
);
const history = JSON.parse(
  fs.readFileSync(new URL("data/history.json", root), "utf8"),
);
if (
  openspace.radii_m.some((r) => r !== 3396190) ||
  history.license_mode !== "apache"
)
  throw Error("Unexpected provenance; review sources before publishing.");
fs.writeFileSync(
  new URL("src/data.js", root),
  "export const CONTEXT = " + JSON.stringify({ openspace, history }) + ";\n",
);
