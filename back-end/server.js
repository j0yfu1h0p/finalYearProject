//https://smiling-sparrow-proper.ngrok-free.app/api/admin/auth/create-first-admin
// {
//   "username": "superadmin",
//   "password": "StrongPassword!234"
// }

const mongoose = require('mongoose');
const express = require('express');
const dotenv = require('dotenv');
const cors = require('cors');
const http = require('http');
const jwt = require('jsonwebtoken');
const { Server } = require('socket.io');
const { initializeWhatsAppClient } = require('./services/whatsappService');
const logger = require('./utils/logger');
const errorHandler = require('./middleware/errorHandler');

dotenv.config({ path: './.env' });
const connectDB = require('./config/db');

const Driver = require('./models/Driver');
const Mechanic = require('./models/Mechanic');
const ServiceRequest = require('./models/ServiceRequest');
const MechanicServiceRequest = require('./models/MechanicServiceRequest');
const Message = require('./models/Message');

const app = express();
const server = http.createServer(app);

const io = new Server(server, {
    cors: {
        origin: "*",
        methods: ["GET", "POST"]
    }
});

const driverSockets = new Map();
const mechanicSockets = new Map();
const userSockets = new Map();
const driverLocations = new Map();
const mechanicLocations = new Map();
const driverTimers = new Map();
const mechanicTimers = new Map();

const activeUserTrips = new Map();
const activeDriverTrips = new Map();
const activeMechanicRequests = new Map();
const userLastSeen = new Map();
const driverLastSeen = new Map();
const mechanicLastSeen = new Map();

const roomUser = (id) => `user_${id}`;
const roomDriver = (id) => `driver_${id}`;
const roomMechanic = (id) => `mechanic_${id}`;
const roomTrip = (id) => `trip_${id}`;

const emitToUser = (userId, event, payload) => {
    const sid = userSockets.get(String(userId));
    if (sid) io.to(sid).emit(event, payload);
};
const emitToDriver = (driverId, event, payload) => {
    const sid = driverSockets.get(String(driverId));
    if (sid) io.to(sid).emit(event, payload);
};
const emitToMechanic = (mechanicId, event, payload) => {
    const sid = mechanicSockets.get(String(mechanicId));
    if (sid) io.to(sid).emit(event, payload);
};
const emitToTrip = (tripId, event, payload) => {
    io.to(roomTrip(tripId)).emit(event, payload);
};

