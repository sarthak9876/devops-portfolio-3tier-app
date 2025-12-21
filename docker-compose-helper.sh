#!/bin/bash
# Docker Compose Helper - Quick Commands Reference

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Docker Compose Helper ===${NC}"
echo ""

case "${1:-help}" in

  start)
    echo "🚀 Starting all services..."
    docker compose up -d
    echo ""
    echo -e "${GREEN}✅ Services started!${NC}"
    echo "Frontend: http://localhost:3000"
    echo "Backend:  http://localhost:5000"
    echo "MongoDB:  mongodb://localhost:27017"
    ;;

  stop)
    echo "🛑 Stopping all services (keeping data)..."
    docker compose down
    echo -e "${GREEN}✅ Stopped!${NC}"
    ;;

  restart)
    echo "🔄 Restarting all services..."
    docker compose restart
    echo -e "${GREEN}✅ Restarted!${NC}"
    ;;

  logs)
    SERVICE="${2:-}"
    if [ -z "$SERVICE" ]; then
      echo "📜 Showing logs from all services (Ctrl+C to exit)..."
      docker compose logs -f
    else
      echo "📜 Showing logs from $SERVICE (Ctrl+C to exit)..."
      docker compose logs -f "$SERVICE"
    fi
    ;;

  status)
    echo "📊 Service Status:"
    docker compose ps
    echo ""
    echo "💾 Volume Usage:"
    docker volume ls | grep taskmaster || echo "No volumes yet"
    ;;

  health)
    echo "🏥 Health Check Status:"
    docker compose ps --format "table {{.Service}}\t{{.Status}}\t{{.Health}}"
    ;;

  rebuild)
    echo "🔨 Rebuilding images..."
    docker compose build --no-cache
    echo -e "${GREEN}✅ Rebuild complete!${NC}"
    ;;

  clean)
    echo -e "${YELLOW}⚠️  This will DELETE all data (volumes)${NC}"
    read -p "Are you sure? (yes/no): " confirm
    if [ "$confirm" == "yes" ]; then
      echo "🧹 Cleaning up (removing containers + volumes)..."
      docker compose down -v
      docker system prune -f
      echo -e "${GREEN}✅ Cleaned!${NC}"
    else
      echo "Cancelled."
    fi
    ;;

  shell)
    SERVICE="${2:-backend}"
    echo "🐚 Opening shell in $SERVICE container..."
    docker compose exec "$SERVICE" sh
    ;;

  test)
    echo "🧪 Testing services..."
    echo ""
    
    echo -n "Backend health: "
    if curl -sf http://localhost:5000/health > /dev/null; then
      echo -e "${GREEN}✅ OK${NC}"
    else
      echo -e "${RED}❌ FAILED${NC}"
    fi
    
    echo -n "Frontend accessible: "
    if curl -sf http://localhost:3000 > /dev/null; then
      echo -e "${GREEN}✅ OK${NC}"
    else
      echo -e "${RED}❌ FAILED${NC}"
    fi
    
    echo -n "MongoDB connection: "
    if docker compose exec mongodb mongosh --quiet --eval "db.adminCommand('ping')" > /dev/null 2>&1; then
      echo -e "${GREEN}✅ OK${NC}"
    else
      echo -e "${RED}❌ FAILED${NC}"
    fi
    ;;

  help|*)
    echo "Usage: ./docker-compose-helper.sh [command] [options]"
    echo ""
    echo "Commands:"
    echo "  start       - Start all services"
    echo "  stop        - Stop all services (keep data)"
    echo "  restart     - Restart all services"
    echo "  logs [svc]  - View logs (optionally filter by service)"
    echo "  status      - Show service and volume status"
    echo "  health      - Show health check status"
    echo "  rebuild     - Rebuild images from scratch"
    echo "  clean       - Stop services and DELETE all data"
    echo "  shell [svc] - Open shell in service (default: backend)"
    echo "  test        - Test all services are responding"
    echo "  help        - Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./docker-compose-helper.sh start"
    echo "  ./docker-compose-helper.sh logs backend"
    echo "  ./docker-compose-helper.sh shell mongodb"
    ;;
esac
