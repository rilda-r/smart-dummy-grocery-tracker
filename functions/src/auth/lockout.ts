import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import * as crypto from "crypto";

const LOCKOUT_DURATION_MS = 10 * 60 * 1000; // 10 minutes
const MAX_FAILED_ATTEMPTS = 3;

function hashEmail(email: string): string {
  return crypto.createHash("sha256").update(email.trim().toLowerCase()).digest("hex");
}

export const recordFailedLogin = functions.https.onCall(async (data) => {
  const email = data.email;
  if (!email || typeof email !== "string") {
    throw new functions.https.HttpsError("invalid-argument", "Email is required");
  }

  const emailHash = hashEmail(email);
  const db = admin.firestore();
  const authStateRef = db.collection("authState").doc(emailHash);

  const doc = await authStateRef.get();
  const now = Date.now();

  let failedAttempts = 1;
  let lockedUntil: number | null = null;

  if (doc.exists) {
    const data = doc.data()!;
    const currentLockedUntil = data.lockedUntil ? (data.lockedUntil as admin.firestore.Timestamp).toMillis() : null;

    if (currentLockedUntil && currentLockedUntil > now) {
      // Still currently locked out
      const remainingSeconds = Math.ceil((currentLockedUntil - now) / 1000);
      return {
        isLocked: true,
        remainingSeconds,
        remainingAttempts: 0,
        lockedUntil: currentLockedUntil,
      };
    }

    // Previous lock expired or continuing attempts
    const previousAttempts = data.failedAttempts || 0;
    failedAttempts = previousAttempts + 1;

    if (failedAttempts >= MAX_FAILED_ATTEMPTS) {
      lockedUntil = now + LOCKOUT_DURATION_MS;
      failedAttempts = MAX_FAILED_ATTEMPTS;
    }
  }

  await authStateRef.set({
    emailHash,
    failedAttempts,
    lockedUntil: lockedUntil ? admin.firestore.Timestamp.fromMillis(lockedUntil) : null,
    lastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  const isLocked = lockedUntil !== null && lockedUntil > now;
  const remainingSeconds = lockedUntil ? Math.ceil((lockedUntil - now) / 1000) : 0;
  const remainingAttempts = Math.max(0, MAX_FAILED_ATTEMPTS - failedAttempts);

  return {
    isLocked,
    remainingSeconds,
    remainingAttempts,
    lockedUntil,
  };
});

export const checkLockStatus = functions.https.onCall(async (data) => {
  const email = data.email;
  if (!email || typeof email !== "string") {
    throw new functions.https.HttpsError("invalid-argument", "Email is required");
  }

  const emailHash = hashEmail(email);
  const db = admin.firestore();
  const authStateRef = db.collection("authState").doc(emailHash);

  const doc = await authStateRef.get();
  const now = Date.now();

  if (!doc.exists) {
    return {
      isLocked: false,
      remainingSeconds: 0,
      remainingAttempts: MAX_FAILED_ATTEMPTS,
    };
  }

  const docData = doc.data()!;
  const lockedUntil = docData.lockedUntil ? (docData.lockedUntil as admin.firestore.Timestamp).toMillis() : null;
  const failedAttempts = docData.failedAttempts || 0;

  if (lockedUntil && lockedUntil > now) {
    const remainingSeconds = Math.ceil((lockedUntil - now) / 1000);
    return {
      isLocked: true,
      remainingSeconds,
      remainingAttempts: 0,
      lockedUntil,
    };
  }

  // Lock has expired or never locked
  if (lockedUntil && lockedUntil <= now) {
    // Reset state after lock expiration
    await authStateRef.delete();
    return {
      isLocked: false,
      remainingSeconds: 0,
      remainingAttempts: MAX_FAILED_ATTEMPTS,
    };
  }

  return {
    isLocked: false,
    remainingSeconds: 0,
    remainingAttempts: Math.max(0, MAX_FAILED_ATTEMPTS - failedAttempts),
  };
});
