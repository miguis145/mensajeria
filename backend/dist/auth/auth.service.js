import argon2 from 'argon2';
import jwt from 'jsonwebtoken';
import { env } from '../config/env.js';
export async function hashPassword(plainPassword) {
    return argon2.hash(plainPassword, {
        type: argon2.argon2id,
    });
}
export async function verifyPassword(plainPassword, storedHash) {
    return argon2.verify(storedHash, plainPassword);
}
export function generateToken(payload) {
    return jwt.sign(payload, env.jwtSecret, {
        expiresIn: env.jwtExpiresIn,
    });
}
export function verifyToken(token) {
    return jwt.verify(token, env.jwtSecret);
}
//# sourceMappingURL=auth.service.js.map