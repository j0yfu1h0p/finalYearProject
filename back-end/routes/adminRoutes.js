const express = require('express');
const router = express.Router();
const adminController = require('../controllers/adminController');
const adminAuth = require('../middleware/adminAuth');
const roleCheck = require('../middleware/roleCheck');

// Dashboard
router.get('/stats', adminAuth, adminController.getDashboardStats);

// Admin profile
router.get('/profile', adminAuth, adminController.getProfile);
router.put('/change-password', adminAuth, adminController.changePassword);

// Driver management
router.get('/drivers/pending', adminAuth, adminController.getPendingRegistrations);
router.get('/drivers/search', adminAuth, adminController.searchDrivers);
router.get('/drivers/:id', adminAuth, adminController.getDriverDetails);
router.put('/drivers/:id/approve', adminAuth, adminController.approveDriver);
router.put('/drivers/:id/reject', adminAuth, adminController.rejectDriver);
router.get('/drivers', adminAuth, adminController.getAllDrivers);

// Customer management
router.get('/customers/search', adminAuth, adminController.searchCustomers);
router.get('/customers/:id', adminAuth, adminController.getCustomerDetails);

// Service Requests (Ride requests)
router.get('/requests/latest', adminAuth, adminController.getLatestRequests);
router.get('/requests', adminAuth, adminController.getServiceRequests);
router.get('/requests/:id', adminAuth, adminController.getServiceRequestById);

// Mechanic management
router.get('/mechanics/pending', adminAuth, adminController.getPendingMechanicRegistrations);
router.get('/mechanics/uncertain', adminAuth, adminController.getUncertainMechanicRegistrations);
router.get('/mechanics/rejected', adminAuth, adminController.getRejectedMechanicRegistrations);
router.get('/mechanics/approved', adminAuth, adminController.getApprovedMechanicRegistrations);


router.get('/mechanics/search', adminAuth, adminController.searchMechanics);
router.get('/mechanics/:id', adminAuth, adminController.getMechanicDetails);
router.put('/mechanics/:id/approve', adminAuth, adminController.approveMechanic);
router.put('/mechanics/:id/reject', adminAuth, adminController.rejectMechanic);
router.put('/mechanics/:id/pending', adminAuth, adminController.setPendingMechanic);
router.put('/mechanics/:id/uncertain', adminAuth, adminController.setUncertainMechanic);

router.get('/mechanics', adminAuth, adminController.getAllMechanics);





// Mechanic Service Requests
router.get('/mechanic-requests/latest', adminAuth, adminController.getLatestMechanicRequests);
router.get('/mechanic-requests', adminAuth, adminController.getMechanicServiceRequests);
router.get('/mechanic-requests/:id', adminAuth, adminController.getMechanicServiceRequestById);

// Activity logs
router.get('/activity-logs', adminAuth, adminController.getActivityLogs);

// Admin management
router.post('/admins', adminAuth, roleCheck(['superadmin']), adminController.createAdmin);
router.get('/admins', adminAuth, roleCheck(['superadmin']), adminController.getAllAdmins);
router.delete('/admins/:id', adminAuth, roleCheck(['superadmin']), adminController.deleteAdmin);
router.put('/admins/:id/role', adminAuth, roleCheck(['superadmin']), adminController.updateAdminRole);
router.put('/admins/:id/status', adminAuth, roleCheck(['superadmin']), adminController.updateAdminStatus);


module.exports = router;