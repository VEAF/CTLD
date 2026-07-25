import { svelte } from '@sveltejs/vite-plugin-svelte'
import { svelteTesting } from '@testing-library/svelte/vite'
import { defineConfig } from 'vitest/config'

// Dev: proxy /api to the FastAPI backend (uvicorn on :8000).
// Build: emit static assets into the Python package (served by FastAPI, ticket 07).
// svelteTesting() makes vitest resolve Svelte's browser build (not SSR) + auto-cleanup.
export default defineConfig({
  plugins: [svelte(), svelteTesting()],
  base: './',
  build: {
    outDir: '../ctld_tools/web/static',
    emptyOutDir: true,
  },
  server: {
    proxy: { '/api': 'http://127.0.0.1:8000' },
  },
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./src/test-setup.ts'],
  },
})
