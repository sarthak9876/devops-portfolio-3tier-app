# Database Configuration

## MongoDB Setup

This directory contains MongoDB initialization scripts and configuration.

### Files:
- `init-mongo.js`: Database initialization script (creates collections, indexes, sample data)

### Local Development:
Run MongoDB locally
```
docker run -d -p 27017:27017 --name mongodb mongo:7
```
Initialize database
```
docker exec -i mongodb mongosh taskmaster < init-mongo.js
```

### Docker Compose:
MongoDB will be automatically initialized when using Docker Compose.

### Kubernetes:
MongoDB will run as a StatefulSet with persistent volumes.
