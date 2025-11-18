const Driver = require('../models/Driver');
const mongoose = require('mongoose');
const { logActivity } = require('../services/activityLogService');
const ServiceRequest = require('../models/ServiceRequest'); // Assuming the model is in the same directory

exports.registerDriver = async (req, res) => {
    const { personal_info, identification, license, vehicles } = req.body;

    try {
        const driver = await Driver.findById(req.driver.id);
        if (!driver) {
            return res.status(404).json({ message: 'Driver not found.' });
        }

        driver.personal_info = {
            ...personal_info,
            registration_status: 'pending',
            last_updated: new Date()
        };
        driver.identification = identification;
        driver.license = license;
        driver.vehicles = vehicles;

        await driver.save();

        await logActivity({
            action: 'DRIVER_REGISTER',
            description: `Driver submitted registration for approval: ${driver._id}`,
            entityType: 'driver',
            entityId: driver._id,
            performedBy: driver._id,
            userType: 'Driver'
        });

        res.status(200).json({
            message: 'Driver registration submitted for approval',
            registrationStatus: 'pending'
        });

    } catch (error) {
        await logActivity({
            action: 'DRIVER_REGISTER_ERROR',
            description: error.message,
            entityType: 'driver',
            entityId: req.driver.id,
            performedBy: req.driver.id,
            userType: 'Driver',
            isError: true,
            errorDetails: error.stack
        });
        res.status(500).json({ message: 'Server error during registration' });
    }
};

exports.getDriverProfileByID = async (req, res) => {
    try {
        const { id } = req.params;

        if (!mongoose.Types.ObjectId.isValid(id)) {
            return res.status(400).json({ success: false, message: 'Invalid driver ID' });
        }

        const driver = await Driver.findById(id).select('phoneNumber personal_info vehicles rating');

        if (!driver) {
            return res.status(404).json({ success: false, message: 'Driver not found' });
        }

        const driverProfile = {
            personal_info: {
                name: `${driver.personal_info.first_name || ''} ${driver.personal_info.last_name || ''}`.trim(),
                phone: driver.phoneNumber,
                avatar: driver.personal_info.profile_photo_url
            },
            vehicles: driver.vehicles.map(vehicle => ({
                plate: vehicle.number_plate,
                color: vehicle.color
            }))
        };

        res.json({ success: true, profile: driverProfile });
    } catch (error) {
        res.status(500).json({ success: false, message: 'Server error' });
    }
};

exports.getDriverProfile = async (req, res) => {
    try {
        const driver = await Driver.findById(req.driver.id)
            .select('-otp -__v');

        if (!driver) {
            return res.status(404).json({ message: 'Driver not found' });
        }

        res.status(200).json(driver);

    } catch (error) {
        res.status(500).json({ message: 'Server error fetching driver profile' });
    }
};

exports.getPendingUpdates = async (req, res) => {
    try {
        const driver = await Driver.findById(req.driver.id);
        if (!driver) return res.status(404).json({ message: 'Driver not found' });

        const lastSeen = new Date(req.query.lastSeen || 0);
        const updates = driver.adminActions.filter(
            action => action.timestamp > lastSeen
        );

        const lastUpdate = updates.length > 0 ? updates[updates.length - 1] : null;

        res.status(200).json({
            statusChanged: !!lastUpdate,
            newStatus: lastUpdate ? driver.personal_info.registration_status : null,
            timestamp: lastUpdate ? lastUpdate.timestamp : null
        });
    } catch (error) {
        res.status(500).json({ message: 'Server error fetching updates' });
    }
};

exports.checkCNIC = async (req, res) => {
    try {
        const driver = await Driver.findOne({ 'identification.cnic_number': req.query.cnic });
        res.json({ exists: !!driver });
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
};

exports.checkLicense = async (req, res) => {
    try {
        const driver = await Driver.findOne({ 'license.license_number': req.query.license });
        res.json({ exists: !!driver });
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
};

exports.checkPlate = async (req, res) => {
    try {
        const exists = await Driver.findOne({ 'vehicles.number_plate': req.query.plate });
        res.json({ exists: !!exists });
    } catch (error) {
        res.status(500).json({ message: 'Server error' });
    }
};

exports.getNearbyPendingRequests = async (req, res) => {
    try {
        const { latitude, longitude } = req.body;
        const driver = req.driver;

        if (!latitude || !longitude) {
            return res.status(400).json({ message: "Your current location (latitude, longitude) is required." });
        }

        // First, handle expired requests
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
            expiresAt: { $gt: now }, // Only get requests that have not expired
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
