const express = require('express');
const router = express.Router();
const authController = require('../controllers/auth.controller');
const { authorize, endSession } = require('../middleware/session');

// POST /api/auth/login
router.post('/login', authController.login);
router.post('/logout', authorize(), endSession);

module.exports = router;
