import React from 'react';
import TaskCard from './TaskCard';

function TaskBoard({ tasks, onUpdate, onDelete }) {
  // Sort tasks by priority (high -> medium -> low)
  const priorityOrder = { high: 1, medium: 2, low: 3 };
  
  const sortByPriority = (taskList) => {
    return [...taskList].sort((a, b) => {
      const priorityDiff = priorityOrder[a.priority] - priorityOrder[b.priority];
      if (priorityDiff !== 0) return priorityDiff;
      // If same priority, sort by creation date (newest first)
      return new Date(b.createdAt) - new Date(a.createdAt);
    });
  };

  const todoTasks = sortByPriority(tasks.filter(t => t.status === 'todo'));
  const inProgressTasks = sortByPriority(tasks.filter(t => t.status === 'in-progress'));
  const doneTasks = sortByPriority(tasks.filter(t => t.status === 'done'));

  const renderColumn = (title, taskList, status, icon, color) => (
    <div className="board-column">
      <div className="column-header" style={{ borderTopColor: color }}>
        <div className="column-title">
          <span className="column-icon">{icon}</span>
          <h2>{title}</h2>
        </div>
        <span className="task-count">{taskList.length}</span>
      </div>
      
      <div className="column-content">
        {taskList.length === 0 ? (
          <div className="empty-column">
            <p>No tasks</p>
          </div>
        ) : (
          taskList.map(task => (
            <TaskCard
              key={task._id}
              task={task}
              onUpdate={onUpdate}
              onDelete={onDelete}
            />
          ))
        )}
      </div>
    </div>
  );

  return (
    <div className="task-board">
      {renderColumn('To Do', todoTasks, 'todo', '📌', '#3b82f6')}
      {renderColumn('In Progress', inProgressTasks, 'in-progress', '🔄', '#f59e0b')}
      {renderColumn('Done', doneTasks, 'done', '✅', '#10b981')}
    </div>
  );
}

export default TaskBoard;
