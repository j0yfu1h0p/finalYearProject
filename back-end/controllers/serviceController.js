const ServiceRequest = require('../models/ServiceRequest');
const { logActivity } = require('../services/activityLogService');

exports.createServiceRequest = async (req, res, next) => {
    try {
        const {
            vehicleType,
            pickupLocation,
            destination,
            distance,
            duration,
            rate,
            totalAmount
        } = req.body;

        if (!pickupLocation.coordinates || !pickupLocation.coordinates.lng || !pickupLocation.coordinates.lat) {
            return res.status(400).json({ success: false, message: 'Pickup location with lat and lng coordinates is required.' });
        }

        const expiresAt = new Date(Date.now() + 10 * 60 * 1000);
        const serviceRequest = new ServiceRequest({
            vehicleType,
            pickupLocation: {
                address: pickupLocation.address,
                location: {
                    type: 'Point',
                    coordinates: [pickupLocation.coordinates.lng, pickupLocation.coordinates.lat]
                }
            },
            destination,
            distance,
            duration,
            rate,
            totalAmount,
            userId: req.user.id,
            expiresAt
        });

        const savedRequest = await serviceRequest.save();

        await logActivity({
            action: 'CREATE_REQUEST',
            description: `New service request created: ${savedRequest._id}`,
            entityType: 'request',
            entityId: savedRequest._id,
            performedBy: req.user.id,
            userType: 'User'
        });

        const io = req.app.locals.io;
        const driverSockets = req.app.locals.driverSockets;
        await notifyNearbyDrivers(savedRequest, io, driverSockets);

        res.status(201).json({ success: true, data: savedRequest });
    } catch (err) {
        next(err);
    }
};

exports.getUserRequests = async (req, res, next) => {
    try {
        const requests = await ServiceRequest.find({ userId: req.user.id }).sort({ createdAt: -1 });
        res.status(200).json({ success: true, data: requests });
    } catch (err) {
        next(err);
    }
};

exports.getActiveRide = async (req, res, next) => {
    try {
        const activeRide = await ServiceRequest.findOne({
            userId: req.user.id,
            status: { $in: ['accepted', 'arrived', 'in_progress'] }
        })
        .populate('driverId', 'personal_info phoneNumber vehicles rating')
        .sort({ createdAt: -1 });

        if (activeRide) {
            return res.status(200).json({
                success: true,
                hasActiveRide: true,
                data: activeRide
            });
        }

        res.status(200).json({
            success: true,
            hasActiveRide: false,
            data: null
        });
    } catch (err) {
        next(err);
    }
};

exports.getActiveDriverTrip = async (req, res, next) => {
    try {
        const activeTrip = await ServiceRequest.findOne({
            driverId: req.driver.id,
            status: { $in: ['accepted', 'arrived', 'in_progress'] }
        })
        .populate('userId', 'fullName phoneNumber')
        .sort({ createdAt: -1 });

        if (activeTrip) {
            return res.status(200).json({
                success: true,
                hasActiveTrip: true,
                data: activeTrip
            });
        }

        res.status(200).json({
            success: true,
            hasActiveTrip: false,
            data: null
        });
    } catch (err) {
        next(err);
    }
};

const notifyNearbyDrivers = async (serviceRequest, io, driverSockets) => {
    try {
        const connectedDrivers = Array.from(driverSockets.keys());

        if (connectedDrivers.length === 0) {
            return;
        }

        connectedDrivers.forEach(driverId => {
            const socketId = driverSockets.get(driverId);
            if (socketId) {
                io.to(socketId).emit('new_ride_request', {
                    requestId: serviceRequest._id,
                    vehicleType: serviceRequest.vehicleType,
                    pickupLocation: serviceRequest.pickupLocation,
                    destination: serviceRequest.destination,
                    distance: serviceRequest.distance,
                    duration: serviceRequest.duration,
                    totalAmount: serviceRequest.totalAmount,
                    createdAt: serviceRequest.createdAt,
                    expiresAt: serviceRequest.expiresAt
                });
            }
        });

    } catch (error) {

    }
};

exports.getServiceRequestById = async (req, res, next) => {
    try {
        const request = await ServiceRequest.findOne({
            _id: req.params.id,
            userId: req.user.id
        });

        if (!request) {
            return res.status(404).json({ success: false, message: 'Request not found' });
        }

        res.status(200).json({ success: true, data: request });
    } catch (err) {
        next(err);
    }
};

exports.getPendingRequests = async (req, res, next) => {
    try {
        const requests = await ServiceRequest.find({ status: 'pending' }).sort({ createdAt: -1 });
        res.status(200).json({ success: true, data: requests });
    } catch (err) {
        next(err);
    }
};

exports.getNearbyPendingRequests = async (req, res) => {
    try {
        const { latitude, longitude } = req.body;
        const driver = req.driver;

        if (!latitude || !longitude) {
            return res.status(400).json({ message: "Your current location (latitude, longitude) is required." });
        }

        const now = new Date();
        const expiredRequests = await ServiceRequest.find({
            status: 'pending',
            expiresAt: { $lt: now }
        });

        if (expiredRequests.length > 0) {
            const expiredIds = expiredRequests.map(r => r._id);
            await ServiceRequest.updateMany(
                { _id: { $in: expiredIds } },
                { $set: { status: 'cancelled' } }
            );
        }

        const radiusKm = parseFloat(req.query.radiusKm || "10");
        const coords = [longitude, latitude];

        const query = {
            status: "pending",
            expiresAt: { $gt: now },
            'pickupLocation.location': {
                $near: {
                    $geometry: { type: "Point", coordinates: coords },
                    $maxDistance: radiusKm * 1000
                }
            }
        };

        const serviceRequests = await ServiceRequest.find(query).limit(50).populate('userId', 'personal_info.name');

        res.status(200).json({ success: true, data: serviceRequests });

    } catch (error) {
        res.status(500).json({ message: "Server error" });
    }
};

