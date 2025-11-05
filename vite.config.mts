import { defineConfig } from 'vite'
import RubyPlugin from 'vite-plugin-ruby'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [
    RubyPlugin(),
    react({
      // Use classic runtime to avoid preamble issues
      jsxRuntime: 'classic',
      fastRefresh: false,
    }),
  ],
})
