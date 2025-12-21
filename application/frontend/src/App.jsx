import React, { useState, useEffect } from 'react';
import taskService from './services/taskService';
import TaskBoard from './components/TaskBoard';
import TaskForm from './components/TaskForm';
import './styles/App.css';

function App() {
  const [tasks, setTasks] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [healthStatus, setHealthStatus] = useState(null);
  const [showAddForm, setShowAddForm] = useState(false);
  const [stats, setStats] = useState({ todo: 0, inProgress: 0, done: 0 });

  // Fetch tasks on component mount
  useEffect(() => {
    fetchTasks();
    checkHealth();
  }, []);

  // Update stats when tasks change
  useEffect(() => {
    calculateStats();
  }, [tasks]);

  const fetchTasks = async () => {
    try {
      setLoading(true);
      const data = await taskService.getAllTasks();
      setTasks(data.data);
      setError(null);
    } catch (err) {
      setError('Failed to fetch tasks. Please check if backend is running.');
      console.error('Error fetching tasks:', err);
    } finally {
      setLoading(false);
    }
  };

  const checkHealth = async () => {
    try {
      const health = await taskService.checkHealth();
      setHealthStatus(health);
    } catch (err) {
      console.error('Health check failed:', err);
      setHealthStatus({ message: 'Offline', database: 'disconnected' });
    }
  };

  const calculateStats = () => {
    const newStats = {
      todo: tasks.filter(t => t.status === 'todo').length,
      inProgress: tasks.filter(t => t.status === 'in-progress').length,
      done: tasks.filter(t => t.status === 'done').length,
    };
    setStats(newStats);
  };

  const handleCreateTask = async (taskData) => {
    try {
      await taskService.createTask(taskData);
      await fetchTasks();
      setShowAddForm(false);
    } catch (err) {
      setError('Failed to create task');
      console.error('Error creating task:', err);
    }
  };

  const handleUpdateTask = async (id, updates) => {
    try {
      await taskService.updateTask(id, updates);
      await fetchTasks();
    } catch (err) {
      setError('Failed to update task');
      console.error('Error updating task:', err);
    }
  };

  const handleDeleteTask = async (id) => {
    if (!window.confirm('Are you sure you want to delete this task?')) {
      return;
    }
    try {
      await taskService.deleteTask(id);
      await fetchTasks();
    } catch (err) {
      setError('Failed to delete task');
      console.error('Error deleting task:', err);
    }
  };

  return (
    <div className="app">
      <header className="app-header">
        <div className="header-content">
          <div className="header-title">
            <h1>📋 TaskMaster</h1>
            <p className="subtitle">DevOps Portfolio - 3-Tier Kubernetes Deployment on AWS</p>
          </div>
          
          {healthStatus && (
            <div className="health-status">
              <div className="health-indicator">
                <span 
                  className="status-dot" 
                  style={{ backgroundColor: healthStatus.database === 'connected' ? '#10b981' : '#ef4444' }}
                ></span>
                <span className="status-text">Backend: {healthStatus.message}</span>
              </div>
              <div className="health-indicator">
                <span 
                  className="status-dot" 
                  style={{ backgroundColor: healthStatus.database === 'connected' ? '#10b981' : '#ef4444' }}
                ></span>
                <span className="status-text">Database: {healthStatus.database}</span>
              </div>
            </div>
          )}
        </div>

        <div className="stats-bar">
          <div className="stat-item">
            <span className="stat-number">{stats.todo}</span>
            <span className="stat-label">To Do</span>
          </div>
          <div className="stat-item">
            <span className="stat-number">{stats.inProgress}</span>
            <span className="stat-label">In Progress</span>
          </div>
          <div className="stat-item">
            <span className="stat-number">{stats.done}</span>
            <span className="stat-label">Done</span>
          </div>
          <div className="stat-item">
            <span className="stat-number">{tasks.length}</span>
            <span className="stat-label">Total</span>
          </div>
        </div>
      </header>

      <main className="app-main">
        {error && (
          <div className="error-banner">
            <span className="error-icon">⚠️</span>
            <span>{error}</span>
            <button onClick={() => setError(null)} className="error-close">×</button>
          </div>
        )}
        
        <div className="actions-bar">
          <button 
            className="btn-primary"
            onClick={() => setShowAddForm(!showAddForm)}
          >
            {showAddForm ? '✕ Cancel' : '+ Add New Task'}
          </button>
          
          <button className="btn-secondary" onClick={fetchTasks}>
            🔄 Refresh
          </button>
        </div>

        {showAddForm && (
          <div className="task-form-container">
            <h2>Create New Task</h2>
            <TaskForm onSubmit={handleCreateTask} onCancel={() => setShowAddForm(false)} />
          </div>
        )}

        {loading ? (
          <div className="loading-state">
            <div className="spinner"></div>
            <p>Loading tasks...</p>
          </div>
        ) : (
          <TaskBoard 
            tasks={tasks} 
            onUpdate={handleUpdateTask}
            onDelete={handleDeleteTask}
          />
        )}
      </main>

      <footer className="app-footer">
        <div className="footer-content">
          <p>Built with React + Node.js + MongoDB | Deployed on Kubernetes | AWS Free Tier</p>
          <p className="footer-tech">
            Docker • Terraform • Ansible • GitHub Actions • Prometheus • Grafana
          </p>
        </div>
      </footer>
    </div>
  );
}

export default App;