exports.acceptServiceRequest = async (req, res, next) => {
    try {
        const request = await ServiceRequest.findOneAndUpdate(
            { _id: req.params.id, status: 'pending' },
            {
                $set: {
                    driverId: req.driver.id,
                    status: 'accepted'
                },
                $unset: { expiresAt: 1 }
            },
            { new: true }
        );

        if (!request) {
            return res.status(404).json({ success: false, message: 'Request not found or already accepted' });
        }

        const io = req.app.locals.io;
        const userSockets = req.app.locals.userSockets;

        const userSocketId = userSockets.get(request.userId.toString());
        if (userSocketId) {
            io.to(userSocketId).emit("driver_assigned", {
                driver: {
                    _id: req.driver.id,
                    name: req.driver.name,
                    phone: req.driver.phone,
                    avatar: req.driver.avatar,
                    vehicle: req.driver.vehicle,
                    rating: req.driver.rating
                },
                tripId: request._id
            });
        }

        res.status(200).json({
            success: true,
            message: 'Service request accepted',
            data: request
        });
    } catch (err) {
        next(err);
    }
};

exports.markArrived = async (req, res, next) => {
    try {
        const request = await ServiceRequest.findOne({
            _id: req.params.id,
            driverId: req.driver.id,
            status: 'accepted'
        });

        if (!request) {
            return res.status(404).json({ success: false, message: 'Request not found or not accepted' });
        }

        request.status = 'arrived';
        await request.save();

        const io = req.app.locals.io;
        const userSockets = req.app.locals.userSockets;
        const userSocketId = userSockets.get(request.userId.toString());
        if (userSocketId) {
            io.to(userSocketId).emit('driver_arrived', { requestId: request._id });
        }

        res.status(200).json({ success: true, message: 'Driver has arrived', data: request });
    } catch (err) {
        next(err);
    }
};

exports.startTrip = async (req, res, next) => {
    try {
        const request = await ServiceRequest.findOne({
            _id: req.params.id,
            driverId: req.driver.id,
            status: { $in: ['accepted', 'arrived'] }
        });

        if (!request) {
            return res.status(404).json({
                success: false,
                message: 'Request not found or not ready for starting'
            });
        }

        request.status = 'in_progress';
        await request.save();

        const io = req.app.locals.io;
        const userSockets = req.app.locals.userSockets;
        const userSocketId = userSockets.get(request.userId.toString());

        if (userSocketId) {
            io.to(userSocketId).emit('trip_started', {
                requestId: request._id
            });
        }

        res.status(200).json({
            success: true,
            message: 'Trip started successfully',
            data: request
        });

    } catch (err) {
        next(err);
    }
};

exports.completeServiceRequest = async (req, res, next) => {
    try {
        const request = await ServiceRequest.findOne({
            _id: req.params.id,
            driverId: req.driver.id
        });

        if (!request) {
            return res.status(404).json({
                success: false,
                message: 'Request not found or not assigned to this driver'
            });
        }

        if (!['accepted', 'arrived', 'in_progress'].includes(request.status)) {
            return res.status(400).json({
                success: false,
                message: `Cannot complete request from current status: ${request.status}`
            });
        }

        request.status = 'completed';
        await request.save();

        const io = req.app.locals.io;
        const userSockets = req.app.locals.userSockets;

        const userSocketId = userSockets.get(request.userId.toString());
        if (userSocketId) {
            io.to(userSocketId).emit('ride_status_update', {
                status: 'completed',
                requestId: request._id,
                driverId: request.driverId,
                timestamp: new Date()
            });
        }

        const driverSockets = req.app.locals.driverSockets;
        const driverSocketId = driverSockets?.get(request.driverId.toString());
        if (driverSocketId) {
            io.to(driverSocketId).emit('ride_status_update', {
                status: 'completed',
                requestId: request._id,
                userId: request.userId,
                timestamp: new Date()
            });
        }

        res.status(200).json({
            success: true,
            message: 'Service request completed successfully',
            data: request
        });

    } catch (err) {
        next(err);
    }
};

exports.cancelServiceRequest = async (req, res, next) => {
    try {
        const request = await ServiceRequest.findOne({
            _id: req.params.id,
            $or: [
                { userId: req.user?.id },
                { driverId: req.driver?.id }
            ]
        });

        if (!request) {
            return res.status(404).json({ success: false, message: 'Request not found' });
        }

        if (['cancelled', 'completed'].includes(request.status)) {
            return res.status(400).json({
                success: false,
                message: `Cannot cancel request with status: ${request.status}`
            });
        }

        request.status = 'cancelled';
        await request.save();

        const io = req.app.locals.io;

        if (request.userId) {
            const userSockets = req.app.locals.userSockets;
            const userSocketId = userSockets.get(request.userId.toString());
            if (userSocketId) {
                io.to(userSocketId).emit('ride_status_update', {
                    status: 'cancelled',
                    requestId: request._id,
                    driverId: request.driverId,
                    timestamp: new Date()
                });
            }
        }

        if (request.driverId) {
            const driverSockets = req.app.locals.driverSockets;
            const driverSocketId = driverSockets?.get(request.driverId.toString());
            if (driverSocketId) {
                io.to(driverSocketId).emit('ride_status_update', {
                    status: 'cancelled',
                    requestId: request._id,
                    userId: request.userId,
                    timestamp: new Date()
                });
            }
        }

        res.status(200).json({
            success: true,
            message: 'Service request cancelled',
            data: request
        });
    } catch (err) {
        next(err);
    }
};
