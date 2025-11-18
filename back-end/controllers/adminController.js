const Driver = require('../models/Driver');
    const ServiceRequest = require('../models/ServiceRequest');
    const Customer = require('../models/Customer');
    const { logActivity } = require('../services/activityLogService');
    const Admin = require('../models/Admin');
    const Mechanic = require('../models/Mechanic'); // Added missing import
    const MechanicServiceRequest = require('../models/MechanicServiceRequest'); // Added missing import
    const mongoose = require('mongoose');
    
    // Get dashboard statistics
    // Enhanced getDashboardStats function
    exports.getDashboardStats = async (req, res) => {
        try {
            const startOfMonth = new Date();
            startOfMonth.setDate(1);
            startOfMonth.setHours(0, 0, 0, 0);
    
            const startOfYear = new Date();
            startOfYear.setMonth(0, 1);
            startOfYear.setHours(0, 0, 0, 0);
    
            const [
                totalDrivers,
                pendingDrivers,
                activeRequests,
                completedRequests,
                totalCustomers,
                monthlyRevenue,
                yearlyRevenue,
                allTimeRevenue,
                // Mechanic-related stats
                totalMechanics,
                pendingMechanics,
                activeMechanicRequests,
                completedMechanicRequests,
                monthlyMechanicRevenue,
                yearlyMechanicRevenue,
                allTimeMechanicRevenue
            ] = await Promise.all([
                // Driver stats
                Driver.countDocuments(),
                Driver.countDocuments({ 'personal_info.registration_status': 'pending' }),
                ServiceRequest.countDocuments({ status: 'accepted' }),
                ServiceRequest.countDocuments({ status: 'completed' }),
                Customer.countDocuments(),
                ServiceRequest.aggregate([
                    { $match: { status: 'completed', createdAt: { $gte: startOfMonth } } },
                    { $group: { _id: null, total: { $sum: '$totalAmount' } } }
                ]),
                ServiceRequest.aggregate([
                    { $match: { status: 'completed', createdAt: { $gte: startOfYear } } },
                    { $group: { _id: null, total: { $sum: '$totalAmount' } } }
                ]),
                ServiceRequest.aggregate([
                    { $match: { status: 'completed' } },
                    { $group: { _id: null, total: { $sum: '$totalAmount' } } }
                ]),
    
                // Mechanic stats
                Mechanic.countDocuments(),
                Mechanic.countDocuments({ registrationStatus: 'pending' }),
                MechanicServiceRequest.countDocuments({
                    status: { $in: ['accepted', 'arrived', 'in-progress'] }
                }),
                MechanicServiceRequest.countDocuments({ status: 'completed' }),
                MechanicServiceRequest.aggregate([
                    { $match: { status: 'completed', createdAt: { $gte: startOfMonth } } },
                    { $group: { _id: null, total: { $sum: '$priceQuote.amount' } } }
                ]),
                MechanicServiceRequest.aggregate([
                    { $match: { status: 'completed', createdAt: { $gte: startOfYear } } },
                    { $group: { _id: null, total: { $sum: '$priceQuote.amount' } } }
                ]),
                MechanicServiceRequest.aggregate([
                    { $match: { status: 'completed' } },
                    { $group: { _id: null, total: { $sum: '$priceQuote.amount' } } }
                ])
            ]);
    
            // Get recent activity counts
            const [recentDriverSignups, recentMechanicSignups] = await Promise.all([
                Driver.countDocuments({
                    createdAt: { $gte: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000) }
                }),
                Mechanic.countDocuments({
                    createdAt: { $gte: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000) }
                })
            ]);
    
            // Get service request trends
            const serviceRequestTrends = await ServiceRequest.aggregate([
                {
                    $match: {
                        createdAt: { $gte: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000) }
                    }
                },
                {
                    $group: {
                        _id: { $dateToString: { format: "%Y-%m-%d", date: "$createdAt" } },
                        count: { $sum: 1 }
                    }
                },
                { $sort: { _id: 1 } },
                { $limit: 7 }
            ]);
    
            const mechanicRequestTrends = await MechanicServiceRequest.aggregate([
                {
                    $match: {
                        createdAt: { $gte: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000) }
                    }
                },
                {
                    $group: {
                        _id: { $dateToString: { format: "%Y-%m-%d", date: "$createdAt" } },
                        count: { $sum: 1 }
                    }
                },
                { $sort: { _id: 1 } },
                { $limit: 7 }
            ]);

            // Log activity
            await logActivity({
                action: 'VIEW_STATS',
                description: 'Viewed enhanced dashboard statistics',
                performedBy: req.admin.id,
                userType: 'Admin'
            });

            res.status(200).json({
                // Driver and customer stats
                totalDrivers,
                pendingDrivers,
                activeRequests,
                completedRequests,
                totalCustomers,
                monthlyRevenue: monthlyRevenue[0]?.total || 0,
                yearlyRevenue: yearlyRevenue[0]?.total || 0,
                allTimeRevenue: allTimeRevenue[0]?.total || 0,
    
                // Mechanic stats
                totalMechanics,
                pendingMechanics,
                activeMechanicRequests,
                completedMechanicRequests,
                monthlyMechanicRevenue: monthlyMechanicRevenue[0]?.total || 0,
                yearlyMechanicRevenue: yearlyMechanicRevenue[0]?.total || 0,
                allTimeMechanicRevenue: allTimeMechanicRevenue[0]?.total || 0,
    
                // Combined totals
                totalServiceProviders: totalDrivers + totalMechanics,
                totalPendingRegistrations: pendingDrivers + pendingMechanics,
                totalActiveRequests: activeRequests + activeMechanicRequests,
                totalCompletedRequests: completedRequests + completedMechanicRequests,
                totalMonthlyRevenue: (monthlyRevenue[0]?.total || 0) + (monthlyMechanicRevenue[0]?.total || 0),
                totalYearlyRevenue: (yearlyRevenue[0]?.total || 0) + (yearlyMechanicRevenue[0]?.total || 0),
                totalAllTimeRevenue: (allTimeRevenue[0]?.total || 0) + (allTimeMechanicRevenue[0]?.total || 0),
    
                // Recent activity
                recentDriverSignups,
                recentMechanicSignups,
    
                // Trends
                serviceRequestTrends,
                mechanicRequestTrends
            });
        } catch (error) {
            res.status(500).json({ message: 'Server error while fetching statistics' });
        }
    };
    
    // utils/statsHelpers.js
    const getRevenueTrends = async (model, days = 30) => {
        const startDate = new Date();
        startDate.setDate(startDate.getDate() - days);
    
        return await model.aggregate([
            {
                $match: {
                    status: 'completed',
                    createdAt: { $gte: startDate }
                }
            },
            {
                $group: {
                    _id: { $dateToString: { format: "%Y-%m-%d", date: "$createdAt" } },
                    revenue: {
                        $sum: model.modelName === 'ServiceRequest' ? '$totalAmount' : '$priceQuote.amount'
                    },
                    count: { $sum: 1 }
                }
            },
            { $sort: { _id: 1 } }
        ]);
    };
    
    // Search drivers by phone number
    exports.searchDrivers = async (req, res) => {
        try {
            const { phoneNumber: rawPhone, status, page = 1, limit = 10 } = req.query;
    
            // Build the query
            const query = {};
    
            // If phone is provided → ONLY search by phone
            if (rawPhone) {
                query.phoneNumber = rawPhone.startsWith('+') ? rawPhone : `+${rawPhone}`;
            }
            // Otherwise apply status filter (default = pending)
            else {
                const valid = ['uncertain', 'pending', 'approved', 'rejected'];
                const s = status || 'pending';
                if (!valid.includes(s)) {
                    return res.status(400).json({
                        message: `Invalid status. Must be one of: ${valid.join(', ')}`
                    });
                }
                query['personal_info.registration_status'] = s;
            }
    
            const drivers = await Driver.find(query)
                .select(
                    'phoneNumber personal_info.first_name personal_info.last_name personal_info.registration_status vehicles personal_info.registration_date'
                )
                .sort({ 'personal_info.registration_date': -1 })
                .skip((page - 1) * limit)
                .limit(parseInt(limit))
                .lean();
    
            const total = await Driver.countDocuments(query);
    
            const transformed = drivers.map(d => ({
                id: d._id,
                phoneNumber: d.phoneNumber,
                fullName: `${d.personal_info.first_name || ''} ${d.personal_info.last_name || ''}`.trim(),
                registrationStatus: d.personal_info.registration_status,
                vehicleCount: d.vehicles?.length || 0,
                registrationDate: d.personal_info.registration_date
            }));
    
            await logActivity({
                action: 'SEARCH_DRIVERS',
                description: `Searched drivers with params: ${JSON.stringify(req.query)}`,
                performedBy: req.admin.id,
                userType: 'Admin',
                metadata: { searchParams: req.query, resultsCount: transformed.length }
            });

            res.status(200).json({ success: true, data: transformed, pagination: { page: parseInt(page), limit: parseInt(limit), total, pages: Math.ceil(total / limit) } });
        } catch (err) {
            await logActivity({ action: 'SEARCH_DRIVERS_ERROR', description: err.message, performedBy: req.admin.id, userType: 'Admin', isError: true, errorDetails: process.env.NODE_ENV === 'development' ? err.stack : undefined });
            res.status(500).json({ success: false, message: 'Server error while searching drivers' });
        }
    };
    
    
    // Get a full service request by ObjectId
    exports.getServiceRequestById = async (req, res) => {
        try {
            const { id } = req.params;

            if (!id || !id.match(/^[0-9a-fA-F]{24}$/)) {
                return res.status(400).json({
                    success: false,
                    message: 'Invalid request ID format',
                });
            }

            const request = await ServiceRequest.findById(id)
                .populate('userId')
                .populate('driverId')
                .lean();

            if (!request) {
                return res.status(404).json({
                    success: false,
                    message: 'Service request not found',
                });
            }

            if (req.admin) {
                await logActivity({
                    action: 'VIEW_SERVICE_REQUEST',
                    description: `Viewed service request ${id}`,
                    performedBy: req.admin.id,
                    userType: 'Admin',
                    metadata: { requestId: id },
                });
            }

            res.status(200).json({
                success: true,
                data: request,
            });
        } catch (err) {
            res.status(500).json({
                success: false,
                message: 'Server error while fetching service request',
            });
        }
    };
    
    // Get a full mechanic service request by ObjectId
    exports.getMechanicServiceRequestById = async (req, res) => {
        try {
            const { id } = req.params;
    
            // Validate ObjectId format
            if (!id || !mongoose.Types.ObjectId.isValid(id)) {
                return res.status(400).json({
                    success: false,
                    message: 'Invalid mechanic service request ID format',
                });
            }
    
            // Find and fully populate request with user & mechanic
            const request = await MechanicServiceRequest.findById(id)
                .populate('userId', 'fullName phoneNumber')   // Populate user with selected fields
                .populate('mechanicId', 'fullName phoneNumber registrationStatus') // Populate mechanic with selected fields
                .lean();
    
            if (!request) {
                return res.status(404).json({
                    success: false,
                    message: 'Mechanic service request not found',
                });
            }
    
            // Optionally log the admin activity
            if (req.admin) {
                await logActivity({
                    action: 'VIEW_MECHANIC_SERVICE_REQUEST',
                    description: `Viewed mechanic service request ${id}`,
                    performedBy: req.admin.id,
                    userType: 'Admin',
                    metadata: { requestId: id },
                });
            }
    
            res.status(200).json({
                success: true,
                data: request,
            });
        } catch (err) {
            res.status(500).json({
                success: false,
                message: 'Server error while fetching mechanic service request',
            });
        }
    };
    
    // Get driver details
    exports.getDriverDetails = async (req, res) => {
        try {
            const driver = await Driver.findById(req.params.id)
                .select('-otp -__v');
    
            if (!driver) {
                return res.status(404).json({ message: 'Driver not found' });
            }
    
            const requests = await ServiceRequest.find({ driverId: driver._id })
                .sort({ createdAt: -1 })
                .limit(10)
                .populate('userId', 'phoneNumber fullName');
    
            // Log activity
            await logActivity({
                action: 'VIEW_DRIVER',
                description: `Viewed driver: ${driver._id}`,
                entityType: 'driver',
                entityId: driver._id,
                performedBy: req.admin.id,
                userType: 'Admin'
            });

            res.status(200).json({
                driver,
                recentRequests: requests
            });
        } catch (error) {
            res.status(500).json({ message: 'Server error' });
        }
    };
    
    // Search customers by phone number
    exports.searchCustomers = async (req, res) => {
        try {
            const { phoneNumber } = req.query;
            if (!phoneNumber) {
                return res.status(400).json({ message: 'Phone number is required' });
            }
    
            const customers = await Customer.find({ phoneNumber })
                .select('phoneNumber fullName createdAt')
                .limit(10);
    
            // Log activity
            await logActivity({
                action: 'SEARCH_CUSTOMERS',
                description: `Searched customers: ${phoneNumber}`,
                performedBy: req.admin.id,
                userType: 'Admin'
            });

            res.status(200).json(customers);
        } catch (error) {
            res.status(500).json({ message: 'Server error' });
        }
    };
    
    // Get customer details
    exports.getCustomerDetails = async (req, res) => {
        try {
            const customer = await Customer.findById(req.params.id);
    
            if (!customer) {
                return res.status(404).json({ message: 'Customer not found' });
            }
    
            const requests = await ServiceRequest.find({ userId: customer._id })
                .sort({ createdAt: -1 })
                .limit(10)
                .populate('driverId', 'phoneNumber personal_info');
    
            // Log activity
            await logActivity({
                action: 'VIEW_CUSTOMER',
                description: `Viewed customer: ${customer._id}`,
                entityType: 'customer',
                entityId: customer._id,
                performedBy: req.admin.id,
                userType: 'Admin'
            });

            res.status(200).json({
                customer,
                recentRequests: requests
            });
        } catch (error) {
            res.status(500).json({ message: 'Server error' });
        }
    };
    
    // Get latest ride requests
    exports.getLatestRequests = async (req, res) => {
        try {
            const requests = await ServiceRequest.find()
                .sort({ createdAt: -1 })
                .limit(20)
                .populate('userId', 'phoneNumber fullName')
                .populate('driverId', 'phoneNumber personal_info');
    
            // Log activity
            await logActivity({
                action: 'VIEW_REQUESTS',
                description: 'Viewed latest ride requests',
                performedBy: req.admin.id,
                userType: 'Admin'
            });

            res.status(200).json(requests);
        } catch (error) {
            res.status(500).json({ message: 'Server error' });
        }
    };

    // Get activity logs
    exports.getActivityLogs = async (req, res) => {
        try {
            const { page = 1, limit = 20 } = req.query;
            const logs = await require('../models/ActivityLog').find()
                .sort({ timestamp: -1 })
                .skip((page - 1) * limit)
                .limit(parseInt(limit))
                .populate('performedBy', 'username');
    
            const totalLogs = await require('../models/ActivityLog').countDocuments();

            res.status(200).json({
                logs,
                total: totalLogs,
                page: parseInt(page),
                pages: Math.ceil(totalLogs / limit)
            });
        } catch (error) {
            res.status(500).json({ message: 'Server error' });
        }
    };
    
    // Approve a driver registration (with logging)
    exports.approveDriver = async (req, res) => {
        try {
            const driver = await Driver.findById(req.params.id);
            if (!driver) {
                return res.status(404).json({ message: 'Driver not found' });
            }
    
            const adminAction = {
                action: 'approved',
                adminId: req.admin.id,
                adminType: 'user',
                notes: req.body.notes || 'Approved by admin'
            };
    
            driver.adminActions.push(adminAction);
            driver.personal_info.registration_status = 'approved';
            driver.personal_info.last_updated = new Date();
            await driver.save();
    
            // Log activity
            await logActivity({
                action: 'APPROVE_DRIVER',
                description: `Approved driver: ${driver._id}`,
                entityType: 'driver',
                entityId: driver._id,
                performedBy: req.admin.id,
                userType: 'Admin'
            });

            res.status(200).json({ message: 'Driver approved successfully' });
        } catch (error) {
            res.status(500).json({ message: 'Server error' });
        }
    };
    
    // Reject a driver registration (with logging)
    exports.rejectDriver = async (req, res) => {
        try {
            const driver = await Driver.findById(req.params.id);
            if (!driver) {
                return res.status(404).json({ message: 'Driver not found' });
            }
    
            const adminAction = {
                action: 'rejected',
                adminId: req.admin.id,
                adminType: 'user',
                notes: req.body.notes || 'Rejected by admin'
            };
    
            driver.adminActions.push(adminAction);
            driver.personal_info.registration_status = 'rejected';
            driver.personal_info.last_updated = new Date();
            await driver.save();
    
            // Log activity
            await logActivity({
                action: 'REJECT_DRIVER',
                description: `Rejected driver: ${driver._id}`,
                entityType: 'driver',
                entityId: driver._id,
                performedBy: req.admin.id,
                userType: 'Admin'
            });

            res.status(200).json({ message: 'Driver rejected successfully' });
        } catch (error) {
            res.status(500).json({ message: 'Server error' });
        }
    };
    
    // Get pending driver registrations
    exports.getPendingRegistrations = async (req, res) => {
        try {
            const pendingDrivers = await Driver.find({ 'personal_info.registration_status': 'pending' })
                .select('phoneNumber personal_info vehicles')
                .sort({ createdAt: -1 });
    
            res.status(200).json(pendingDrivers);
        } catch (error) {
            res.status(500).json({ message: 'Server error' });
        }
    };
    
    // Get all drivers
    exports.getAllDrivers = async (req, res) => {
        try {
            const drivers = await Driver.find()
                .select('-otp -__v')
                .sort({ createdAt: -1 });
    
            res.status(200).json(drivers);
        } catch (error) {
            res.status(500).json({ message: 'Server error' });
        }
    };
    
    // Get all service requests
    exports.getServiceRequests = async (req, res) => {
        try {
            const requests = await ServiceRequest.find()
                .sort({ createdAt: -1 })
                .populate('userId', 'phoneNumber fullName')
                .populate('driverId', 'phoneNumber personal_info');
    
            res.status(200).json(requests);
        } catch (error) {
            res.status(500).json({ message: 'Server error' });
        }
    };
    
    // Create a new admin
    exports.createAdmin = async (req, res) => {
        try {
            const { username, password, role } = req.body;
    
            if (!username || !password) {
                return res.status(400).json({ message: 'Username and password are required' });
            }
    
            const existingAdmin = await Admin.findOne({ username });
            if (existingAdmin) {
                return res.status(409).json({ message: 'Admin already exists' });
            }
    
            const newAdmin = new Admin({
                username,
                password,
                role: role || 'admin'
            });
            await newAdmin.save();
    
            // Log activity
            await logActivity({
                action: 'CREATE_ADMIN',
                description: `Created admin: ${username} with role ${newAdmin.role}`,
                performedBy: req.admin.id,
                userType: 'Admin'
            });

            res.status(201).json({ message: 'Admin created successfully' });
        } catch (error) {
            res.status(500).json({ message: 'Server error' });
        }
    };
    
    // Get all admins
    exports.getAllAdmins = async (req, res) => {
        try {
            const admins = await Admin.find({}, '-password');
            res.status(200).json(admins);
        } catch (error) {
            res.status(500).json({ message: 'Server error' });
        }
    };
    
    // Delete an admin
    exports.deleteAdmin = async (req, res) => {
        try {
            const { id } = req.params;
    
            if (id === req.admin.id) {
                return res.status(400).json({ message: 'You cannot delete your own account.' });
            }
    
            const admin = await Admin.findById(id);
            if (!admin) {
                return res.status(404).json({ message: 'Admin not found' });
            }
    
            if (admin.role === 'superadmin') {
                return res.status(403).json({ message: 'Cannot delete a superadmin.' });
            }
    
            await Admin.findByIdAndDelete(id);
    
            await logActivity({
                action: 'DELETE_ADMIN',
                description: `Deleted admin: ${admin.username}`,
                performedBy: req.admin.id,
                userType: 'Admin'
            });

            res.status(200).json({ message: 'Admin deleted successfully' });
        } catch (error) {
            res.status(500).json({ message: 'Server error' });
        }
    };
    
    // Update an admin's role
    exports.updateAdminRole = async (req, res) => {
        try {
            const { id } = req.params;
            const { role } = req.body;
    
            if (!role || !['admin', 'superadmin'].includes(role)) {
                return res.status(400).json({ message: 'Invalid role specified.' });
            }
    
            if (id === req.admin.id) {
                return res.status(400).json({ message: 'You cannot change your own role.' });
            }
    
            const admin = await Admin.findById(id);
            if (!admin) {
                return res.status(404).json({ message: 'Admin not found' });
            }
    
            admin.role = role;
            await admin.save();
    
            await logActivity({
                action: 'UPDATE_ADMIN_ROLE',
                description: `Updated role for admin ${admin.username} to ${role}`,
                performedBy: req.admin.id,
                userType: 'Admin'
            });

            res.status(200).json({ message: 'Admin role updated successfully' });
        } catch (error) {
            res.status(500).json({ message: 'Server error' });
        }
    };
    
    exports.updateAdminStatus = async (req, res) => {
        try {
            const { id } = req.params;
            const { active } = req.body;
    
            if (typeof active !== 'boolean') {
                return res.status(400).json({ message: 'Invalid status specified. It must be true or false.' });
            }
    
            if (id === req.admin.id) {
                return res.status(400).json({ message: 'You cannot change your own status.' });
            }
    
            const admin = await Admin.findById(id);
            if (!admin) {
                return res.status(404).json({ message: 'Admin not found' });
            }
    
            if (admin.role === 'superadmin') {
                return res.status(403).json({ message: 'Cannot change the status of a superadmin.' });
            }
    
            admin.active = active;
            await admin.save();
    
            await logActivity({
                action: 'UPDATE_ADMIN_STATUS',
                description: `Updated status for admin ${admin.username} to ${active ? 'active' : 'inactive'}`,
                performedBy: req.admin.id,
                userType: 'Admin'
            });

            res.status(200).json({ message: `Admin account has been ${active ? 'activated' : 'deactivated'}` });
        } catch (error) {
            res.status(500).json({ message: 'Server error' });
        }
    };
    
    
    // Mechanic management functions
    exports.getPendingMechanicRegistrations = async (req, res) => {
        try {
            const pendingMechanics = await Mechanic.find({ registrationStatus: 'pending' })
                .select('phoneNumber personName shopName servicesOffered createdAt')
                .sort({ createdAt: -1 });
    
            // Log activity
            await logActivity({
                action: 'VIEW_PENDING_MECHANICS',
                description: 'Viewed pending mechanic registrations',
                performedBy: req.admin.id,
                userType: 'Admin'
            });

            res.status(200).json(pendingMechanics);
        } catch (error) {
            res.status(500).json({ message: 'Server error' });
        }
    };
    exports.getUncertainMechanicRegistrations = async (req, res) => {
        try {
            const pendingMechanics = await Mechanic.find({ registrationStatus: 'uncertain' })
                .select('phoneNumber personName shopName servicesOffered createdAt')
                .sort({ createdAt: -1 });
    
            // Log activity
            await logActivity({
                action: 'VIEW_UNCERTAIN_MECHANICS',
                description: 'Viewed pending uncertain registrations',
                performedBy: req.admin.id,
                userType: 'Admin'
            });

            res.status(200).json(pendingMechanics);
        } catch (error) {
            res.status(500).json({ message: 'Server error' });
        }
    };
    // Get rejected mechanic registrations
    exports.getRejectedMechanicRegistrations = async (req, res) => {
        try {
            const rejectedMechanics = await Mechanic.find({ registrationStatus: 'rejected' })
                .select('phoneNumber personName shopName servicesOffered createdAt')
                .sort({ createdAt: -1 });
    
            // Log activity
            await logActivity({
                action: 'VIEW_REJECTED_MECHANICS',
                description: 'Viewed rejected mechanic registrations',
                performedBy: req.admin.id,
                userType: 'Admin'
            });

            res.status(200).json(rejectedMechanics);
        } catch (error) {
            res.status(500).json({ message: 'Server error' });
        }
    };
    
    // Get approved mechanic registrations
    exports.getApprovedMechanicRegistrations = async (req, res) => {
        try {
            const approvedMechanics = await Mechanic.find({ registrationStatus: 'approved' })
                .select('phoneNumber personName shopName servicesOffered createdAt')
                .sort({ createdAt: -1 });
    
            // Log activity
            await logActivity({
                action: 'VIEW_APPROVED_MECHANICS',
                description: 'Viewed approved mechanic registrations',
                performedBy: req.admin.id,
                userType: 'Admin'
            });

            res.status(200).json(approvedMechanics);
        } catch (error) {
            res.status(500).json({ message: 'Server error' });
        }
    };
    
    exports.searchMechanics = async (req, res) => {
        try {
            const { phoneNumber, status, page = 1, limit = 10 } = req.query;
    
            // Build the query
            const query = {};
    
            if (phoneNumber) {
                query.phoneNumber = phoneNumber.startsWith('+') ? phoneNumber : `+${phoneNumber}`;
            }
    
            if (status) {
                query.registrationStatus = status;
            }
    
            const mechanics = await Mechanic.find(query)
                .select('phoneNumber personName shopName registrationStatus servicesOffered createdAt')
                .sort({ createdAt: -1 })
                .skip((page - 1) * limit)
                .limit(parseInt(limit))
                .lean();
    
            const total = await Mechanic.countDocuments(query);
    
            // Log activity
            await logActivity({
                action: 'SEARCH_MECHANICS',
                description: `Searched mechanics with params: ${JSON.stringify(req.query)}`,
                performedBy: req.admin.id,
                userType: 'Admin',
                metadata: { searchParams: req.query, resultsCount: mechanics.length }
            });

            res.status(200).json({
                success: true,
                data: mechanics,
                pagination: {
                    page: parseInt(page),
                    limit: parseInt(limit),
                    total,
                    pages: Math.ceil(total / limit)
                }
            });
        } catch (error) {
            res.status(500).json({ message: 'Server error' });
        }
    };
    
    exports.getMechanicDetails = async (req, res) => {
        try {
            const mechanic = await Mechanic.findById(req.params.id);
    
            if (!mechanic) {
                return res.status(404).json({ message: 'Mechanic not found' });
            }
    
            const requests = await MechanicServiceRequest.find({ mechanicId: mechanic._id })
                .sort({ createdAt: -1 })
                .limit(10)
                .populate('userId', 'phoneNumber fullName');
    
            // Log activity
            await logActivity({
                action: 'VIEW_MECHANIC',
                description: `Viewed mechanic: ${mechanic._id}`,
                entityType: 'mechanic',
                entityId: mechanic._id,
                performedBy: req.admin.id,
                userType: 'Admin'
            });

            res.status(200).json({
                mechanic,
                recentRequests: requests
            });
        } catch (error) {
            res.status(500).json({ message: 'Server error' });
        }
    };
    
    exports.approveMechanic = async (req, res) => {
        try {
            const mechanic = await Mechanic.findById(req.params.id);
            if (!mechanic) {
                return res.status(404).json({ message: 'Mechanic not found' });
            }
    
            mechanic.registrationStatus = 'approved';
            await mechanic.save();
    
            // Log activity
            await logActivity({
                action: 'APPROVE_MECHANIC',
                description: `Approved mechanic: ${mechanic._id}`,
                entityType: 'mechanic',
                entityId: mechanic._id,
                performedBy: req.admin.id,
                userType: 'Admin'
            });

            res.status(200).json({ message: 'Mechanic approved successfully' });
        } catch (error) {
            res.status(500).json({ message: 'Server error' });
        }
    };
    
    exports.rejectMechanic = async (req, res) => {
        try {
            const mechanic = await Mechanic.findById(req.params.id);
            if (!mechanic) {
                return res.status(404).json({ message: 'Mechanic not found' });
            }
    
            mechanic.registrationStatus = 'rejected';
            await mechanic.save();
    
            // Log activity
            await logActivity({
                action: 'REJECT_MECHANIC',
                description: `Rejected mechanic: ${mechanic._id}`,
                entityType: 'mechanic',
                entityId: mechanic._id,
                performedBy: req.admin.id,
                userType: 'Admin'
            });

            res.status(200).json({ message: 'Mechanic rejected successfully' });
        } catch (error) {
            res.status(500).json({ message: 'Server error' });
        }
    };
    // Set mechanic registration status to pending
    exports.setPendingMechanic = async (req, res) => {
        try {
            const mechanic = await Mechanic.findById(req.params.id);
            if (!mechanic) {
                return res.status(404).json({ message: 'Mechanic not found' });
            }
    
            mechanic.registrationStatus = 'pending';
            await mechanic.save();
    
            // Log activity
            await logActivity({
                action: 'SET_PENDING_MECHANIC',
                description: `Set mechanic to pending: ${mechanic._id}`,
                entityType: 'mechanic',
                entityId: mechanic._id,
                performedBy: req.admin.id,
                userType: 'Admin'
            });

            res.status(200).json({ message: 'Mechanic status set to pending successfully' });
        } catch (error) {
            res.status(500).json({ message: 'Server error' });
        }
    };
    
    // Set mechanic registration status to uncertain
    exports.setUncertainMechanic = async (req, res) => {
        try {
            const mechanic = await Mechanic.findById(req.params.id);
            if (!mechanic) {
                return res.status(404).json({ message: 'Mechanic not found' });
            }
    
            mechanic.registrationStatus = 'uncertain';
            await mechanic.save();
    
            // Log activity
            await logActivity({
                action: 'SET_UNCERTAIN_MECHANIC',
                description: `Set mechanic to uncertain: ${mechanic._id}`,
                entityType: 'mechanic',
                entityId: mechanic._id,
                performedBy: req.admin.id,
                userType: 'Admin'
            });

            res.status(200).json({ message: 'Mechanic status set to uncertain successfully' });
        } catch (error) {
            res.status(500).json({ message: 'Server error' });
        }
    };
    
    exports.getAllMechanics = async (req, res) => {
        try {
            const mechanics = await Mechanic.find()
                .select('-otp')
                .sort({ createdAt: -1 });
    
            res.status(200).json(mechanics);
        } catch (error) {
            res.status(500).json({ message: 'Server error' });
        }
    };
    
    // Mechanic service requests functions
    exports.getLatestMechanicRequests = async (req, res) => {
        try {
            const requests = await MechanicServiceRequest.find()
                .sort({ createdAt: -1 })
                .limit(20)
                .populate('userId', 'phoneNumber fullName')
                .populate('mechanicId', 'phoneNumber personName shopName');
    
            // Log activity
            await logActivity({
                action: 'VIEW_MECHANIC_REQUESTS',
                description: 'Viewed latest mechanic service requests',
                performedBy: req.admin.id,
                userType: 'Admin'
            });

            res.status(200).json(requests);
        } catch (error) {
            res.status(500).json({ message: 'Server error' });
        }
    };
    
    exports.getMechanicServiceRequests = async (req, res) => {
        try {
            const { status, page = 1, limit = 20 } = req.query;
            const query = {};
    
            if (status) {
                query.status = status;
            }
    
            const requests = await MechanicServiceRequest.find(query)
                .sort({ createdAt: -1 })
                .skip((page - 1) * limit)
                .limit(parseInt(limit))
                .populate('userId', 'phoneNumber fullName')
                .populate('mechanicId', 'phoneNumber personName shopName');
    
            const total = await MechanicServiceRequest.countDocuments(query);
    
            res.status(200).json({
                requests,
                pagination: {
                    page: parseInt(page),
                    limit: parseInt(limit),
                    total,
                    pages: Math.ceil(total / limit)
                }
            });
        } catch (error) {
            res.status(500).json({ message: 'Server error' });
        }
    };
    
    
    // Export the helper function
    exports.getRevenueTrends = getRevenueTrends;

    // Get admin profile
