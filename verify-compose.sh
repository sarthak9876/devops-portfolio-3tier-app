#!/bin/bash

echo "=== Docker Compose Verification ==="
echo ""

echo "1. Containers Running:"
docker compose ps --format "table {{.Service}}\t{{.Status}}\t{{.Ports}}"
echo ""

echo "2. Health Status:"
docker compose ps --format "table {{.Service}}\t{{.Health}}"
echo ""

echo "3. Backend Health:"
curl -s http://localhost:5000/health || echo "FAILED"
echo ""

echo "4. Frontend Accessible:"
curl -s -I http://localhost:3000 | head -n 1
echo ""

echo "5. Database Connection:"
docker compose exec mongodb mongosh --quiet --eval "db.adminCommand('ping')" || echo "FAILED"
echo ""

echo "6. Volumes:"
docker volume ls | grep taskmaster
echo ""

echo "7. Networks:"
docker network ls | grep taskmaster
echo ""

echo "✅ Verification complete!"
