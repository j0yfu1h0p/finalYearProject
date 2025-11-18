const jwt = require('jsonwebtoken');

/**
 * Middleware to authenticate and authorize users based on JWT tokens.
 * - Logs key steps for debugging purposes.
 * - If token is valid but has no roles, it still proceeds.
 * - If roles exist, attaches role-specific objects (driver, mechanic).
 */
const authenticateToken = (req, res, next) => {


    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1]; // Extract Bearer token

    if (!token) {
        return res.sendStatus(401); // No token, unauthorized
    }

    jwt.verify(token, process.env.JWT_SECRET, (err, decoded) => {
        if (err) {
            return res.sendStatus(403); // Invalid token, forbidden
        }


        // Always attach full decoded payload
        req.user = decoded;

        // Handle roles if present
        if (decoded.roles?.includes('driver')) {
            req.driver = decoded;
        }

        if (decoded.roles?.includes('mechanic')) {
            req.mechanic = decoded;
        }

        // Normalize roles array, or empty if none
        req.roles = decoded.roles || (decoded.role ? [decoded.role] : []);

        // Continue to next middleware/route
        next();
    });
};

/**
 * Middleware to authenticate users for service request routes.
 * - Verifies JWT token.
 * - Attaches decoded user payload to req.user.
 * - Returns 401 if no token, 403 if token invalid.
 * - Designed specifically for routes like listUserServiceRequests.
 */
const authenticateUserToken = (req, res, next) => {


    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
        return res.status(401).json({ message: 'Authentication token required' });
    }

    jwt.verify(token, process.env.JWT_SECRET, (err, decoded) => {
        if (err) {
            return res.status(403).json({ message: 'Invalid or expired token' });
        }


        // Attach only the user info for this route
        req.user = decoded;

        next();
    });
};

module.exports = { authenticateToken ,authenticateUserToken};
