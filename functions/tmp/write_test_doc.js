const admin = require('firebase-admin');

process.env.FIRESTORE_EMULATOR_HOST = 'localhost:8080';

admin.initializeApp({ projectId: 'coodyou-hag' });

const db = admin.firestore();

async function run() {
  const ref = db.collection('dasherAvailability').doc('test-dasher-123');
  await ref.set({ id: 'test-dasher-123', isOnline: true, updatedAt: admin.firestore.FieldValue.serverTimestamp() });
  const doc = await ref.get();
  console.log('Wrote doc:', doc.id, doc.data());
}

run().catch(console.error).finally(() => process.exit());
