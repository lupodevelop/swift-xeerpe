import { defineConfig } from "astro/config";

// SITE and BASE let the same build go to any host or sub-path.
export default defineConfig({
  site: process.env.SITE,
  base: process.env.BASE ?? "/",
});
