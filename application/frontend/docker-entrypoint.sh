#!/bin/sh
# Runtime environment variable injection for Vite apps
# This runs when the container starts, NOT at build time

set -e

# Default to localhost if not provided
API_URL=${VITE_API_URL:-http://localhost:5000}

echo "🔧 Injecting runtime configuration..."
echo "   VITE_API_URL=${API_URL}"

# Create a JavaScript file that the app will load at runtime
cat > /usr/share/nginx/html/runtime-config.js << RUNTIME_CONFIG
// Auto-generated at container startup
window.__RUNTIME_CONFIG__ = {
  API_URL: '${API_URL}',
  APP_TITLE: '${VITE_APP_TITLE:-TaskMaster}',
  ENVIRONMENT: '${NODE_ENV:-production}'
};

console.log('Runtime config loaded:', window.__RUNTIME_CONFIG__);
RUNTIME_CONFIG

echo "✅ Runtime configuration injected successfully"

# Execute the original NGINX entrypoint
exec nginx -g 'daemon off;'
