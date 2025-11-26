const MechanicServiceRequest = require('../models/MechanicServiceRequest');
const Mechanic = require('../models/Mechanic');
const Customer = require('../models/Customer');
const { logActivity } = require('../services/activityLogService');

const EXP_MIN = parseInt(process.env.MECHANIC_REQ_EXP_MIN || '5', 10);

// Helpers
function now() { return new Date(); }
function isExpired(doc) { return doc.expiresAt && doc.expiresAt.getTime() < Date.now(); }
const notifyNearbyMechanics = async (serviceRequest, io, mechanicSockets) => {
    try {

        const connectedMechanics = Array.from(mechanicSockets.keys());

        if (connectedMechanics.length === 0) {
            return;
        }

        connectedMechanics.forEach(mechanicId => {
            const socketId = mechanicSockets.get(mechanicId);
            if (socketId) {
                io.to(socketId).emit('new_mechanic_request', {
                    requestId: serviceRequest._id,
                    serviceType: serviceRequest.serviceType,
                    userLocation: serviceRequest.userLocation,
                    notes: serviceRequest.notes,
                    priceQuote: serviceRequest.priceQuote,
                    userId: serviceRequest.userId,
                    createdAt: serviceRequest.createdAt,
                    expiresAt: serviceRequest.expiresAt
                });
            }
        });

    } catch (error) {

    }
};

// USER: Create new service request
exports.createUserServiceRequest = async (req, res) => {
    const userId = req.user?.id || req.user?._id;
    try {
        if (!userId) return res.status(401).json({ message: 'Unauthorized' });

        const { serviceType, userLocation, notes, priceQuote } = req.body;
        if (!serviceType) return res.status(400).json({ message: 'serviceType required' });
        if (!userLocation || !Array.isArray(userLocation.coordinates) || userLocation.coordinates.length !== 2) {
            return res.status(400).json({ message: 'userLocation.coordinates [lng,lat] required' });
        }

        // Add price quote validation
        let priceData = null;
        if (priceQuote && priceQuote.amount) {
            priceData = {
                amount: priceQuote.amount,
                currency: priceQuote.currency || 'PKR',
                providedAt: new Date(),
                updatedAt: new Date()
            };
        }

        const doc = await MechanicServiceRequest.create({
            userId,
            serviceType,
            userLocation: { type: 'Point', coordinates: userLocation.coordinates },
            expiresAt: new Date(Date.now() + EXP_MIN * 60 * 1000),
            notes,
            priceQuote: priceData
        });

        // Populate the document to get full details
        const populatedDoc = await MechanicServiceRequest.findById(doc._id)
            .populate('userId', 'name phone');

        await logActivity({
            action: 'CREATE_MECHANIC_REQUEST',
            description: `User created a new mechanic service request: ${doc._id}`,
            performedBy: userId,
            userType: 'User',
            entityId: doc._id,
            entityType: 'request',
            metadata: { serviceType: doc.serviceType }
        });

        // Notify nearby mechanics about the new request
        const io = req.app?.locals?.io;
        const mechanicSockets = req.app?.locals?.mechanicSockets;
        if (io && mechanicSockets) {
            await notifyNearbyMechanics(populatedDoc, io, mechanicSockets);
        }

        return res.status(201).json(populatedDoc);
    } catch (e) {
        await logActivity({
            action: 'CREATE_MECHANIC_REQUEST_ERROR',
            description: e.message,
            performedBy: userId,
            userType: 'User',
            isError: true,
            errorDetails: e.stack
        });
        return res.status(500).json({ message: 'Server error' });
    }
};
// USER: Get single request
exports.getUserServiceRequest = async (req, res) => {
    try {
        const userId = req.user?.id || req.user?._id;
        const doc = await MechanicServiceRequest.findById(req.params.id);
        if (!doc) return res.status(404).json({ message: 'Not found' });
        if (doc.userId.toString() !== String(userId)) return res.status(403).json({ message: 'Forbidden' });
        return res.json(doc);
    } catch (e) {
        return res.status(500).json({ message: 'Server error' });
    }
};

