const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const prisma = require('../config/prisma');
const config = require('../config');

exports.register = async (req, res, next) => {
  const { email, password, companyName } = req.body;

  try {
    // Check if user already exists
    const existingUser = await prisma.user.findUnique({
      where: { email }
    });

    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: 'A user with this email already exists.'
      });
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    // Atomically create Company, Wallet and Admin User
    const result = await prisma.$transaction(async (tx) => {
      const company = await tx.company.create({
        data: {
          name: companyName,
        }
      });

      // Initialize credits wallet with 0.0000 EUR
      await tx.wallet.create({
        data: {
          companyId: company.id,
          balance: 0.0000,
          currency: 'EUR'
        }
      });

      const user = await tx.user.create({
        data: {
          email,
          passwordHash: hashedPassword,
          role: 'admin', // First user is Admin
          companyId: company.id
        }
      });

      return { company, user };
    });

    res.status(201).json({
      success: true,
      message: 'Account successfully registered.',
      data: {
        userId: result.user.id,
        email: result.user.email,
        company: {
          id: result.company.id,
          name: result.company.name
        }
      }
    });

  } catch (err) {
    next(err);
  }
};

exports.login = async (req, res, next) => {
  const { email, password } = req.body;

  try {
    const user = await prisma.user.findUnique({
      where: { email },
      include: { company: true }
    });

    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Invalid email or password.'
      });
    }

    const isMatch = await bcrypt.compare(password, user.passwordHash);
    if (!isMatch) {
      return res.status(401).json({
        success: false,
        message: 'Invalid email or password.'
      });
    }

    // Sign JWT
    const token = jwt.sign(
      {
        id: user.id,
        companyId: user.companyId,
        role: user.role
      },
      config.jwt.secret,
      { expiresIn: config.jwt.expiresIn }
    );

    res.status(200).json({
      success: true,
      message: 'Login successful.',
      data: {
        token,
        user: {
          id: user.id,
          email: user.email,
          role: user.role
        },
        company: {
          id: user.company.id,
          name: user.company.name
        }
      }
    });

  } catch (err) {
    next(err);
  }
};
