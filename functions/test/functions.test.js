const { test, before, after, describe } = require('node:test');
const assert = require('node:assert/strict');

const admin = require('firebase-admin');

const TEST_PROJECT = 'kabete-94936';
let testInstance;
let funcs;

function loadFunctions() {
  // Requiring index.js initializes the admin app. With FIRESTORE_EMULATOR_HOST
  // set by the emulators:exec wrapper, the admin SDK points at the local emulator.
  return require('../index');
}

function makeTestInstance() {
  const firebaseFunctionsTest = require('firebase-functions-test');
  return firebaseFunctionsTest({
    projectId: TEST_PROJECT,
  }, null);
}

function asUser(uid, role = 'Student') {
  return {
    auth: {
      uid,
      token: { sub: uid },
    },
  };
}

async function seedUser(db, uid, role = 'Student') {
  await db.collection('users').doc(uid).set({
    uid,
    name: role,
    email: `${uid}@kabetepoly.ac.ke`,
    role,
  });
}

async function seedElection(db, electionId, { status = 'active', startMillis = Date.now() - 60_000, endMillis = Date.now() + 3600_000, resultsPublic = false } = {}) {
  await db.collection('elections').doc(electionId).set({
    title: 'Test Election',
    status,
    startDate: new admin.firestore.Timestamp(Math.floor(startMillis / 1000), 0),
    endDate: new admin.firestore.Timestamp(Math.floor(endMillis / 1000), 0),
    resultsPublic,
  });
}

async function seedPosition(db, electionId, positionId) {
  await db.collection('elections').doc(electionId).collection('positions').doc(positionId).set({
    title: 'President',
    maxWinners: 1,
  });
}

async function seedCandidate(db, electionId, positionId, candidateId, name = 'Ada') {
  await db.collection('elections').doc(electionId).collection('positions').doc(positionId).collection('candidates').doc(candidateId).set({
    name,
    candidateNumber: 1,
    voteCount: 0,
  });
}

