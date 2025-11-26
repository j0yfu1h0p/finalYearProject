const mongoose = require('mongoose');
const Review = require('../models/Review');
const ServiceRequest = require('../models/ServiceRequest');
const MechanicServiceRequest = require('../models/MechanicServiceRequest');
const Driver = require('../models/Driver');
const Mechanic = require('../models/Mechanic');
const Customer = require('../models/Customer');
const { logActivity } = require('../services/activityLogService');

const normalizeRating = (value) => {
    const rating = Number(value);
    if (!Number.isFinite(rating)) return null;
    if (rating < 1 || rating > 5) return null;
    return Math.round(rating * 2) / 2; // support halves while keeping range
};

const buildHttpError = (status, message) => {
    const err = new Error(message);
    err.status = status;
    return err;
};

const sanitizeComment = (comment) => {
    if (!comment) return '';
    return comment.toString().trim().slice(0, 1000);
};

const updateAggregateRating = async ({ model, id, rating, session }) => {
    let q = model.findById(id);
    if (session) q = q.session(session);
    const doc = await q.select('rating ratingCount lastReviewAt');
    if (!doc) {
        throw new Error('Review target not found');
    }

    const existingCount = doc.ratingCount || 0;
    const existingAverage = doc.rating || 0;
    const newCount = existingCount + 1;
    const newAverage = Math.round((((existingAverage * existingCount) + rating) / newCount) * 100) / 100;

    doc.rating = newAverage;
    doc.ratingCount = newCount;
    doc.lastReviewAt = new Date();
    await doc.save(session ? { session } : undefined);
};

const runWithOptionalTransaction = async (operation) => {
    // Try to run with a real transaction; if server doesn't support transactions
    // (standalone MongoDB), fall back to running without a session.
    let session = null;
    try {
        session = await mongoose.startSession();
        try {
            await session.withTransaction(async () => { await operation(session); });
        } catch (err) {
            // Specific message from the MongoDB driver when transactions aren't supported
            if (err && err.message && err.message.includes('Transaction numbers are only allowed')) {
                await session.endSession();
                session = null;
                await operation(null);
            } else throw err;
        }
    } finally {
        if (session) session.endSession();
    }
};

const buildReviewPayload = ({
    serviceType,
    request,
    reviewerId,
    reviewerModel = 'Customer',
    revieweeId,
    revieweeModel,
    rating,
    comment,
    metadata
}) => ({
    serviceType,
    requestId: request._id,
    requestModel: request.constructor.modelName,
    reviewer: reviewerId,
    reviewerModel,
    reviewee: revieweeId,
    revieweeModel,
    rating,
    comment: sanitizeComment(comment),
    rideEndedAt: request.completedAt || request.updatedAt || new Date(),
    metadata
});

exports.createTowingReview = async (req, res, next) => {
    const ratingValue = normalizeRating(req.body.rating);
    if (!ratingValue) {
        return res.status(400).json({ success: false, message: 'Rating must be between 1 and 5 stars.' });
    }

    try {
        let reviewDoc;
        await runWithOptionalTransaction(async (session) => {
            let rq = ServiceRequest.findOne({ _id: req.params.id, userId: req.user.id });
            if (session) rq = rq.session(session);
            const request = await rq;

            if (!request) {
                throw buildHttpError(404, 'Service request not found.');
            }

            if (request.status !== 'completed') {
                throw buildHttpError(400, 'Ride must be completed before leaving a review.');
            }

            if (request.reviewId) {
                throw buildHttpError(409, 'Review already submitted for this ride.');
            }

            if (!request.driverId) {
                throw buildHttpError(400, 'Driver information missing for this ride.');
            }

            const [review] = await Review.create([
                buildReviewPayload({
                    serviceType: 'towing',
                    request,
                    reviewerId: req.user.id,
                    revieweeId: request.driverId,
                    revieweeModel: 'Driver',
                    rating: ratingValue,
                    comment: req.body.comment,
                    metadata: {
                        vehicleType: request.vehicleType,
                        serviceCategory: request.rate
                    }
                })
            ], session ? { session } : undefined);

            request.reviewId = review._id;
            await request.save(session ? { session } : undefined);

            await updateAggregateRating({ model: Driver, id: request.driverId, rating: ratingValue, session });

            reviewDoc = review;

            await logActivity({
                action: 'CREATE_RIDE_REVIEW',
                description: `User ${req.user.id} reviewed driver ${request.driverId}`,
                performedBy: req.user.id,
                userType: 'User',
                entityId: review._id,
                entityType: 'review',
                metadata: { serviceRequestId: request._id, rating: ratingValue }
            });
        });

        return res.status(201).json({ success: true, message: 'Thanks for rating your driver.', data: reviewDoc });
    } catch (error) {
        if (error.status) {
            return res.status(error.status).json({ success: false, message: error.message });
        }
        return next(error);
    }
};