io.on("connection", (socket) => {
    const safeJoin = (room) => {
        try { socket.join(room); } catch (_) { }
    };
    const safeLeave = (room) => {
        try { socket.leave(room); } catch (_) { }
    };

    const registerSocket = async (decoded) => {
        const id = String(decoded.id);
        socket.data.userId = id;
        socket.data.roles = decoded.roles || [decoded.role];

        if (socket.data.roles?.includes('driver') || decoded.role === 'driver') {
            driverSockets.set(id, socket.id);
            safeJoin(roomDriver(id));
            startDriverLocationUpdates(id);

            try {
                const driver = await Driver.findById(id);
                if (driver) {
                    socket.emit('driver_status_changed', {
                        status: driver.personal_info?.registration_status || 'pending',
                        timestamp: new Date()
                    });
                }
            } catch (e) {

            }
        }

        if (socket.data.roles?.includes('mechanic') || decoded.role === 'mechanic') {
            mechanicSockets.set(id, socket.id);
            safeJoin(roomMechanic(id));
            startMechanicLocationUpdates(id);

            try {
                const mechanic = await Mechanic.findById(id);
                if (mechanic) {
                    socket.emit('mechanic_status_changed', {
                        status: mechanic.registrationStatus || 'pending',
                        timestamp: new Date()
                    });
                }
            } catch (e) {

            }
        }

        userSockets.set(id, socket.id);
        safeJoin(roomUser(id));

        socket.emit("authenticated", {
            success: true,
            roles: socket.data.roles,
            message: `Authenticated as ${socket.data.roles.join(', ')}`
        });
    };

    socket.on("authenticate", async (token) => {
        try {
            const decoded = jwt.verify(token, process.env.JWT_SECRET);
            await registerSocket(decoded);
        } catch (err) {
            socket.emit("authenticated", { success: false, message: "Invalid token" });
            socket.disconnect();
        }
    });

    socket.on("driver_authenticate", async (token) => {
        try {
            const decoded = jwt.verify(token, process.env.JWT_SECRET);
            await registerSocket(decoded);
        } catch (err) {
            socket.emit("authenticated", { success: false, message: "Invalid token" });
            socket.disconnect();
        }
    });

    socket.on('join_trip_chat', async ({ tripId }) => {
        if (!tripId) return;
        safeJoin(roomTrip(tripId));
        try {
            const messages = await Message.find({ tripId }).sort({ timestamp: 1 }).limit(50);
            socket.emit('chat_history', messages);
        } catch (err) {

        }
    });

    socket.on('leave_trip_chat', ({ tripId }) => {
        if (!tripId) return;
        safeLeave(roomTrip(tripId));
    });

    socket.on('send_message', async (data) => {
        try {
            const { tripId, message, tripModel } = data || {};
            if (!tripId || !message || !socket.data.userId) return;

            const senderId = socket.data.userId;
            const roles = socket.data.roles || [];

            let senderModel = 'Customer';
            if (tripModel === 'ServiceRequest' && roles.includes('driver')) {
                senderModel = 'Driver';
            } else if (tripModel === 'MechanicServiceRequest' && roles.includes('mechanic')) {
                senderModel = 'Mechanic';
            } else if (roles.includes('driver')) {
                senderModel = 'Driver';
            } else if (roles.includes('mechanic')) {
                senderModel = 'Mechanic';
            }

            const finalTripModel = ['ServiceRequest', 'MechanicServiceRequest'].includes(tripModel)
                ? tripModel
                : 'ServiceRequest';

            const newMessage = new Message({
                sender: senderId,
                senderModel,
                message,
                tripId,
                tripModel: finalTripModel,
            });

            await newMessage.save();

            const populatedMessage = await Message.findById(newMessage._id).populate('sender', 'fullName profile_image');

            emitToTrip(tripId, 'new_message', populatedMessage);

        } catch (error) {
            socket.emit('chat_error', { message: 'Failed to send message.' });
        }
    });

    socket.on('driver_location_update', (data) => {
        const { driverId, location } = data || {};
        if (!driverId) return;

        driverLocations.set(String(driverId), location);

        socket.to(roomDriver(driverId)).emit('driver_location_update', {
            driverId,
            location,
            timestamp: new Date()
        });

        if (socket.data.currentTripId) {
            socket.to(roomTrip(socket.data.currentTripId)).emit('driver_location_update', {
                driverId,
                location,
                timestamp: new Date()
            });
        }
    });

    socket.on('mechanic_location_update', (data) => {
        const { mechanicId, location } = data || {};
        if (!mechanicId) return;

        mechanicLocations.set(String(mechanicId), location);

        socket.to(roomMechanic(mechanicId)).emit('mechanic_location_update', {
            mechanicId,
            location,
            timestamp: new Date()
        });

        if (socket.data.currentRequestId) {
            socket.to(roomTrip(socket.data.currentRequestId)).emit('mechanic_location_update', {
                mechanicId,
                location,
                timestamp: new Date()
            });
        }
    });

    socket.on('join_driver_tracking', (data) => {
        const { driverId, tripId } = data || {};
        if (driverId) safeJoin(roomDriver(driverId));
        if (tripId) {
            safeJoin(roomTrip(tripId));
            socket.data.currentTripId = tripId;
        }

        if (driverId && driverLocations.has(String(driverId))) {
            socket.emit('driver_location_update', {
                driverId,
                location: driverLocations.get(String(driverId)),
                timestamp: new Date()
            });
        }
    });

    socket.on('rejoin_trip_tracking', async ({ driverId, tripId }) => {
        try {
            const activeTrip = await ServiceRequest.findOne({
                _id: tripId,
                driverId: driverId,
                status: { $in: ['accepted', 'arrived', 'in_progress'] }
            }).populate('userId', 'fullName phoneNumber');

            if (activeTrip) {
                safeJoin(roomTrip(tripId));
                safeJoin(roomDriver(driverId));
                socket.data.currentTripId = tripId;

                const userId = activeTrip.userId?._id?.toString();
                const userSocketId = userId ? userSockets.get(userId) : null;

                socket.emit('rejoin_trip_tracking', {
                    success: true,
                    tripId: activeTrip._id,
                    status: activeTrip.status,
                    userId: userId,
                    userConnected: !!userSocketId,
                    tripData: activeTrip
                });

                if (userSocketId) {
                    io.to(userSocketId).emit('driver_reconnected', {
                        tripId: activeTrip._id,
                        driverId: driverId,
                        timestamp: new Date()
                    });
                }

                if (driverLocations.has(String(driverId))) {
                    socket.emit('driver_location_update', {
                        driverId,
                        location: driverLocations.get(String(driverId)),
                        timestamp: new Date()
                    });
                }

            } else {
                socket.emit('rejoin_trip_tracking', {
                    success: false,
                    message: 'No active trip found'
                });
            }
        } catch (error) {
            socket.emit('rejoin_trip_tracking', {
                success: false,
                message: 'Error rejoining trip'
            });
        }
    });

    socket.on('join_mechanic_tracking', (data) => {
        const { mechanicId, requestId } = data || {};
        if (mechanicId) safeJoin(roomMechanic(mechanicId));
        if (requestId) {
            safeJoin(roomTrip(requestId));
            socket.data.currentRequestId = requestId;
        }

        if (mechanicId && mechanicLocations.has(String(mechanicId))) {
            socket.emit('mechanic_location_update', {
                mechanicId,
                location: mechanicLocations.get(String(mechanicId)),
                timestamp: new Date()
            });
        }
    });

    socket.on('join_trip', ({ tripId }) => {
        if (tripId) {
            safeJoin(roomTrip(tripId));
            socket.data.currentTripId = tripId;
        }
    });

    socket.on('join_request', ({ serviceRequestId }) => {
        if (serviceRequestId) {
            safeJoin(roomTrip(serviceRequestId));
            socket.data.currentRequestId = serviceRequestId;
        }
    });

    socket.on('leave_request', ({ serviceRequestId }) => {
        if (serviceRequestId) {
            safeLeave(roomTrip(serviceRequestId));
            if (socket.data.currentRequestId === serviceRequestId) {
                socket.data.currentRequestId = null;
            }
        }
    });

    socket.on('driver_arrived_pickup', async ({ tripId, driverId }) => {
        try {
            const updatedTrip = await ServiceRequest.findByIdAndUpdate(
                tripId,
                {
                    status: 'arrived',
                    arrivedAt: new Date()
                },
                { new: true }
            );

            if (updatedTrip) {
                emitToTrip(tripId, 'ride_status_update', {
                    status: 'arrived',
                    tripId,
                    driverId,
                    arrivedAt: new Date().toISOString()
                });
            }
        } catch (error) {

        }
    });

    socket.on('trip_started', async ({ tripId, driverId }) => {
        try {
            const updatedTrip = await ServiceRequest.findByIdAndUpdate(
                tripId,
                {
                    status: 'in_progress',
                    startedAt: new Date()
                },
                { new: true }
            );

            if (updatedTrip) {
                emitToTrip(tripId, 'ride_status_update', {
                    status: 'started',
                    tripId,
                    driverId,
                    startedAt: new Date().toISOString()
                });
            }
        } catch (error) {

        }
    });

    socket.on('driver_completed_trip', async ({ tripId, driverId }) => {
        try {
            const updatedTrip = await ServiceRequest.findByIdAndUpdate(
                tripId,
                {
                    status: 'completed',
                    completedAt: new Date()
                },
                { new: true }
            );

            if (updatedTrip) {
                emitToTrip(tripId, 'ride_status_update', {
                    status: 'completed',
                    tripId,
                    driverId,
                    completedAt: new Date().toISOString()
                });

                if (updatedTrip.userId) {
                    emitToUser(updatedTrip.userId, 'ride_status_update', {
                        tripId: updatedTrip._id,
                        status: 'completed',
                        driverId: String(driverId),
                        completedAt: new Date().toISOString()
                    });
                }
            }
        } catch (error) {

        }
    });

    socket.on('mechanic_arrived', ({ requestId, mechanicId }) => {
        emitToTrip(requestId, 'mechanic_status_update', {
            status: 'arrived',
            requestId,
            mechanicId,
            arrivedAt: new Date().toISOString()
        });
    });

    socket.on('mechanic_job_started', ({ requestId, mechanicId }) => {
        emitToTrip(requestId, 'mechanic_status_update', {
            status: 'in-progress',
            requestId,
            mechanicId,
            startedAt: new Date().toISOString()
        });
    });

    socket.on('mechanic_job_completed', async ({ requestId, mechanicId }) => {
        try {
            const updatedRequest = await MechanicServiceRequest.findByIdAndUpdate(
                requestId,
                {
                    status: 'completed',
                    completedAt: new Date()
                },
                { new: true }
            );

            if (updatedRequest) {
                emitToTrip(requestId, 'mechanic_status_update', {
                    status: 'completed',
                    requestId,
                    mechanicId,
                    completedAt: new Date().toISOString()
                });

                if (updatedRequest.userId) {
                    emitToUser(updatedRequest.userId, 'mechanic_request_update', {
                        requestId: updatedRequest._id,
                        status: 'completed',
                        mechanicId: String(mechanicId),
                        completedAt: new Date().toISOString()
                    });
                }
            }
        } catch (error) {

        }
    });

    socket.on('mechanic_cancelled_job', async ({ requestId, userId, mechanicId }) => {
        try {
            const updatedRequest = await MechanicServiceRequest.findByIdAndUpdate(
                requestId,
                {
                    status: 'cancelled',
                    cancelledAt: new Date(),
                    cancellation: {
                        cancelledBy: 'mechanic',
                        reason: 'mechanic_cancelled',
                        at: new Date()
                    }
                },
                { new: true }
            );

            if (updatedRequest) {
                emitToTrip(requestId, 'mechanic_status_update', {
                    status: 'cancelled',
                    requestId,
                    mechanicId,
                    cancelledAt: new Date().toISOString(),
                    message: 'Mechanic cancelled the job'
                });

                if (userId) {
                    emitToUser(userId, 'mechanic_status_update', {
                        status: 'cancelled',
                        requestId,
                        mechanicId,
                        cancelledAt: new Date().toISOString(),
                        message: 'Mechanic cancelled the job'
                    });
                }
            }
        } catch (error) {

        }
    });

    socket.on('driver_cancelled_ride', async ({ requestId, userId, driverId }) => {
        try {
            const updatedTrip = await ServiceRequest.findByIdAndUpdate(
                requestId,
                {
                    status: 'cancelled',
                    cancelledAt: new Date(),
                    cancellation: {
                        cancelledBy: 'driver',
                        reason: 'driver_cancelled',
                        at: new Date()
                    }
                },
                { new: true }
            );

            if (updatedTrip) {
                emitToTrip(requestId, 'ride_status_update', {
                    status: 'cancelled',
                    requestId,
                    driverId,
                    cancelledAt: new Date().toISOString(),
                    message: 'Driver cancelled the ride'
                });

                if (userId) {
                    emitToUser(userId, 'ride_status_update', {
                        status: 'cancelled',
                        requestId,
                        driverId,
                        cancelledAt: new Date().toISOString(),
                        message: 'Driver cancelled the ride'
                    });
                }
            }
        } catch (error) {

        }
    });

    socket.on('user_cancelled_ride', async (data) => {
        const { requestId, driverId } = data || {};

        if (driverId) {
            emitToDriver(driverId, 'ride_status_update', {
                status: 'cancelled',
                requestId,
                cancelledAt: new Date().toISOString(),
                message: 'Ride cancelled by user',
                type: 'user_cancelled_ride'
            });
            emitToDriver(driverId, 'user_cancelled_ride', {
                requestId,
                cancelledAt: new Date().toISOString(),
                message: 'Ride cancelled by user'
            });
        }

        emitToTrip(requestId, 'ride_status_update', {
            status: 'cancelled',
            requestId,
            cancelledAt: new Date().toISOString(),
            message: 'Ride cancelled by user',
            type: 'user_cancelled_ride'
        });

        emitToTrip(requestId, 'user_cancelled_ride', {
            requestId,
            cancelledAt: new Date().toISOString(),
            message: 'Ride cancelled by user'
        });

        try {
            await ServiceRequest.findByIdAndUpdate(requestId, {
                status: 'cancelled',
                cancelledAt: new Date(),
                cancellationReason: 'Cancelled by user'
            });
        } catch (error) {

        }
    });

    socket.on('request_status_sync', async () => {
        const { userId, roles } = socket.data;
        if (!userId) return;

        try {
            if (roles?.includes('driver')) {
                const driver = await Driver.findById(userId);
                if (driver) {
                    socket.emit('driver_status_changed', {
                        status: driver.personal_info?.registration_status || 'pending',
                        timestamp: new Date()
                    });
                }
            }

            if (roles?.includes('mechanic')) {
                const mechanic = await Mechanic.findById(userId);
                if (mechanic) {
                    socket.emit('mechanic_status_changed', {
                        status: mechanic.registrationStatus || 'pending',
                        timestamp: new Date()
                    });
                }
            }
        } catch (error) {

        }
    });

    socket.on('register_active_trip', async ({ tripId, driverId, userId }) => {
        if (tripId && driverId && userId) {
            activeUserTrips.set(String(userId), { tripId, type: 'ride', driverId });
            activeDriverTrips.set(String(driverId), { tripId, userId });
            socket.data.currentTripId = tripId;
        }
    });

    socket.on('register_active_mechanic_request', async ({ requestId, mechanicId, userId }) => {
        if (requestId && mechanicId && userId) {
            activeUserTrips.set(String(userId), { tripId: requestId, type: 'mechanic', mechanicId });
            activeMechanicRequests.set(String(mechanicId), { requestId, userId });
            socket.data.currentRequestId = requestId;
        }
    });

    socket.on('clear_active_trip', ({ userId, driverId, tripId }) => {
        if (userId) activeUserTrips.delete(String(userId));
        if (driverId) activeDriverTrips.delete(String(driverId));
        socket.data.currentTripId = null;
    });

    socket.on('clear_active_mechanic_request', ({ userId, mechanicId, requestId }) => {
        if (userId) activeUserTrips.delete(String(userId));
        if (mechanicId) activeMechanicRequests.delete(String(mechanicId));
        socket.data.currentRequestId = null;
    });

    socket.on('check_active_ride', async () => {
        const { userId } = socket.data;
        if (!userId) return;

        try {
            const activeRide = await ServiceRequest.findOne({
                userId: userId,
                status: { $in: ['accepted', 'arrived', 'in_progress'] }
            }).populate('driverId', 'personal_info phoneNumber vehicles');

            if (activeRide) {
                socket.emit('active_ride_found', {
                    tripId: activeRide._id,
                    status: activeRide.status,
                    driverId: activeRide.driverId?._id,
                    driverData: activeRide.driverId,
                    serviceRequest: activeRide,
                    type: 'ride'
                });
            } else {
                socket.emit('no_active_ride');
            }
        } catch (error) {
            socket.emit('no_active_ride');
        }
    });

    socket.on('disconnect', () => {
        const { userId, roles, currentTripId, currentRequestId } = socket.data || {};
        if (userId) {
            userLastSeen.set(String(userId), Date.now());

            if (roles?.includes('driver')) {
                if (driverSockets.get(userId) === socket.id) {
                    driverSockets.delete(userId);
                    stopDriverLocationUpdates(userId);
                    driverLastSeen.set(String(userId), Date.now());

                    const activeTrip = activeDriverTrips.get(userId);
                    if (activeTrip) {
                        emitToUser(activeTrip.userId, 'driver_disconnected', {
                            driverId: userId,
                            tripId: activeTrip.tripId,
                            timestamp: new Date(),
                            message: 'Driver connection lost. They may reconnect shortly.'
                        });

                        emitToTrip(activeTrip.tripId, 'driver_disconnected', {
                            driverId: userId,
                            tripId: activeTrip.tripId,
                            timestamp: new Date()
                        });
                    }
                }
            }

            if (roles?.includes('mechanic')) {
                if (mechanicSockets.get(userId) === socket.id) {
                    mechanicSockets.delete(userId);
                    stopMechanicLocationUpdates(userId);
                    mechanicLastSeen.set(String(userId), Date.now());

                    const activeRequest = activeMechanicRequests.get(userId);
                    if (activeRequest) {
                        emitToUser(activeRequest.userId, 'mechanic_disconnected', {
                            mechanicId: userId,
                            requestId: activeRequest.requestId,
                            timestamp: new Date(),
                            message: 'Mechanic connection lost. They may reconnect shortly.'
                        });

                        emitToTrip(activeRequest.requestId, 'mechanic_disconnected', {
                            mechanicId: userId,
                            requestId: activeRequest.requestId,
                            timestamp: new Date()
                        });
                    }
                }
            }

            if (userSockets.get(userId) === socket.id) {
                userSockets.delete(userId);

                const userActiveTrip = activeUserTrips.get(userId);
                if (userActiveTrip) {
                    if (userActiveTrip.type === 'ride' && userActiveTrip.driverId) {
                        emitToDriver(userActiveTrip.driverId, 'user_disconnected', {
                            userId: userId,
                            tripId: userActiveTrip.tripId,
                            timestamp: new Date(),
                            message: 'User connection lost. They may reconnect shortly.'
                        });
                    } else if (userActiveTrip.type === 'mechanic' && userActiveTrip.mechanicId) {
                        emitToMechanic(userActiveTrip.mechanicId, 'user_disconnected', {
                            userId: userId,
                            requestId: userActiveTrip.tripId,
                            timestamp: new Date(),
                            message: 'User connection lost. They may reconnect shortly.'
                        });
                    }
                }
            }
        }
    });
});

