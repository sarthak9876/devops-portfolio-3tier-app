############################
# Stage 1: Build React app
############################

FROM node:20-alpine AS build
# Use Node 20 Alpine for building the frontend (small image).
# AS build: Name this stage "build".


WORKDIR /app
# Set work directory to app in image

COPY package*.json ./
# Copy package.json (and package-lock.json when present) for dependency installation.

RUN npm install
# Install all dependencies required for building the React app.

COPY . . 
# Copy rest of frontend dependencies required for building React App

ARG VITE_API_URL=http://localhost:5000
# ARG: Build-time argument, not persisted as runtime env var.
# Default VITE_API_URL if not overridden at build time.

ENV VITE_API_URL=$VITE_API_URL
# ENV: Set environment variable inside build stage.
# Vite will use this when building the app (import.meta.env.VITE_API_URL).

RUN npm run build
# Build the production-optimized static files (Vite output into dist/).

############################
# Stage 2: NGINX runtime
############################

FROM nginx:1.27-alpine AS runtime
# Use official NGINX Alpine image as lightweight web server.

COPY nginx.conf /etc/nginx/conf.d/default.conf
# Replace default NGINX site configuration with our custom config.

COPY --from=build /app/dist /usr/share/nginx/html
# Copy built static files from build stage into NGINX's web root.

EXPOSE 80
# Document that container listens on port 80.

CMD ["nginx","-g","daemon off;"]
# Start NGINX in foreground mode (required for Docker to keep container running).