// USER: List requests
exports.listUserServiceRequests = async (req, res) => {
    try {
        const userId = req.user?.id || req.user?._id;
        if (!userId) {
            return res.status(401).json({ message: 'User not authenticated' });
        }

        const page = Math.max(parseInt(req.query.page || '1', 10), 1);
        const limit = Math.min(parseInt(req.query.limit || '20', 10), 50);
        const skip = (page - 1) * limit;

        const [items, total] = await Promise.all([
            MechanicServiceRequest.find({ userId })
                .populate('userId', 'fullName phoneNumber')
                .populate('mechanicId', 'personName shopName phoneNumber')
                .sort({ createdAt: -1 })
                .skip(skip)
                .limit(limit),
            MechanicServiceRequest.countDocuments({ userId })
        ]);

        return res.json({ page, limit, total, data: items });
    } catch (e) {
        return res.status(500).json({ message: 'Server error' });
    }
};

// @desc Check for active mechanic request for the logged-in user
exports.getActiveMechanicRequest = async (req, res, next) => {
    try {
        const userId = req.user?.id || req.user?._id;

        if (!userId) {
            return res.status(401).json({ message: 'User not authenticated' });
        }

        const activeRequest = await MechanicServiceRequest.findOne({
            userId: userId,
            status: { $in: ['accepted', 'arrived', 'in-progress'] }
        })
            .populate('mechanicId', 'personName shopName phoneNumber servicesOffered location rating ratingCount address personalPhotoUrl')
            .sort({ createdAt: -1 });

        if (activeRequest) {
            try {
                const { io, userSockets } = req.app?.locals || {};
                if (io && userSockets) {
                    const userSid = userSockets.get(String(userId));
                    if (userSid) {
                        io.to(userSid).emit('rejoin_mechanic_tracking', {
                            requestId: activeRequest._id,
                            mechanicId: activeRequest.mechanicId?._id,
                            status: activeRequest.status,
                            message: 'Please rejoin tracking rooms for crash recovery'
                        });
                    }
                }
            } catch (socketError) {

            }

            return res.status(200).json({
                success: true,
                hasActiveRequest: true,
                data: activeRequest
            });
        }

        res.status(200).json({
            success: true,
            hasActiveRequest: false,
            data: null
        });
    } catch (err) {
        return res.status(500).json({ message: 'Server error' });
    }
};

// @desc Check for active mechanic job for the logged-in mechanic
exports.getActiveMechanicJob = async (req, res, next) => {
    try {
        const mechId = req.mechanic?._id || req.mechanic?.id;

        if (!mechId) {
            return res.status(401).json({ message: 'Mechanic not authenticated' });
        }

        const activeJob = await MechanicServiceRequest.findOne({
            mechanicId: mechId,
            status: { $in: ['accepted', 'arrived', 'in-progress'] }
        })
            .populate('userId', 'fullName phoneNumber')
            .sort({ createdAt: -1 })
            .lean();

        if (activeJob) {
            try {
                const { io, mechanicSockets } = req.app?.locals || {};
                if (io && mechanicSockets) {
                    const mechSid = mechanicSockets.get(String(mechId));
                    if (mechSid) {
                        io.to(mechSid).emit('rejoin_job_tracking', {
                            requestId: activeJob._id,
                            userId: activeJob.userId?._id,
                            status: activeJob.status,
                            message: 'Please rejoin tracking rooms for crash recovery'
                        });
                    }
                }
            } catch (socketError) {

            }

            return res.status(200).json({
                success: true,
                hasActiveJob: true,
                data: activeJob
            });
        }

        return res.status(200).json({
            success: true,
            hasActiveJob: false,
            data: null
        });
    } catch (err) {
        return res.status(500).json({
            message: 'Server error',
            error: process.env.NODE_ENV === 'development' ? err.message : undefined
        });
    }
};

