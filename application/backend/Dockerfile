############################
# Stage 1: Base dependencies
############################

FROM node:20-alpine AS base
# Using official Node 20 image based on Alpine Linux
# AS base: Give this stage a name ("base") so later stages can reuse it.

WORKDIR /app
# Set the WORKDIR to /app inside image

COPY package*.json ./
# COPY: Copy package.json and package-lock.json (if present) from host to container.
# Using package*.json lets Docker cache dependency installation if app code changes but dependencies don't.

############################
# Stage 2: Dependencies only
############################

FROM base AS deps
# This stage is based on base stage and we are giving the stage name of 'deps'

RUN npm ci --only=production
# RUN: Execute a command inside this build stage.
# npm ci: Clean install using package-lock.json (faster and reproducible).
# --only=production: Install only production dependencies (no devDependencies) to keep image smaller.

############################
# Stage 3: Development deps (optional for dev/test)
############################

FROM base AS dev-deps
# Separate stage if you ever need dev dependencies for tests or local debugging.

RUN npm install
# npm install: Install both prod and dev dependencies (for dev/test images, not used in final prod image).

############################
# Stage 4: Production runtime image
############################

FROM node:20-alpine AS runtime
# New stage for the final runtime image.
# Uses a clean Node 20 Alpine base (no build caches, only what we copy in).

ENV NODE_ENV=production
# ENV: Set environment variable inside container.
# NODE_ENV=production: Enables production optimizations in many Node libs.

WORKDIR /app
# Set work direcotry as /app inside the image

COPY --from=deps /app/node_modules ./node_modules
# COPY --from=deps: Copy files from another stage ("deps") into this stage.
# /app/node_modules: Source path inside deps stage.
# ./node_modules: Destination path inside current WORKDIR.
# This avoids reinstalling dependencies in the final image.

COPY . .
# Copy application source code

EXPOSE 5000
# EXPOSE: Document that container listens on port 5000 (API port).
# This is for humans and tools; it does NOT publish the port by itself.

CMD ["node","server.js"]
# CMD: Default command to run when container starts.
# ["node", "server.js"]: Use exec form, avoids shell, better signal handling.


