import React, { useState } from 'react';

function TaskForm({ onSubmit, onCancel }) {
  const [formData, setFormData] = useState({
    title: '',
    description: '',
    status: 'todo',
    priority: 'medium'
  });

  const handleSubmit = (e) => {
    e.preventDefault();
    if (!formData.title.trim()) {
      alert('Task title is required');
      return;
    }
    onSubmit(formData);
    setFormData({ title: '', description: '', status: 'todo', priority: 'medium' });
  };

  const handleChange = (e) => {
    setFormData({
      ...formData,
      [e.target.name]: e.target.value
    });
  };

  return (
    <form onSubmit={handleSubmit} className="task-form-modern">
      <div className="form-group">
        <label htmlFor="title">Task Title *</label>
        <input
          type="text"
          id="title"
          name="title"
          placeholder="e.g., Deploy Kubernetes cluster on AWS"
          value={formData.title}
          onChange={handleChange}
          required
          autoFocus
        />
      </div>

      <div className="form-group">
        <label htmlFor="description">Description</label>
        <textarea
          id="description"
          name="description"
          placeholder="Provide details about the task..."
          value={formData.description}
          onChange={handleChange}
          rows="4"
        />
      </div>

      <div className="form-row">
        <div className="form-group">
          <label htmlFor="status">Status</label>
          <select 
            id="status"
            name="status" 
            value={formData.status} 
            onChange={handleChange}
          >
            <option value="todo">📌 To Do</option>
            <option value="in-progress">🔄 In Progress</option>
            <option value="done">✅ Done</option>
          </select>
        </div>

        <div className="form-group">
          <label htmlFor="priority">Priority</label>
          <select 
            id="priority"
            name="priority" 
            value={formData.priority} 
            onChange={handleChange}
          >
            <option value="low">⚪ Low Priority</option>
            <option value="medium">🟡 Medium Priority</option>
            <option value="high">🔴 High Priority</option>
          </select>
        </div>
      </div>

      <div className="form-actions">
        <button type="submit" className="btn-submit">
          Create Task
        </button>
        {onCancel && (
          <button type="button" onClick={onCancel} className="btn-cancel">
            Cancel
          </button>
        )}
      </div>
    </form>
  );
}

export default TaskForm;
