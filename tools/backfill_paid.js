// Marks a single user (or all users) as paid in Firestore.
// Usage:
//   node tools/backfill_paid.js <firebaseUid>
//   node tools/backfill_paid.js            (no uid = all users)
// Requires tools/serviceAccountKey.json (git-ignored).
const admin = require('firebase-admin');

const keyPath =
  process.env.GOOGLE_APPLICATION_CREDENTIALS ||
  require('path').join(__dirname, 'serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(keyPath),
});

const db = admin.firestore();

async function main() {
  const uid = process.argv[2];

  if (uid) {
    const ref = db.collection('users').doc(uid);
    const doc = await ref.get();
    if (!doc.exists) {
      console.log(`User doc ${uid} not found.`);
      return;
    }
    await ref.set({ paid: true }, { merge: true });
    console.log(`Marked user ${uid} as paid.`);
    return;
  }

  const snapshot = await db.collection('users').get();
  if (snapshot.empty) {
    console.log('No users found.');
    return;
  }
  const batch = db.batch();
  let count = 0;
  snapshot.docs.forEach((doc) => {
    batch.set(doc.ref, { paid: true }, { merge: true });
    count++;
  });
  await batch.commit();
  console.log(`Marked ${count} existing user(s) as paid.`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
