// MongoDB initialization script
// Creates database, collections, and indexes

db = db.getSiblingDB('taskmaster');

// Create tasks collection with validation
db.createCollection('tasks', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['title', 'status'],
      properties: {
        title: {
          bsonType: 'string',
          description: 'Task title is required'
        },
        description: {
          bsonType: 'string',
          description: 'Task description'
        },
        status: {
          enum: ['todo', 'in-progress', 'done'],
          description: 'Task status must be one of: todo, in-progress, done'
        },
        priority: {
          enum: ['low', 'medium', 'high'],
          description: 'Task priority must be one of: low, medium, high'
        }
      }
    }
  }
});

// Create indexes for better query performance
db.tasks.createIndex({ createdAt: -1 });
db.tasks.createIndex({ status: 1 });
db.tasks.createIndex({ priority: 1 });

// Insert sample data for testing
db.tasks.insertMany([
  {
    title: 'Setup AWS Infrastructure',
    description: 'Configure VPC, subnets, and security groups using Terraform',
    status: 'in-progress',
    priority: 'high',
    createdAt: new Date(),
    updatedAt: new Date()
  },
  {
    title: 'Deploy Kubernetes Cluster',
    description: 'Use kubeadm to bootstrap K8s cluster on EC2 instances',
    status: 'todo',
    priority: 'high',
    createdAt: new Date(),
    updatedAt: new Date()
  },
  {
    title: 'Configure CI/CD Pipeline',
    description: 'Setup GitHub Actions for automated deployments',
    status: 'todo',
    priority: 'medium',
    createdAt: new Date(),
    updatedAt: new Date()
  },
  {
    title: 'Setup Monitoring Stack',
    description: 'Deploy Prometheus and Grafana for observability',
    status: 'todo',
    priority: 'medium',
    createdAt: new Date(),
    updatedAt: new Date()
  }
]);

print('✅ Database initialized successfully!');
print(`📊 Inserted ${db.tasks.countDocuments()} sample tasks`);