function findDriverSocket(driverId) {
    const sockets = io.sockets.sockets;
    for (const [id, socket] of sockets) {
        if (socket.driverId === driverId) {
            return socket;
        }
    }
    return null;
}

function startDriverLocationUpdates(driverId) {
    stopDriverLocationUpdates(driverId);

    const timer = setInterval(() => {
        const socketId = driverSockets.get(driverId);
        if (socketId) {
            io.to(socketId).emit('request_location_update', {
                driverId,
                role: 'driver',
                timestamp: new Date()
            });
        }
    }, 10000);

    driverTimers.set(driverId, timer);
}

function stopDriverLocationUpdates(driverId) {
    const timer = driverTimers.get(driverId);
    if (timer) {
        clearInterval(timer);
        driverTimers.delete(driverId);
    }
}

function startMechanicLocationUpdates(mechanicId) {
    stopMechanicLocationUpdates(mechanicId);

    const timer = setInterval(() => {
        const socketId = mechanicSockets.get(mechanicId);
        if (socketId) {
            io.to(socketId).emit('request_location_update', {
                mechanicId,
                role: 'mechanic',
                timestamp: new Date()
            });
        }
    }, 10000);

    mechanicTimers.set(mechanicId, timer);
}

function stopMechanicLocationUpdates(mechanicId) {
    const timer = mechanicTimers.get(mechanicId);
    if (timer) {
        clearInterval(timer);
        mechanicTimers.delete(mechanicId);
    }
}

