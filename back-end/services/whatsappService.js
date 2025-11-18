const twilio = require('twilio');
const { Client, LocalAuth } = require('whatsapp-web.js');
const qrcode = require('qrcode-terminal');
const logger = require('../utils/logger');

const PROVIDERS = {
    TWILIO: 'twilio',
    WEBJS: 'webjs'
};

let twilioClient;
let webClient;
let webClientReady;

const getProvider = () => {
    const provider = (process.env.WHATSAPP_PROVIDER || PROVIDERS.TWILIO).toLowerCase();
    return Object.values(PROVIDERS).includes(provider) ? provider : PROVIDERS.TWILIO;
};

const ensureTwilioEnv = () => {
    const {
        TWILIO_ACCOUNT_SID,
        TWILIO_AUTH_TOKEN,
        TWILIO_PHONE_NUMBER
    } = process.env;

    if (!TWILIO_ACCOUNT_SID || !TWILIO_AUTH_TOKEN || !TWILIO_PHONE_NUMBER) {
        throw new Error('Missing Twilio WhatsApp credentials (TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_PHONE_NUMBER).');
    }

    return { TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_PHONE_NUMBER };
};

const getTwilioClient = () => {
    if (!twilioClient) {
        const { TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN } = ensureTwilioEnv();
        twilioClient = twilio(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN);
    }
    return twilioClient;
};

const initializeWebClient = () => {
    if (webClient && webClientReady) {
        return webClientReady;
    }

    webClient = new Client({
        authStrategy: new LocalAuth()
    });

    webClient.on('qr', qr => {
        logger.info('Scan the QR code below to authenticate the WhatsApp Web client.');
        qrcode.generate(qr, { small: true });
    });

    webClientReady = new Promise((resolve, reject) => {
        webClient.once('ready', () => {
            logger.info('WhatsApp Web client connected.');
            resolve();
        });
        webClient.once('auth_failure', (msg) => {
            logger.error('WhatsApp Web auth failure', msg);
            reject(new Error(`WhatsApp Web auth failure: ${msg}`));
        });
        webClient.once('disconnected', () => {
            logger.warn('WhatsApp Web client disconnected, resetting session.');
            webClient = null;
            webClientReady = null;
        });
    });

    webClient.initialize();
    return webClientReady;
};

const normalizeRecipient = (rawNumber = '') => {
    const cleaned = rawNumber.replace(/[^\d+]/g, '');
    if (!cleaned) {
        throw new Error('A recipient phone number is required.');
    }
    return cleaned.startsWith('+') ? cleaned : `+${cleaned}`;
};

const initializeWhatsAppClient = () => {
    const provider = getProvider();
    logger.info(`Initializing WhatsApp provider: ${provider}`);
    if (provider === PROVIDERS.WEBJS) {
        return initializeWebClient()
            .catch(err => {
                logger.error('Failed to initialize WhatsApp Web client', err);
            });
    }
    twilioClient = null;
    getTwilioClient();
    return Promise.resolve();
};

const previewMessage = (text = '') => {
    if (text.length <= 60) return text;
    return `${text.slice(0, 57)}...`;
};

const sendViaTwilio = async (to, message) => {
    const twClient = getTwilioClient();
    const { TWILIO_PHONE_NUMBER } = ensureTwilioEnv();
    const recipient = normalizeRecipient(to);

    try {
        logger.debug('Sending WhatsApp message via Twilio', {
            to: recipient,
            from: normalizeRecipient(TWILIO_PHONE_NUMBER),
            preview: previewMessage(message)
        });
        return await twClient.messages.create({
            body: message,
            from: `whatsapp:${normalizeRecipient(TWILIO_PHONE_NUMBER)}`,
            to: `whatsapp:${recipient}`
        });
    } catch (error) {
        logger.error('Twilio WhatsApp send failed', error);
        throw error;
    }
};

const sendViaWebClient = async (to, message) => {
    await initializeWebClient();
    if (!webClient) {
        throw new Error('WhatsApp Web client is not ready.');
    }
    const formatted = normalizeRecipient(to).substring(1); // remove leading +
    const chatId = `${formatted}@c.us`;
    try {
        logger.debug('Sending WhatsApp message via whatsapp-web.js', {
            to: formatted,
            preview: previewMessage(message)
        });
        return await webClient.sendMessage(chatId, message);
    } catch (error) {
        logger.error('WhatsApp Web send failed', error);
        throw error;
    }
};

const sendMessage = async (to, message) => {
    if (!message) {
        throw new Error('Message body is required.');
    }

    const provider = getProvider();
    if (provider === PROVIDERS.WEBJS) {
        return sendViaWebClient(to, message);
    }
    return sendViaTwilio(to, message);
};

module.exports = {
    initializeWhatsAppClient,
    sendMessage
};
