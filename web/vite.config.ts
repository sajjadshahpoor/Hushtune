import { defineConfig } from 'vite';
import { VitePWA } from 'vite-plugin-pwa';

// Served from GitHub Pages at https://sajjadshahpoor.github.io/Hushtune/app/
// (the repo's Pages site is published from /docs).
export default defineConfig({
  base: '/Hushtune/app/',
  build: { outDir: '../docs/app', emptyOutDir: true },
  // ffmpeg.wasm spawns its own worker and breaks when pre-bundled.
  optimizeDeps: { exclude: ['@ffmpeg/ffmpeg', '@ffmpeg/util'] },
  plugins: [
    VitePWA({
      registerType: 'autoUpdate',
      pwaAssets: { image: 'public/icon.svg', overrideManifestIcons: true },
      manifest: {
        name: 'Hushtune',
        short_name: 'Hushtune',
        description: 'Save audio and video files to your iPhone.',
        display: 'standalone',
        background_color: '#0b0b0d',
        theme_color: '#0b0b0d',
      },
      workbox: { globPatterns: ['**/*.{js,css,html,svg,png,ico}'] },
    }),
  ],
});
