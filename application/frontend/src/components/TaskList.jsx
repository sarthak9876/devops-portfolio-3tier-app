import React from 'react';

function TaskList({ tasks, onUpdate, onDelete }) {
  if (tasks.length === 0) {
    return <div className="empty-state">No tasks yet. Create one above!</div>;
  }

  const getPriorityColor = (priority) => {
    switch (priority) {
      case 'high': return '#f44336';
      case 'medium': return '#ff9800';
      case 'low': return '#4caf50';
      default: return '#757575';
    }
  };

  return (
    <div className="task-list">
      {tasks.map((task) => (
        <div key={task._id} className="task-card">
          <div className="task-header">
            <h3>{task.title}</h3>
            <span 
              className="priority-badge" 
              style={{ backgroundColor: getPriorityColor(task.priority) }}
            >
              {task.priority}
            </span>
          </div>
          <p className="task-description">{task.description}</p>
          <div className="task-footer">
            <select 
              value={task.status} 
              onChange={(e) => onUpdate(task._id, { status: e.target.value })}
              className="status-select"
            >
              <option value="todo">To Do</option>
              <option value="in-progress">In Progress</option>
              <option value="done">Done</option>
            </select>
            <button 
              onClick={() => onDelete(task._id)}
              className="delete-btn"
            >
              Delete
            </button>
          </div>
          <div className="task-meta">
            Created: {new Date(task.createdAt).toLocaleDateString()}
          </div>
        </div>
      ))}
    </div>
  );
}

export default TaskList;
