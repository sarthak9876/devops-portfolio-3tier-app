const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 5000;

// ═══════════════════════════════════════════════════════
// Middleware
// ═══════════════════════════════════════════════════════

app.use(helmet()); // Security headers
app.use(cors({ origin: process.env.CORS_ORIGIN || '*' }));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(morgan('combined')); // Request logging

// Log all requests
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
  next();
});

// ═══════════════════════════════════════════════════════
// Task Schema & Model
// ═══════════════════════════════════════════════════════

const taskSchema = new mongoose.Schema({
  title: {
    type: String,
    required: [true, 'Title is required'],
    trim: true,
    maxlength: [100, 'Title cannot exceed 100 characters']
  },
  description: {
    type: String,
    trim: true,
    maxlength: [500, 'Description cannot exceed 500 characters']
  },
  status: {
    type: String,
    enum: ['todo', 'in-progress', 'completed', 'done'],
    default: 'todo'
  },
  priority: {
    type: String,
    enum: ['low', 'medium', 'high'],
    default: 'medium'
  },
  dueDate: {
    type: Date
  },
  createdAt: {
    type: Date,
    default: Date.now
  },
  updatedAt: {
    type: Date,
    default: Date.now
  }
});

// Update timestamp on save
taskSchema.pre('save', function(next) {
  this.updatedAt = Date.now();
  next();
});

const Task = mongoose.model('Task', taskSchema);

// ═══════════════════════════════════════════════════════
// Health Check Endpoints (Kubernetes Probes)
// ═══════════════════════════════════════════════════════

// Liveness probe - is the app alive?
app.get('/health', (req, res) => {
  const healthcheck = {
    status: 'OK',
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV || 'production',
    database: mongoose.connection.readyState === 1 ? 'connected' : 'disconnected'
  };
  
  const statusCode = healthcheck.database === 'connected' ? 200 : 503;
  res.status(statusCode).json(healthcheck);
});

// Readiness probe - is the app ready to serve traffic?
app.get('/ready', (req, res) => {
  if (mongoose.connection.readyState === 1) {
    res.status(200).json({ 
      status: 'ready', 
      database: 'connected',
      timestamp: new Date().toISOString()
    });
  } else {
    res.status(503).json({ 
      status: 'not ready', 
      database: 'disconnected',
      timestamp: new Date().toISOString()
    });
  }
});

// ═══════════════════════════════════════════════════════
// API Routes - /api/v1/tasks
// ═══════════════════════════════════════════════════════

// GET all tasks
app.get('/api/v1/tasks', async (req, res) => {
  try {
    const tasks = await Task.find().sort({ createdAt: -1 });
    res.json({
      success: true,
      count: tasks.length,
      data: tasks
    });
  } catch (error) {
    console.error('❌ Error fetching tasks:', error);
    res.status(500).json({ 
      success: false, 
      error: 'Failed to fetch tasks' 
    });
  }
});

// GET single task by ID
app.get('/api/v1/tasks/:id', async (req, res) => {
  try {
    const task = await Task.findById(req.params.id);
    
    if (!task) {
      return res.status(404).json({ 
        success: false, 
        error: 'Task not found' 
      });
    }
    
    res.json({ success: true, data: task });
  } catch (error) {
    console.error('❌ Error fetching task:', error);
    res.status(500).json({ 
      success: false, 
      error: 'Failed to fetch task' 
    });
  }
});

// POST create new task
app.post('/api/v1/tasks', async (req, res) => {
  try {
    const task = await Task.create(req.body);
    
    console.log('✅ Task created:', task._id);
    
    res.status(201).json({ 
      success: true, 
      data: task 
    });
  } catch (error) {
    console.error('❌ Error creating task:', error);
    
    // Handle validation errors
    if (error.name === 'ValidationError') {
      return res.status(400).json({ 
        success: false, 
        error: error.message 
      });
    }
    
    res.status(500).json({ 
      success: false, 
      error: 'Failed to create task' 
    });
  }
});

// PUT update task
app.put('/api/v1/tasks/:id', async (req, res) => {
  try {
    // Explicitly set updatedAt
    req.body.updatedAt = Date.now();
    
    const task = await Task.findByIdAndUpdate(
      req.params.id, 
      req.body, 
      {
        new: true,           // Return updated document
        runValidators: true  // Run schema validators
      }
    );
    
    if (!task) {
      return res.status(404).json({ 
        success: false, 
        error: 'Task not found' 
      });
    }
    
    console.log('✅ Task updated:', task._id);
    
    res.json({ success: true, data: task });
  } catch (error) {
    console.error('❌ Error updating task:', error);
    
    if (error.name === 'ValidationError') {
      return res.status(400).json({ 
        success: false, 
        error: error.message 
      });
    }
    
    res.status(500).json({ 
      success: false, 
      error: 'Failed to update task' 
    });
  }
});

