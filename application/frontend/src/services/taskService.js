import axios from 'axios';

// ═══════════════════════════════════════════════════════
// TaskMaster API Service
// Uses relative URLs - nginx reverse proxy handles routing
// ═══════════════════════════════════════════════════════

// In Kubernetes: /api/* gets proxied by nginx to backend-service
// In local dev: /api/* goes to localhost:5000 (via docker-compose or proxy)
const API_BASE = '/api/v1';

console.log('🚀 TaskService initialized');
console.log('📡 API Base URL:', API_BASE);
console.log('🌐 Current origin:', window.location.origin);

// Create axios instance with default config
const apiClient = axios.create({
  baseURL: API_BASE,
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request interceptor (for debugging and future auth tokens)
apiClient.interceptors.request.use(
  (config) => {
    console.log(`📤 API Request: ${config.method?.toUpperCase()} ${config.url}`);
    return config;
  },
  (error) => {
    console.error('❌ Request Error:', error);
    return Promise.reject(error);
  }
);

// Response interceptor (for error handling)
apiClient.interceptors.response.use(
  (response) => {
    console.log(`✅ API Response: ${response.status} ${response.config.url}`);
    return response;
  },
  (error) => {
    if (error.response) {
      // Server responded with error status (4xx, 5xx)
      console.error(`❌ API Error ${error.response.status}:`, error.response.data);
    } else if (error.request) {
      // Request made but no response received
      console.error('❌ No response from server:', error.message);
    } else {
      // Error in request setup
      console.error('❌ Request setup error:', error.message);
    }
    return Promise.reject(error);
  }
);

// ═══════════════════════════════════════════════════════
// API Service Methods
// ═══════════════════════════════════════════════════════

const taskService = {
  /**
   * Health check endpoint
   * @returns {Promise<Object>} Health status
   */
  checkHealth: async () => {
    // Health endpoint is at /health (not /api/v1/health)
    const response = await axios.get('/health');
    return response.data;
  },

  /**
   * Get all tasks
   * @returns {Promise<Array>} List of tasks
   */
  getAllTasks: async () => {
    const response = await apiClient.get('/tasks');
    return response.data;
  },

  /**
   * Get single task by ID
   * @param {string} id - Task ID
   * @returns {Promise<Object>} Task object
   */
  getTask: async (id) => {
    const response = await apiClient.get(`/tasks/${id}`);
    return response.data;
  },

  /**
   * Create new task
   * @param {Object} taskData - Task data (title, description, status, priority)
   * @returns {Promise<Object>} Created task
   */
  createTask: async (taskData) => {
    const response = await apiClient.post('/tasks', taskData);
    return response.data;
  },

  /**
   * Update existing task
   * @param {string} id - Task ID
   * @param {Object} updates - Fields to update
   * @returns {Promise<Object>} Updated task
   */
  updateTask: async (id, updates) => {
    const response = await apiClient.put(`/tasks/${id}`, updates);
    return response.data;
  },

  /**
   * Delete task
   * @param {string} id - Task ID
   * @returns {Promise<Object>} Deletion confirmation
   */
  deleteTask: async (id) => {
    const response = await apiClient.delete(`/tasks/${id}`);
    return response.data;
  },
};

export default taskService;
