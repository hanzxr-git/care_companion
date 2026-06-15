const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

exports.onSosTriggered = functions.firestore
  .document('users/{userId}')
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    const userId = context.params.userId;

    // Only trigger if sosActive changed from false to true
    if (!beforeData.sosActive && afterData.sosActive) {
      console.log(`SOS Alert triggered by user: ${userId}`);

      try {
        // 1. Find all circles this user belongs to
        const circlesSnapshot = await db.collection('circles')
          .where('memberUids', 'array-contains', userId)
          .get();

        if (circlesSnapshot.empty) {
          console.log(`User ${userId} is not in any circles. No one to notify.`);
          return null;
        }

        // 2. Gather all unique member UIDs to notify (excluding the user who triggered it)
        const uidsToNotify = new Set();
        circlesSnapshot.forEach(doc => {
          const circleData = doc.data();
          const members = circleData.memberUids || [];
          members.forEach(memberId => {
            if (memberId !== userId) {
              uidsToNotify.add(memberId);
            }
          });
        });

        if (uidsToNotify.size === 0) {
          console.log(`No other members found in user ${userId}'s circles.`);
          return null;
        }

        // 3. Fetch the FCM tokens for those users
        const tokens = [];
        const usersRef = db.collection('users');
        
        // We have to batch get or query in chunks, but for a small app we can fetch them individually or use 'in' query.
        // Using 'in' query (limit to 30 uids max per query)
        const uidsArray = Array.from(uidsToNotify);
        // Chunk array into pieces of 30 for the 'in' query constraint
        const chunks = [];
        for (let i = 0; i < uidsArray.length; i += 30) {
          chunks.push(uidsArray.slice(i, i + 30));
        }

        for (const chunk of chunks) {
          const usersSnapshot = await usersRef.where(admin.firestore.FieldPath.documentId(), 'in', chunk).get();
          usersSnapshot.forEach(userDoc => {
            const userData = userDoc.data();
            if (userData.fcmToken) {
              tokens.push(userData.fcmToken);
            }
          });
        }

        if (tokens.length === 0) {
          console.log('No FCM tokens found for any circle members.');
          return null;
        }

        // 4. Send the push notification payload
        const payload = {
          notification: {
            title: 'EMERGENCY: SOS Alert Triggered!',
            body: `${afterData.displayName || 'A circle member'} has activated an SOS alert and needs immediate assistance!`,
          },
          data: {
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
            type: 'sos_alert',
            userId: userId,
          },
          tokens: tokens,
        };

        const response = await admin.messaging().sendEachForMulticast(payload);
        console.log(`Successfully sent ${response.successCount} SOS messages. Failed: ${response.failureCount}`);
        
      } catch (error) {
        console.error('Error sending SOS push notifications:', error);
      }
    }
    return null;
  });
