const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

/**
 * Send a push notification to a specific user by their userId.
 * Trigger this from the app via an HTTPS callable function.
 */
exports.sendNotification = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'You must be logged in.');
  }

  const { userId, title, body, data: payloadData } = data;
  if (!userId || !title || !body) {
    throw new functions.https.HttpsError('invalid-argument', 'userId, title, and body are required.');
  }

  const userDoc = await admin.firestore().collection('users').doc(userId).get();
  const tokens = userDoc.data()?.fcmTokens ?? [];

  if (tokens.length === 0) return { success: true, sent: 0 };

  const message = {
    notification: { title, body },
    data: payloadData ?? {},
    tokens,
  };

  const response = await admin.messaging().sendEachForMulticast(message);
  return { success: true, sent: response.successCount, failed: response.failureCount };
});

/**
 * Send a notification to an entire class.
 * Triggered when a new lesson, quiz, or announcement is created.
 */
exports.sendClassNotification = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const { classId, title, body, type } = snap.data();

    if (!classId || !title || !body) return;

    const usersSnapshot = await admin.firestore()
      .collection('users')
      .where('enrolledClasses', 'array-contains', classId)
      .get();

    const tokens = [];
    usersSnapshot.forEach((doc) => {
      const userTokens = doc.data().fcmTokens ?? [];
      tokens.push(...userTokens);
    });

    if (tokens.length === 0) return;

    const message = {
      notification: { title, body },
      data: { type: type ?? 'general', classId },
      tokens,
    };

    await admin.messaging().sendEachForMulticast(message);
  });
