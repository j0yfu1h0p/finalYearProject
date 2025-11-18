const Joi = require('joi');

// Validate environment variables
const envVarsSchema = Joi.object({
  MONGO_URI: Joi.string().required(),
  JWT_SECRET: Joi.string().required(),
  PORT: Joi.number().default(5000),
  GOOGLE_MAPS_API_KEY: Joi.string().required(),
  TWILIO_ACCOUNT_SID: Joi.string(),
  TWILIO_AUTH_TOKEN: Joi.string(),
  TWILIO_PHONE_NUMBER: Joi.string(),
  WHATSAPP_PROVIDER: Joi.string().valid('twilio', 'webjs').default('twilio')
  ENABLE_DEBUG_LOGS: Joi.string().valid('true', 'false')
}).unknown();

const { error } = envVarsSchema.validate(process.env);

if (error) {
  throw new Error(`Config validation error: ${error.message}`);
}