// USER: Cancel request
exports.cancelUserServiceRequest = async (req, res) => {
    const userId = req.user?.id || req.user?._id;
    try {
        const doc = await MechanicServiceRequest.findOneAndUpdate(
            { _id: req.params.id, userId, status: 'accepted' },
            { $set: { status: 'cancelled', cancellation: { cancelledBy: 'user', reason: 'user_cancelled', at: now() } } },
            { new: true }
        );
        if (!doc) return res.status(400).json({ message: 'Cannot cancel (not pending or not owner)' });

        await logActivity({
            action: 'CANCEL_MECHANIC_REQUEST_USER',
            description: `User cancelled mechanic service request: ${doc._id}`,
            performedBy: userId,
            userType: 'User',
            entityId: doc._id,
            entityType: 'request'
        });

        return res.json(doc);
    } catch (e) {
        await logActivity({
            action: 'CANCEL_MECHANIC_REQUEST_USER_ERROR',
            description: e.message,
            performedBy: userId,
            userType: 'User',
            entityId: req.params.id,
            entityType: 'request',
            isError: true,
            errorDetails: e.stack
        });
        return res.status(500).json({ message: 'Server error' });
    }
};

// ==========================
// MECHANIC ROUTES
// ==========================

// Get nearby pending requests
// Controller: Get Nearby Pending Mechanic Service Requests
exports.getNearbyPendingMechanicServiceRequests = async (req, res) => {
    try {
        const mech = req.mechanic;

        // Validate mechanic location
        if (!mech?.location?.coordinates) {
            return res.status(400).json({ message: "Mechanic location missing" });
        }

        // First, handle expired requests
        const now = new Date();
        const expiredRequests = await MechanicServiceRequest.find({
            status: 'pending',
            expiresAt: { $lt: now }
        });

        if (expiredRequests.length > 0) {
            const expiredIds = expiredRequests.map(r => r._id);
            await MechanicServiceRequest.updateMany(
                { _id: { $in: expiredIds } },
                { $set: { status: 'cancelled' } }
            );
        }

        // Parse radius and coordinates
        const radiusKm = parseFloat(req.query.radiusKm || "5");
        const coords = mech.location.coordinates;

        // Build query
        const query = {
            status: "pending",
            expiresAt: { $gt: new Date() },
            serviceType: { $in: mech.servicesOffered || [] },
            userLocation: {
                $near: {
                    $geometry: { type: "Point", coordinates: coords },
                    $maxDistance: radiusKm * 1000
                }
            }
        };

        // Execute query
        const docs = await MechanicServiceRequest.find(query).limit(50);

        // Send response
        return res.json(docs);
    } catch (e) {
        return res.status(500).json({ message: "Server error" });
    }
};

