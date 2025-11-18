const jwt = require('jsonwebtoken');
const Mechanic = require('../models/Mechanic');

module.exports = async function mechanicAuth(req, res, next) {
    try {
        // Extract Authorization header
        const header = req.header('Authorization');
        if (!header) {
            return res.status(401).json({ message: 'No token provided' });
        }

        const token = header.replace('Bearer ', '').trim();
        if (!token) {
            return res.status(401).json({ message: 'Token missing' });
        }

        // Verify JWT
        let decoded;
        try {
            decoded = jwt.verify(token, process.env.JWT_SECRET);
        } catch (e) {
            return res.status(401).json({ message: 'Invalid or expired token' });
        }

        // Extract mechanic ID (supports new unified and legacy tokens)
        const mechanicId =
            decoded.mechanicId ||
            (decoded.role === 'mechanic' ? decoded.id : null);

        if (!mechanicId) {
            return res.status(401).json({ message: 'Mechanic ID missing in token' });
        }

        // Validate mechanic ID format
        if (!mechanicId.match(/^[0-9a-fA-F]{24}$/)) {
            return res.status(401).json({ message: 'Invalid mechanic ID format' });
        }

        // Load mechanic from DB
        const mechanic = await Mechanic.findById(mechanicId);
        if (!mechanic) {
            return res.status(401).json({ message: 'Mechanic not found' });
        }

        // Check if account is suspended
        if (mechanic.isSuspended) {
            return res.status(401).json({ message: 'Account suspended' });
        }

        // Attach mechanic and token info to request object
        req.mechanic = mechanic;
        req.tokenPayload = decoded;

        next();

    } catch (e) {
        return res.status(500).json({
            message: 'Auth middleware error',
            ...(process.env.NODE_ENV === 'development' && { error: e.message })
        });
    }
};