describe('Cloud Functions (against Firestore emulator)', () => {
  before(async () => {
    testInstance = makeTestInstance();
    funcs = loadFunctions();
    await seedUser(admin.firestore(), 'admin-fn', 'Official');
  });

  after(async () => {
    testInstance.cleanup();
  });

  test('castVote rejects unauthenticated', async () => {
    await assert.rejects(
      testInstance.wrap(funcs.castVote)({}, { auth: null }),
      (err) => err.code === 'unauthenticated'
    );
  });

  test('castVote rejects when election does not exist', async () => {
    await assert.rejects(
      testInstance.wrap(funcs.castVote)(
        { electionId: 'nope', positionId: 'p', candidateId: 'c' },
        asUser('student-x')
      ),
      (err) => err.code === 'not-found'
    );
  });

  test('castVote stores an anonymized ballot and increments the candidate', async () => {
    const db = admin.firestore();
    await seedElection(db, 'e1');
    await seedPosition(db, 'e1', 'pos1');
    await seedCandidate(db, 'e1', 'pos1', 'cand1');
    await seedUser(db, 'student-1');

    const result = await testInstance.wrap(funcs.castVote)(
      { electionId: 'e1', positionId: 'pos1', candidateId: 'cand1' },
      asUser('student-1')
    );
    assert.equal(result.ok, true);

    const ballots = await db.collection('elections').doc('e1').collection('ballots').get();
    assert.equal(ballots.docs.length, 1);
    const ballot = ballots.docs[0].data();
    // Anonymous: no studentId stored.
    assert.equal(ballot.studentId, undefined);
    assert.equal(ballot.positionId, 'pos1');
    assert.equal(ballot.candidateId, 'cand1');
    // Ballot id is a deterministic sha256 hash of student:election:position:salt.
    assert.match(ballots.docs[0].id, /^[0-9a-f]{64}$/);

    const cand = await db.collection('elections').doc('e1')
      .collection('positions').doc('pos1')
      .collection('candidates').doc('cand1').get();
    assert.equal(cand.data().voteCount, 1);
  });

  test('hasVoted returns true after casting, false before', async () => {
    const db = admin.firestore();
    await seedElection(db, 'e2');
    await seedPosition(db, 'e2', 'pos1');
    await seedCandidate(db, 'e2', 'pos1', 'cand1');
    await seedUser(db, 'student-2');

    const before = await testInstance.wrap(funcs.hasVoted)(
      { electionId: 'e2', positionId: 'pos1' },
      asUser('student-2')
    );
    assert.equal(before.hasVoted, false);

    await testInstance.wrap(funcs.castVote)(
      { electionId: 'e2', positionId: 'pos1', candidateId: 'cand1' },
      asUser('student-2')
    );

    const after = await testInstance.wrap(funcs.hasVoted)(
      { electionId: 'e2', positionId: 'pos1' },
      asUser('student-2')
    );
    assert.equal(after.hasVoted, true);
  });

  test('castVote double-cast returns a clear already-voted error AND does not double-count', async () => {
    const db = admin.firestore();
    await seedElection(db, 'e3');
    await seedPosition(db, 'e3', 'pos1');
    await seedCandidate(db, 'e3', 'pos1', 'cand1');
    await seedUser(db, 'student-3');

    await testInstance.wrap(funcs.castVote)(
      { electionId: 'e3', positionId: 'pos1', candidateId: 'cand1' },
      asUser('student-3')
    );

    await assert.rejects(
      testInstance.wrap(funcs.castVote)(
        { electionId: 'e3', positionId: 'pos1', candidateId: 'cand1' },
        asUser('student-3')
      ),
      (err) => err.code === 'already-exists'
    );

    const cand = await db.collection('elections').doc('e3')
      .collection('positions').doc('pos1')
      .collection('candidates').doc('cand1').get();
    assert.equal(cand.data().voteCount, 1);
  });

  test('castVote rejects when election is closed', async () => {
    const db = admin.firestore();
    await seedElection(db, 'e4', { status: 'closed' });
    await seedPosition(db, 'e4', 'pos1');
    await seedCandidate(db, 'e4', 'pos1', 'cand1');
    await seedUser(db, 'student-4');

    await assert.rejects(
      testInstance.wrap(funcs.castVote)(
        { electionId: 'e4', positionId: 'pos1', candidateId: 'cand1' },
        asUser('student-4')
      ),
      (err) => err.code === 'failed-precondition'
    );
  });

  test('confirmPayment rejects unauthenticated and non-admin', async () => {
    await assert.rejects(
      testInstance.wrap(funcs.confirmPayment)(
        { paymentId: 'p1', transactionRef: 'R', amount: 500 },
        { auth: null }
      ),
      (err) => err.code === 'unauthenticated'
    );

    await seedUser(admin.firestore(), 'student-nonadmin');
    await assert.rejects(
      testInstance.wrap(funcs.confirmPayment)(
        { paymentId: 'p1', transactionRef: 'R', amount: 500 },
        asUser('student-nonadmin')
      ),
      (err) => err.code === 'permission-denied'
    );
  });

  test('confirmPayment rejects missing/invalid args', async () => {
    await assert.rejects(
      testInstance.wrap(funcs.confirmPayment)(
        { transactionRef: 'R', amount: 500 },
        asUser('admin-fn', 'Official')
      ),
      (err) => err.code === 'invalid-argument'
    );
  });

  test('confirmPayment rejects mismatched amount and already-finalized', async () => {
    const db = admin.firestore();
    await db.collection('payments').doc('pay-amt').set({
      studentId: 'student-5',
      status: 'pending',
      amount: 650,
    });
    await seedUser(db, 'student-5');

    await assert.rejects(
      testInstance.wrap(funcs.confirmPayment)(
        { paymentId: 'pay-amt', transactionRef: 'R', amount: 100 },
        asUser('admin-fn', 'Official')
      ),
      (err) => err.code === 'invalid-argument'
    );

    await db.collection('payments').doc('pay-done').set({
      studentId: 'student-5',
      status: 'completed',
      amount: 650,
    });
    await assert.rejects(
      testInstance.wrap(funcs.confirmPayment)(
        { paymentId: 'pay-done', transactionRef: 'R', amount: 650 },
        asUser('admin-fn', 'Official')
      ),
      (err) => err.code === 'failed-precondition'
    );
  });

  test('confirmPayment flips payment to completed and booking to paid', async () => {
    const db = admin.firestore();
    await db.collection('payments').doc('pay-ok').set({
      studentId: 'student-6',
      status: 'pending',
      amount: 650,
      bookingId: 'booking-1',
    });
    await db.collection('cube_bookings').doc('booking-1').set({
      studentId: 'student-6',
      paymentStatus: 'pending',
    });
    await seedUser(db, 'student-6');

    const result = await testInstance.wrap(funcs.confirmPayment)(
      { paymentId: 'pay-ok', transactionRef: 'REF-123', amount: 650 },
      asUser('admin-fn', 'Official')
    );
    assert.equal(result.success, true);

    const pay = await db.collection('payments').doc('pay-ok').get();
    assert.equal(pay.data().status, 'completed');
    assert.equal(pay.data().transactionRef, 'REF-123');
    assert.ok(pay.data().completedAt);

    const booking = await db.collection('cube_bookings').doc('booking-1').get();
    assert.equal(booking.data().paymentStatus, 'paid');
  });
});