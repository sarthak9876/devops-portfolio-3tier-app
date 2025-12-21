import axios from 'axios';

// Try runtime config first, fallback to build-time env var, then localhost
const getApiUrl = () => {
  // Runtime config (injected by docker-entrypoint.sh)
  if (window.__RUNTIME_CONFIG__?.API_URL) {
    console.log('Using runtime config API URL:', window.__RUNTIME_CONFIG__.API_URL);
    return window.__RUNTIME_CONFIG__.API_URL;
  }
  
  // Build-time env var (Vite)
  if (import.meta.env.VITE_API_URL) {
    console.log('Using build-time API URL:', import.meta.env.VITE_API_URL);
    return import.meta.env.VITE_API_URL;
  }
  
  // Fallback to localhost
  console.log('Using fallback API URL: http://localhost:5000');
  return 'http://localhost:5000';
};

const API_URL = getApiUrl();
const API_BASE = `${API_URL}/api/v1`;

console.log('TaskService initialized with API_BASE:', API_BASE);

const taskService = {
  // Health check
  checkHealth: async () => {
    const response = await axios.get(`${API_URL}/health`);
    return response.data;
  },

  // Get all tasks
  getAllTasks: async () => {
    const response = await axios.get(`${API_BASE}/tasks`);
    return response.data;
  },

  // Get single task
  getTask: async (id) => {
    const response = await axios.get(`${API_BASE}/tasks/${id}`);
    return response.data;
  },

  // Create task
  createTask: async (taskData) => {
    const response = await axios.post(`${API_BASE}/tasks`, taskData);
    return response.data;
  },

  // Update task
  updateTask: async (id, updates) => {
    const response = await axios.put(`${API_BASE}/tasks/${id}`, updates);
    return response.data;
  },

  // Delete task
  deleteTask: async (id) => {
    const response = await axios.delete(`${API_BASE}/tasks/${id}`);
    return response.data;
  }
};

export default taskService;