app.use(express.json());
app.use(cors());
app.use(logger.responseObserverMiddleware);
app.use(logger.requestLoggerMiddleware);

const authRoutes = require('./routes/userAuthRoutes');
const serviceRoutes = require('./routes/serviceRoutes');
const historyRoutes = require('./routes/historyRoutes');
const driverAuthRoutes = require('./routes/driverAuthRoutes');
const driverRoutes = require('./routes/driverRoutes');
const adminRoutes = require('./routes/adminRoutes');
const adminAuthRoutes = require('./routes/adminAuthRoutes');
const userRoutes = require('./routes/userRoutes');
const rateRoutes = require("./routes/rateRoutes");
const mechanicAuthRoutes = require('./routes/mechanicAuthRoutes');
const mechanicRoutes = require('./routes/mechanicRoutes');
const mechanicServiceRequestRoutes = require('./routes/mechanicServiceRequestRoutes');
const professionalRoutes = require('./routes/professionalRoutes');
const chatRoutes = require('./routes/chatRoutes');

app.use('/api/user/auth/', authRoutes);
app.use('/api/v1/services', serviceRoutes);
app.use('/api/history', historyRoutes);
app.use('/api/driver/auth', driverAuthRoutes);
app.use('/api/driver', driverRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/admin/auth', adminAuthRoutes);
app.use('/api/v1/users', userRoutes);
app.use("/api/trip/rates", rateRoutes);
app.use('/api/mechanic/auth', mechanicAuthRoutes);
app.use('/api/mechanic', mechanicRoutes);
app.use('/api/mechanic/requests', mechanicServiceRequestRoutes);
app.use('/api/professional', professionalRoutes);
app.use('/api/chat', chatRoutes);

app.use(errorHandler);

app.locals.io = io;
app.locals.driverSockets = driverSockets;
app.locals.mechanicSockets = mechanicSockets;
app.locals.userSockets = userSockets;
app.locals.driverLocations = driverLocations;
app.locals.mechanicLocations = mechanicLocations;

const PORT = process.env.PORT || 5000;
connectDB().then(() => {
    server.listen(PORT, () => {
        logger.info(`Server running on port ${PORT}`);
        initializeWhatsAppClient();
    });
});

process.on('unhandledRejection', (reason) => {
    logger.error('Unhandled promise rejection', { error: reason });
});

process.on('uncaughtException', (error) => {
    logger.error('Uncaught exception', { error });
});