// DELETE task
app.delete('/api/v1/tasks/:id', async (req, res) => {
  try {
    const task = await Task.findByIdAndDelete(req.params.id);
    
    if (!task) {
      return res.status(404).json({ 
        success: false, 
        error: 'Task not found' 
      });
    }
    
    console.log('✅ Task deleted:', task._id);
    
    res.json({ 
      success: true, 
      message: 'Task deleted successfully',
      data: task 
    });
  } catch (error) {
    console.error('❌ Error deleting task:', error);
    res.status(500).json({ 
      success: false, 
      error: 'Failed to delete task' 
    });
  }
});

// ═══════════════════════════════════════════════════════
// 404 Handler
// ═══════════════════════════════════════════════════════

app.use((req, res) => {
  res.status(404).json({ 
    success: false,
    error: 'Route not found',
    path: req.path,
    method: req.method
  });
});

// ═══════════════════════════════════════════════════════
// Global Error Handler
// ═══════════════════════════════════════════════════════

app.use((err, req, res, next) => {
  console.error('❌ Unhandled error:', err);
  res.status(err.status || 500).json({ 
    success: false,
    error: 'Internal server error',
    message: process.env.NODE_ENV === 'development' ? err.message : undefined
  });
});

// ═══════════════════════════════════════════════════════
// Database Connection with Retry Logic
// (Critical for container startup where MongoDB might not be ready)
// ═══════════════════════════════════════════════════════

const connectDB = async (retries = 5) => {
  // IMPORTANT: MONGO_URI comes from Kubernetes Secret (no hardcoded values!)
  const mongoURI = process.env.MONGO_URI;
  
  if (!mongoURI) {
    console.error('❌ MONGO_URI environment variable is not set');
    console.error('   This should be injected via Kubernetes Secret');
    process.exit(1);
  }
  
  // Sanitize URI for logging (hide password)
  const sanitizedURI = mongoURI.replace(/:[^:]*@/, ':****@');
  console.log(`🔌 Connecting to MongoDB: ${sanitizedURI}`);
  
  for (let i = 0; i < retries; i++) {
    try {
      await mongoose.connect(mongoURI, {
        useNewUrlParser: true,
        useUnifiedTopology: true,
        serverSelectionTimeoutMS: 5000,
      });
      
      console.log(`✅ MongoDB Connected: ${mongoose.connection.host}`);
      console.log(`   Database: ${mongoose.connection.name}`);
      return;
      
    } catch (error) {
      console.error(`❌ MongoDB connection attempt ${i + 1}/${retries} failed:`, error.message);
      
      if (i < retries - 1) {
        const waitTime = 5;
        console.log(`⏳ Retrying in ${waitTime} seconds...`);
        await new Promise(resolve => setTimeout(resolve, waitTime * 1000));
      }
    }
  }
  
  console.error('❌ Could not connect to MongoDB after multiple attempts');
  console.error('   Check if MongoDB service is running and MONGO_URI is correct');
  process.exit(1);
};

// ═══════════════════════════════════════════════════════
// Start Server
// ═══════════════════════════════════════════════════════

const startServer = async () => {
  await connectDB();
  
  app.listen(PORT, '0.0.0.0', () => {
    console.log('═══════════════════════════════════════════════════════');
    console.log('🚀 TaskMaster Backend Server');
    console.log('═══════════════════════════════════════════════════════');
    console.log(`   Port: ${PORT}`);
    console.log(`   Environment: ${process.env.NODE_ENV || 'production'}`);
    console.log(`   Health: http://localhost:${PORT}/health`);
    console.log(`   Ready: http://localhost:${PORT}/ready`);
    console.log(`   API: http://localhost:${PORT}/api/v1/tasks`);
    console.log('═══════════════════════════════════════════════════════');
  });
};

// Start the server
startServer();

// ═══════════════════════════════════════════════════════
// Graceful Shutdown (Kubernetes SIGTERM handling)
// ═══════════════════════════════════════════════════════

process.on('SIGTERM', () => {
  console.log('⚠️  SIGTERM received, shutting down gracefully...');
  
  mongoose.connection.close(false, () => {
    console.log('✅ MongoDB connection closed');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('\n⚠️  SIGINT received, shutting down gracefully...');
  
  mongoose.connection.close(false, () => {
    console.log('✅ MongoDB connection closed');
    process.exit(0);
  });
});
