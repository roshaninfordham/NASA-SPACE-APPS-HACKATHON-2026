import { defineConfig } from "vite";
export default defineConfig({
  base: "./",
  build: {
    rollupOptions: { output: { manualChunks: { graphics: ["three"] } } },
  },
  server: { host: "0.0.0.0", strictPort: true },
});
