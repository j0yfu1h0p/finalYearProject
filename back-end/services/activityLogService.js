const ActivityLog = require('../models/ActivityLog');

const logActivity = async (options) => {
  try {
    const logData = {
      action: options.action,
      description: options.description,
      entityType: options.entityType,
      entityId: options.entityId,
      performedBy: options.performedBy,
      userType: options.userType || 'Admin',
      metadata: options.metadata,
      isError: options.isError || false,
      errorDetails: options.errorDetails,
    };
    const activity = new ActivityLog(logData);
    await activity.save();
  } catch (error) {

  }
};

module.exports = {
  logActivity,
};
