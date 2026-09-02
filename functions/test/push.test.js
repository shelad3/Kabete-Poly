const { test, before, after, describe } = require('node:test');
const assert = require('node:assert/strict');

const admin = require('firebase-admin');

const TEST_PROJECT = 'kabete-94936';
let testInstance;
let funcs;

function loadFunctions() {
  return require('../index');
}

function makeTestInstance() {
  const firebaseFunctionsTest = require('firebase-functions-test');
  return firebaseFunctionsTest({ projectId: TEST_PROJECT }, null);
}

function asUser(uid, role = 'Student') {
  return { auth: { uid, token: { sub: uid } } };
}

async function seedUser(db, uid, role = 'Student', { tokens = [], enrolledClasses = [] } = {}) {
  await db.collection('users').doc(uid).set({
    uid,
    name: role,
    email: `${uid}@kabetepoly.ac.ke`,
    role,
    fcmTokens: tokens,
    enrolledClasses,
  });
}

describe('Push notification Cloud Functions (against Firestore emulator)', () => {
  before(async () => {
    testInstance = makeTestInstance();
    funcs = loadFunctions();
    await seedUser(admin.firestore(), 'admin-push', 'Official');
    await seedUser(admin.firestore(), 'teacher-push', 'Teacher');
    await seedUser(admin.firestore(), 'student-push', 'Student');
  });

  after(async () => {
    testInstance.cleanup();
  });

  // `admin.messaging` is a non-writable getter, so stub the method on the
  // returned (cached) Messaging instance instead. Real FCM cannot run inside
  // the emulator, so we only assert the message we would have sent.
  function stubMessaging() {
    let captured;
    const instance = admin.messaging();
    const original = instance.sendEachForMulticast;
    instance.sendEachForMulticast = async (msg) => {
      captured = msg;
      return { successCount: msg.tokens.length, failureCount: 0 };
    };
    return {
      getCaptured: () => captured,
      restore: () => { instance.sendEachForMulticast = original; },
    };
  }

  test('sendNotification rejects unauthenticated and students', async () => {
    await assert.rejects(
      testInstance.wrap(funcs.sendNotification)(
        { userId: 'x', title: 'Hi', body: 'Yo' },
        { auth: null }
      ),
      (err) => err.code === 'unauthenticated'
    );

    await assert.rejects(
      testInstance.wrap(funcs.sendNotification)(
        { userId: 'x', title: 'Hi', body: 'Yo' },
        asUser('student-push', 'Student')
      ),
      (err) => err.code === 'permission-denied'
    );
  });

  test('sendNotification allows teachers and officials', async () => {
    const response = await testInstance.wrap(funcs.sendNotification)(
      { userId: 'student-push', title: 'Hi', body: 'Yo' },
      asUser('teacher-push', 'Teacher')
    );
    assert.deepEqual(response, { success: true, sent: 0 }); // no tokens -> 0 sent
  });

  test('sendNotification builds a multicast with the target tokens', async () => {
    await seedUser(admin.firestore(), 'student-tokens', 'Student', {
      tokens: ['tok-1', 'tok-2'],
    });

    const stub = stubMessaging();

    const response = await testInstance.wrap(funcs.sendNotification)(
      { userId: 'student-tokens', title: 'T', body: 'B', data: { kind: 'alert' } },
      asUser('teacher-push', 'Teacher')
    );

    assert.deepEqual(response, { success: true, sent: 2, failed: 0 });
    const captured = stub.getCaptured();
    assert.equal(captured.notification.title, 'T');
    assert.equal(captured.notification.body, 'B');
    assert.deepEqual(captured.data, { kind: 'alert' });
    assert.deepEqual(captured.tokens, ['tok-1', 'tok-2']);
    stub.restore();
  });

  test('sendClassNotification fans out to enrolled-class tokens', async () => {
    await seedUser(admin.firestore(), 'student-a', 'Student', {
      tokens: ['tok-a1', 'tok-a2'],
      enrolledClasses: ['CS1A'],
    });
    await seedUser(admin.firestore(), 'student-b', 'Student', {
      tokens: ['tok-b1'],
      enrolledClasses: ['CS1A'],
    });
    await seedUser(admin.firestore(), 'student-other', 'Student', {
      tokens: ['tok-other'],
      enrolledClasses: ['CS1B'],
    });

    const stub = stubMessaging();

    const snap = testInstance.firestore.makeDocumentSnapshot(
      { classId: 'CS1A', title: 'Assembly', body: 'Today 2pm', type: 'announcement', message: null },
      'notifications/notif-1'
    );
    await testInstance.wrap(funcs.sendClassNotification)(snap);

    const captured = stub.getCaptured();
    assert.equal(captured.notification.title, 'Assembly');
    assert.equal(captured.notification.body, 'Today 2pm');
    assert.equal(captured.data.type, 'announcement');
    assert.equal(captured.data.classId, 'CS1A');
    assert.equal(captured.data.notificationId, 'notif-1');
    assert.deepEqual([...captured.tokens].sort(), ['tok-a1', 'tok-a2', 'tok-b1']);
    stub.restore();
  });

  test('sendClassNotification tolerates the legacy `message` field and single student', async () => {
    await seedUser(admin.firestore(), 'student-c', 'Student', {
      tokens: ['tok-c'],
      enrolledClasses: ['CS1A'],
    });

    const stub = stubMessaging();

    const snap = testInstance.firestore.makeDocumentSnapshot(
      { classId: 'CS1A', title: 'Alert', message: 'Legacy body', studentId: 'student-c' },
      'notifications/notif-2'
    );
    await testInstance.wrap(funcs.sendClassNotification)(snap);

    const captured = stub.getCaptured();
    assert.equal(captured.notification.body, 'Legacy body');
    assert.deepEqual(captured.tokens, ['tok-c']);
    stub.restore();
  });

  test('sendClassNotification no-ops when required fields are missing', async () => {
    const snap = testInstance.firestore.makeDocumentSnapshot(
      { title: 'No class' },
      'notifications/notif-3'
    );
    await testInstance.wrap(funcs.sendClassNotification)(snap); // should not throw
  });
});