exports.createMechanicReview = async (req, res, next) => {
    const ratingValue = normalizeRating(req.body.rating);
    if (!ratingValue) {
        return res.status(400).json({ success: false, message: 'Rating must be between 1 and 5 stars.' });
    }

    try {
        let reviewDoc;
        await runWithOptionalTransaction(async (session) => {
            let rq = MechanicServiceRequest.findOne({ _id: req.params.id, userId: req.user.id });
            if (session) rq = rq.session(session);
            const request = await rq;

            if (!request) {
                throw buildHttpError(404, 'Mechanic request not found.');
            }

            if (request.status !== 'completed') {
                throw buildHttpError(400, 'Service must be completed before leaving a review.');
            }

            if (request.reviewId) {
                throw buildHttpError(409, 'Review already submitted for this service.');
            }

            if (!request.mechanicId) {
                throw buildHttpError(400, 'Mechanic information missing for this service.');
            }

            const [review] = await Review.create([
                buildReviewPayload({
                    serviceType: 'mechanic',
                    request,
                    reviewerId: req.user.id,
                    revieweeId: request.mechanicId,
                    revieweeModel: 'Mechanic',
                    rating: ratingValue,
                    comment: req.body.comment,
                    metadata: {
                        serviceCategory: request.serviceType
                    }
                })
            ], session ? { session } : undefined);

            request.reviewId = review._id;
            await request.save(session ? { session } : undefined);

            await updateAggregateRating({ model: Mechanic, id: request.mechanicId, rating: ratingValue, session });

            reviewDoc = review;

            await logActivity({
                action: 'CREATE_MECHANIC_REVIEW',
                description: `User ${req.user.id} reviewed mechanic ${request.mechanicId}`,
                performedBy: req.user.id,
                userType: 'User',
                entityId: review._id,
                entityType: 'review',
                metadata: { mechanicRequestId: request._id, rating: ratingValue }
            });
        });

        return res.status(201).json({ success: true, message: 'Thanks for rating your mechanic.', data: reviewDoc });
    } catch (error) {
        if (error.status) {
            return res.status(error.status).json({ success: false, message: error.message });
        }
        return next(error);
    }
};

