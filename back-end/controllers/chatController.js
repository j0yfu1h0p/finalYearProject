const Message = require('../models/Message');
const ServiceRequest = require('../models/ServiceRequest');
const MechanicServiceRequest = require('../models/MechanicServiceRequest');

// Get chat history for a specific trip
exports.getChatHistory = async (req, res) => {
    try {
        const { tripId } = req.params;
        const messages = await Message.find({ tripId })
            .populate('sender', 'fullName profile_image') // Also populate profile_image
            .sort({ timestamp: 'asc' });

        res.status(200).json(messages);
    } catch (error) {
        res.status(500).json({ message: 'Error fetching chat history' });
    }
};

// Send a message (API version)
exports.sendMessage = async (req, res) => {
    try {
        const { tripId, message, tripModel } = req.body;
        const user = req.user || {};

        if (!tripId || !message) {
            return res.status(400).json({ message: 'tripId and message are required' });
        }

        // Determine sender model based on roles
        const roles = user.roles || (user.role ? [user.role] : []);
        let senderModel = 'Customer';
        if (roles.includes('driver')) senderModel = 'Driver';
        else if (roles.includes('mechanic')) senderModel = 'Mechanic';

        // Determine trip model if not provided
        let finalTripModel = tripModel;
        if (!finalTripModel) {
            const isRide = await ServiceRequest.exists({ _id: tripId });
            if (isRide) finalTripModel = 'ServiceRequest';
            else {
                const isMech = await MechanicServiceRequest.exists({ _id: tripId });
                if (isMech) finalTripModel = 'MechanicServiceRequest';
            }
        }

        if (!['ServiceRequest', 'MechanicServiceRequest'].includes(finalTripModel)) {
            return res.status(400).json({ message: 'Invalid or unknown tripModel' });
        }

        const newMessage = await Message.create({
            sender: user.id,
            senderModel,
            message,
            tripId,
            tripModel: finalTripModel
        });

        res.status(201).json(newMessage);
    } catch (error) {
        res.status(500).json({ message: 'Error sending message' });
    }
};