exports.getProfile = async (req, res) => {
    try {
        const admin = await Admin.findById(req.admin.id).select('-password');

        if (!admin) {
            return res.status(404).json({ message: 'Admin not found' });
        }

        // Log activity
        await logActivity({
            action: 'VIEW_PROFILE',
            description: 'Viewed admin profile',
            performedBy: req.admin.id,
            userType: 'Admin'
        });

        res.status(200).json(admin);
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
};

// Change admin password
exports.changePassword = async (req, res) => {
    try {
        const { currentPassword, newPassword } = req.body;

        // Validate input
        if (!currentPassword || !newPassword) {
            return res.status(400).json({
                message: 'Current password and new password are required'
            });
        }

        if (newPassword.length < 6) {
            return res.status(400).json({
                message: 'New password must be at least 6 characters long'
            });
        }

        // Find the admin
        const admin = await Admin.findById(req.admin.id);
        if (!admin) {
            return res.status(404).json({ message: 'Admin not found' });
        }

        // Verify current password
        const isCurrentPasswordValid = await admin.comparePassword(currentPassword);
        if (!isCurrentPasswordValid) {
            return res.status(400).json({
                message: 'Current password is incorrect'
            });
        }

        // Update password (will be hashed by the pre-save middleware)
        admin.password = newPassword;
        await admin.save();

        // Log activity
        await logActivity({
            action: 'CHANGE_PASSWORD',
            description: 'Changed admin password',
            performedBy: req.admin.id,
            userType: 'Admin'
        });

        res.status(200).json({ message: 'Password changed successfully' });
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
};