exports.createDriverReviewForUser = async (req, res, next) => {
    const ratingValue = normalizeRating(req.body.rating);
    if (!ratingValue) {
        return res.status(400).json({ success: false, message: 'Rating must be between 1 and 5 stars.' });
    }

    try {
        let reviewDoc;
        await runWithOptionalTransaction(async (session) => {
            const driverId = req.driver?._id || req.user?.driverId || req.user?.id;
            if (!driverId) {
                throw buildHttpError(401, 'Driver authentication required.');
            }

            let rq = ServiceRequest.findOne({ _id: req.params.id, driverId: driverId });
            if (session) rq = rq.session(session);
            const request = await rq;

            if (!request) {
                throw buildHttpError(404, 'Ride not found or not assigned to you.');
            }

            if (request.status !== 'completed') {
                throw buildHttpError(400, 'Complete the ride before reviewing the passenger.');
            }

            if (request.providerReviewId) {
                throw buildHttpError(409, 'You already submitted feedback for this ride.');
            }

            if (!request.userId) {
                throw buildHttpError(400, 'Passenger information missing for this ride.');
            }

            const [review] = await Review.create([
                buildReviewPayload({
                    serviceType: 'towing',
                    request,
                    reviewerId: driverId,
                    reviewerModel: 'Driver',
                    revieweeId: request.userId,
                    revieweeModel: 'Customer',
                    rating: ratingValue,
                    comment: req.body.comment,
                    metadata: {
                        vehicleType: request.vehicleType,
                        role: 'driver'
                    }
                })
            ], session ? { session } : undefined);

            request.providerReviewId = review._id;
            await request.save(session ? { session } : undefined);

            await updateAggregateRating({ model: Customer, id: request.userId, rating: ratingValue, session });

            reviewDoc = review;

            await logActivity({
                action: 'DRIVER_REVIEW_CUSTOMER',
                description: `Driver ${driverId} reviewed customer ${request.userId}`,
                performedBy: driverId,
                userType: 'Driver',
                entityId: review._id,
                entityType: 'review',
                metadata: { serviceRequestId: request._id, rating: ratingValue }
            });
        });

        return res.status(201).json({ success: true, message: 'Thanks for sharing feedback about the passenger.', data: reviewDoc });
    } catch (error) {
        if (error.status) {
            return res.status(error.status).json({ success: false, message: error.message });
        }
        return next(error);
    }
};

exports.createMechanicReviewForUser = async (req, res, next) => {
    const ratingValue = normalizeRating(req.body.rating);
    if (!ratingValue) {
        return res.status(400).json({ success: false, message: 'Rating must be between 1 and 5 stars.' });
    }

    try {
        let reviewDoc;
        await runWithOptionalTransaction(async (session) => {
            const mechanicId = req.mechanic?._id || req.tokenPayload?.id;
            if (!mechanicId) {
                throw buildHttpError(401, 'Mechanic authentication required.');
            }

            let rq = MechanicServiceRequest.findOne({ _id: req.params.id, mechanicId: mechanicId });
            if (session) rq = rq.session(session);
            const request = await rq;

            if (!request) {
                throw buildHttpError(404, 'Service request not found or not assigned to you.');
            }

            if (request.status !== 'completed') {
                throw buildHttpError(400, 'Complete the service before reviewing the customer.');
            }

            if (request.providerReviewId) {
                throw buildHttpError(409, 'You already shared feedback for this service.');
            }

            if (!request.userId) {
                throw buildHttpError(400, 'Customer information missing for this service.');
            }

            const [review] = await Review.create([
                buildReviewPayload({
                    serviceType: 'mechanic',
                    request,
                    reviewerId: mechanicId,
                    reviewerModel: 'Mechanic',
                    revieweeId: request.userId,
                    revieweeModel: 'Customer',
                    rating: ratingValue,
                    comment: req.body.comment,
                    metadata: {
                        serviceCategory: request.serviceType,
                        role: 'mechanic'
                    }
                })
            ], session ? { session } : undefined);

            request.providerReviewId = review._id;
            await request.save(session ? { session } : undefined);

            await updateAggregateRating({ model: Customer, id: request.userId, rating: ratingValue, session });

            reviewDoc = review;

            await logActivity({
                action: 'MECHANIC_REVIEW_CUSTOMER',
                description: `Mechanic ${mechanicId} reviewed customer ${request.userId}`,
                performedBy: mechanicId,
                userType: 'Mechanic',
                entityId: review._id,
                entityType: 'review',
                metadata: { mechanicRequestId: request._id, rating: ratingValue }
            });
        });

        return res.status(201).json({ success: true, message: 'Thanks for sharing feedback about the customer.', data: reviewDoc });
    } catch (error) {
        if (error.status) {
            return res.status(error.status).json({ success: false, message: error.message });
        }
        return next(error);
    }
};
