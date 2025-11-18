const Joi = require('joi');
const { SERVICES } = require('../models/Mechanic');

function validateMechanicProfile(data, opts = {}) {
    const partial = opts.partial;
    const pkPhoneRegex = /^(?:\+923|03)[0-9]{9}$/;

    const locationSchema = Joi.object({
        type: Joi.string().valid('Point').default('Point'),
        coordinates: Joi.array().items(
            Joi.number().min(-180).max(180),
            Joi.number().min(-90).max(90)
        ).length(2)
    });

    const schema = Joi.object({
        personName: Joi.string().min(2).max(100).required(),
        shopName: Joi.string().min(2).max(100).required(),
        personalPhotoUrl: Joi.string().uri().allow(null, ''),
        cnicPhotoUrl: Joi.string().uri().allow(null, ''),
        workshopPhotoUrl: Joi.string().uri().allow(null, ''),
        introductionVideoUrl: Joi.string().uri().allow(null, ''),
        registrationCertificateUrl: Joi.string().uri().allow(null, ''),
        emergencyContact: Joi.string().pattern(pkPhoneRegex).allow(null, ''),
        phoneNumber: Joi.string().pattern(pkPhoneRegex).required(),
        servicesOffered: Joi.array().items(Joi.string().valid(...SERVICES)).unique().max(10),
        location: locationSchema,
        address: Joi.string().allow(null, ''),
        isActive: Joi.boolean()
    });

    return partial ? schema.min(1).validate(data) : schema.validate(data);
}

module.exports = { validateMechanicProfile };