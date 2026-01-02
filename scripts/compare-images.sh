#!/bin/bash
# Compare image sizes before/after optimization

echo "Building images for comparison..."

# Build single-stage (naive)
cat > Dockerfile.naive << 'DOCKERFILE'
FROM node:20
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 5000
CMD ["node", "server.js"]
DOCKERFILE

echo "Step 1/2: Building Naive Image..."
docker build -f Dockerfile.naive -t taskmaster-backend:naive . --quiet > /dev/null

# Build optimized
echo "Step 2/2: Building Optimized Image..."
docker build -f Dockerfile.optimized -t taskmaster-backend:optimized . --quiet > /dev/null

echo ""
echo "=== IMAGE SIZE COMPARISON ==="
echo ""
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | grep -E "REPOSITORY|taskmaster-backend"
echo ""

# --- LOGIC START ---
# 1. Get RAW BYTES for accurate calculation
NAIVE_BYTES=$(docker inspect -f "{{ .Size }}" taskmaster-backend:naive 2>/dev/null || echo 0)
OPTIMIZED_BYTES=$(docker inspect -f "{{ .Size }}" taskmaster-backend:optimized 2>/dev/null || echo 0)

# 2. Get READABLE SIZE for display (e.g., "1.2GB" or "400MB")
NAIVE_DISPLAY=$(docker images taskmaster-backend:naive --format "{{.Size}}")
OPTIMIZED_DISPLAY=$(docker images taskmaster-backend:optimized --format "{{.Size}}")

if [ "$NAIVE_BYTES" -gt 0 ] && [ "$OPTIMIZED_BYTES" -gt 0 ]; then
    SAVINGS=$(echo "scale=2; 100 - ($OPTIMIZED_BYTES / $NAIVE_BYTES * 100)" | bc)
    
    # New display line using the readable variables
    echo "📉 Size Reduction: Naive ($NAIVE_DISPLAY) → Optimized ($OPTIMIZED_DISPLAY)"
    echo "💰 Space savings:  ${SAVINGS}%"
else
    echo "⚠️  Error: Could not calculate size."
fi
# --- LOGIC END ---

echo ""
echo "=== LAYER COUNT ==="
echo ""
echo "Naive (single-stage):"
docker history taskmaster-backend:naive --no-trunc 2>/dev/null | wc -l
echo ""
echo "Optimized (multi-stage):"
docker history taskmaster-backend:optimized --no-trunc 2>/dev/null | wc -l
echo ""

echo "✅ Optimization complete!"
