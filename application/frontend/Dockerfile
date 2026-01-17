# ═══════════════════════════════════════════════════════
# TaskMaster Frontend Dockerfile
# Multi-stage build: Dependencies → Build → Production
# ═══════════════════════════════════════════════════════

############################
# Stage 1: Dependencies
############################
FROM node:20-alpine AS deps

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies (clean install for reproducibility)
RUN if [ -f package-lock.json ]; then \
      npm ci --only=production --ignore-scripts; \
    else \
      npm install --only=production --ignore-scripts; \
    fi

# Install dev dependencies for build
RUN npm install

# Clean npm cache
RUN npm cache clean --force

############################
# Stage 2: Build
############################
FROM node:20-alpine AS builder

WORKDIR /app

# Copy dependencies from deps stage
COPY --from=deps /app/node_modules ./node_modules

# Copy source code
COPY . .

# Build the app
# NO VITE_API_URL needed - we use relative URLs!
RUN npm run build

# List build output for debugging
RUN ls -lah /app/dist

############################
# Stage 3: Production (NGINX)
############################
FROM nginx:1.27-alpine AS production

# Install curl for health checks
RUN apk add --no-cache curl

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy built static files from builder stage
COPY --from=builder /app/dist /usr/share/nginx/html

# Verify files were copied
RUN ls -lah /usr/share/nginx/html

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost/nginx-health || exit 1

# Expose port 80
EXPOSE 80

# Start nginx in foreground
CMD ["nginx", "-g", "daemon off;"]

