import React, { useState } from 'react';

function TaskCard({ task, onUpdate, onDelete }) {
  const [isExpanded, setIsExpanded] = useState(false);

  const priorityConfig = {
    high: { color: '#ef4444', bg: '#fee2e2', icon: '🔴', label: 'HIGH' },
    medium: { color: '#f59e0b', bg: '#fef3c7', icon: '🟡', label: 'MEDIUM' },
    low: { color: '#6b7280', bg: '#f3f4f6', icon: '⚪', label: 'LOW' },
  };

  const config = priorityConfig[task.priority] || priorityConfig.medium;

  const handleStatusChange = (newStatus) => {
    onUpdate(task._id, { status: newStatus });
  };

  const handlePriorityChange = (newPriority) => {
    onUpdate(task._id, { priority: newPriority });
  };

  const formatDate = (dateString) => {
    const date = new Date(dateString);
    const now = new Date();
    const diffMs = now - date;
    const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));
    
    if (diffDays === 0) return 'Today';
    if (diffDays === 1) return 'Yesterday';
    if (diffDays < 7) return `${diffDays} days ago`;
    return date.toLocaleDateString();
  };

  return (
    <div 
      className="task-card"
      style={{ borderLeftColor: config.color }}
    >
      <div className="task-header">
        <div className="task-priority-badge" style={{ backgroundColor: config.bg, color: config.color }}>
          <span className="priority-icon">{config.icon}</span>
          <span className="priority-label">{config.label}</span>
        </div>
        
        <button 
          className="task-expand-btn"
          onClick={() => setIsExpanded(!isExpanded)}
          title={isExpanded ? 'Collapse' : 'Expand'}
        >
          {isExpanded ? '−' : '+'}
        </button>
      </div>

      <div className="task-content">
        <h3 className="task-title">{task.title}</h3>
        
        {task.description && (
          <p className="task-description">
            {isExpanded ? task.description : `${task.description.substring(0, 80)}${task.description.length > 80 ? '...' : ''}`}
          </p>
        )}
      </div>

      {isExpanded && (
        <div className="task-actions-expanded">
          <div className="action-group">
            <label>Status:</label>
            <select 
              value={task.status} 
              onChange={(e) => handleStatusChange(e.target.value)}
              className="task-select"
            >
              <option value="todo">📌 To Do</option>
              <option value="in-progress">🔄 In Progress</option>
              <option value="done">✅ Done</option>
            </select>
          </div>

          <div className="action-group">
            <label>Priority:</label>
            <select 
              value={task.priority} 
              onChange={(e) => handlePriorityChange(e.target.value)}
              className="task-select"
            >
              <option value="high">🔴 High</option>
              <option value="medium">🟡 Medium</option>
              <option value="low">⚪ Low</option>
            </select>
          </div>

          <button 
            onClick={() => onDelete(task._id)}
            className="btn-delete"
          >
            🗑️ Delete
          </button>
        </div>
      )}

      <div className="task-footer">
        <span className="task-date">📅 {formatDate(task.createdAt)}</span>
      </div>
    </div>
  );
}

export default TaskCard;