// Accept request
// Controller: acceptMechanicServiceRequest
exports.acceptMechanicServiceRequest = async (req, res) => {
    const mech = req.mechanic;

    try {
        // Build filter for the query
        const filter = {
            _id: req.params.id,
            status: 'pending',
            expiresAt: { $gt: new Date() },
            serviceType: { $in: mech.servicesOffered || [] }
        };

        // Define update to mark as accepted
        const update = {
            $set: { status: 'accepted', mechanicId: mech._id },
            $unset: { expiresAt: 1 }
        };

        // Find and update request
        const doc = await MechanicServiceRequest.findOneAndUpdate(filter, update, { new: true })
            .populate('userId', 'name phoneNumber'); // Populate user data

        if (!doc) {
            return res.status(409).json({ message: 'Already accepted or not eligible' });
        }

        await logActivity({
            action: 'ACCEPT_MECHANIC_REQUEST',
            description: `Mechanic ${mech._id} accepted request ${doc._id}`,
            performedBy: mech._id,
            userType: 'Mechanic',
            entityId: doc._id,
            entityType: 'request'
        });

        // Fetch mechanic profile for socket payload
        const fullMechanicData = await Mechanic.findById(mech._id)
            .select('-otp -otpExpiresAt -__v')
            .lean();

        // Notify user and mechanic via sockets
        try {
            const { io, userSockets, mechanicSockets } = req.app?.locals || {};

            if (io) {
                // Notify user
                const userSid = userSockets?.get(String(doc.userId._id || doc.userId));

                if (userSid) {
                    io.to(userSid).emit('mechanic_request_update', {
                        requestId: doc._id,
                        status: 'accepted',
                        mechanicId: String(mech._id),
                        mechanic: fullMechanicData,
                        requestData: doc
                    });
                }

                // Notify mechanic
                const mechSid = mechanicSockets?.get(String(mech._id));

                if (mechSid) {
                    io.to(mechSid).emit('mechanic_request_update', {
                        requestId: doc._id,
                        status: 'accepted',
                        mechanic: fullMechanicData,
                        requestData: doc
                    });
                }
            }
        } catch (socketError) {

        }

        return res.json(doc);

    } catch (e) {
        await logActivity({
            action: 'ACCEPT_MECHANIC_REQUEST_ERROR',
            description: e.message,
            performedBy: mech._id,
            userType: 'Mechanic',
            entityId: req.params.id,
            entityType: 'request',
            isError: true,
            errorDetails: e.stack
        });
        return res.status(500).json({ message: 'Server error' });
    }
};


// Update request status
exports.updateMechanicServiceRequestStatus = async (req, res) => {
    const mechId = req.mechanic._id;
    const { status } = req.body;
    try {
        const allowed = ['arrived', 'in-progress', 'completed'];
        if (!allowed.includes(status)) {
            return res.status(400).json({ message: 'Invalid status' });
        }

        const doc = await MechanicServiceRequest.findOne({ _id: req.params.id, mechanicId: mechId });
        if (!doc) return res.status(404).json({ message: 'Not found' });
        if (isExpired(doc) && doc.status === 'pending') {
            return res.status(400).json({ message: 'Expired' });
        }

        const transitions = {
            accepted: ['arrived'],
            arrived: ['in-progress'],
            'in-progress': ['completed']
        };

        if (!transitions[doc.status] || !transitions[doc.status].includes(status)) {
            return res.status(400).json({ message: `Invalid transition ${doc.status} -> ${status}` });
        }

        doc.status = status;
        if (status === 'completed') {
            doc.completedAt = new Date();
        }
        await doc.save();

        await logActivity({
            action: `UPDATE_MECHANIC_REQUEST_STATUS`,
            description: `Mechanic ${mechId} updated request ${doc._id} to ${status}`,
            performedBy: mechId,
            userType: 'Mechanic',
            entityId: doc._id,
            entityType: 'request',
            metadata: { newStatus: status }
        });

        // Emit status update to user and mechanic
        try {
            const { io, userSockets, mechanicSockets } = req.app?.locals || {};
            if (io) {
                const userSid = userSockets?.get(String(doc.userId));
                if (userSid) {
                    io.to(userSid).emit('mechanic_request_update', {
                        requestId: doc._id,
                        status: doc.status,
                        mechanicId: String(mechId)
                    });
                }

                const mechSid = mechanicSockets?.get(String(mechId));
                if (mechSid) {
                    io.to(mechSid).emit('mechanic_request_update', {
                        requestId: doc._id,
                        status: doc.status
                    });
                }
            }
        } catch (socketError) {

        }

        return res.json(doc);

    } catch (e) {
        await logActivity({
            action: 'UPDATE_MECHANIC_REQUEST_STATUS_ERROR',
            description: e.message,
            performedBy: mechId,
            userType: 'Mechanic',
            entityId: req.params.id,
            entityType: 'request',
            isError: true,
            errorDetails: e.stack
        });
        return res.status(500).json({ message: 'Server error' });
    }
};
