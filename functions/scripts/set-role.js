#!/usr/bin/env node
// Assigns or revokes a role via Firebase Auth custom claims and mirrors it to
// users/{uid}.role (read-only for clients). Run locally by a project owner:
//
//   GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json \
//     node functions/scripts/set-role.js <email> <admin|minister|user>
//
// Against the emulators:
//   FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 \
//     GCLOUD_PROJECT=demo-devotion node functions/scripts/set-role.js <email> admin
//
// Never commit service-account keys. The user must sign out/in, or use
// Profile → "Refresh account permissions", for the new claim to apply.
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

const ROLES = new Set(['admin', 'minister', 'user']);

async function main() {
  const [email, role] = process.argv.slice(2);
  if (!email || !ROLES.has(role)) {
    console.error('Usage: set-role.js <email> <admin|minister|user>');
    process.exit(64);
  }
  initializeApp(process.env.GCLOUD_PROJECT ? { projectId: process.env.GCLOUD_PROJECT } : undefined);
  const auth = getAuth();
  const user = await auth.getUserByEmail(email);
  const claims = { ...(user.customClaims || {}) };
  if (role === 'user') delete claims.role;
  else claims.role = role;
  await auth.setCustomUserClaims(user.uid, claims);
  await getFirestore().doc(`users/${user.uid}`).set(
    { role: role === 'user' ? FieldValue.delete() : role, updatedAt: FieldValue.serverTimestamp() },
    { merge: true },
  );
  console.log(`Set role "${role}" for ${email} (${user.uid}).`);
}

main().catch((e) => {
  console.error(e.message || e);
  process.exit(1);
});
