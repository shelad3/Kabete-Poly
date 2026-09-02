import { test, describe, before, after } from 'node:test';
import { initializeTestEnvironment, assertSucceeds, assertFails } from '@firebase/rules-unit-testing';
import fs from 'node:fs';
import path from 'node:path';

const PROJECT_ID = 'kabete-94936';

let testEnv;

async function loadRules() {
  const rulesPath = path.resolve(
    path.dirname(new URL(import.meta.url).pathname),
    '../../firestore.rules'
  );
  return fs.readFileSync(rulesPath, 'utf8');
}

before(async () => {
  const rules = await loadRules();
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules },
  });
});

after(async () => {
  if (testEnv) {
    await testEnv.cleanup();
  }
});

async function seedUser(uid, role) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().collection('users').doc(uid).set({
      uid,
      name: role,
      email: `${uid}@kabetepoly.ac.ke`,
      role,
    });
  });
}

async function seedDoc(collection, docId, data) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().collection(collection).doc(docId).set(data);
  });
}

describe('Kabete Poly Firestore rules', () => {
  test('student cannot self-promote to Teacher/Official/Admin', async () => {
    const student = testEnv.authenticatedContext('student-1');
    const db = student.firestore();

    await seedUser('student-1', 'Student');

    await assertSucceeds(
      db.collection('users').doc('student-1').update({ name: 'New Name' })
    );
    await assertFails(
      db.collection('users').doc('student-1').update({ role: 'Teacher' })
    );
    await assertSucceeds(
      db.collection('users').doc('student-1').update({ bio: 'hello' })
    );
  });

  test('student cannot read auth_codes', async () => {
    const student = testEnv.authenticatedContext('student-2');
    const db = student.firestore();

    await seedUser('student-2', 'Student');
    await seedDoc('auth_codes', 'code-1', {
      code: 'SECRET',
      studentId: 'student-2',
    });

    await assertFails(db.collection('auth_codes').doc('code-1').get());
  });

  test('admin can read auth_codes', async () => {
    const official = testEnv.authenticatedContext('admin-3');
    const db = official.firestore();
    await seedUser('admin-3', 'Official');
    await seedDoc('auth_codes', 'code-2', {
      code: 'SECRET',
      studentId: 'student-2',
    });
    await assertSucceeds(db.collection('auth_codes').doc('code-2').get());
  });

  test('student cannot impersonate another sender in messages', async () => {
    const student = testEnv.authenticatedContext('student-3');
    const db = student.firestore();
    await seedUser('student-3', 'Student');

    await assertFails(
      db.collection('messages').doc('msg-1').set({
        senderId: 'other-student',
        text: 'Impersonation attempt',
      })
    );
    await assertSucceeds(
      db.collection('messages').doc('msg-2').set({
        senderId: 'student-3',
        text: 'Legit message',
      })
    );
  });

  test('field_indices write is locked to owner', async () => {
    const attacker = testEnv.authenticatedContext('student-4');
    const db = attacker.firestore();
    await seedUser('student-4', 'Student');

    await assertSucceeds(
      db.collection('field_indices').doc('idx-owner').set({
        uid: 'student-4',
        registered: false,
      })
    );

    await assertFails(
      db.collection('field_indices').doc('idx-other').set({
        uid: 'someone-else',
        registered: false,
      })
    );

    await assertFails(
      db.collection('field_indices').doc('idx-owner').update({
        registered: true,
        uid: 'someone-else',
      })
    );
  });

  test('payment confirm is admin-only (student can only create pending)', async () => {
    const student = testEnv.authenticatedContext('student-5');
    const sdb = student.firestore();
    await seedUser('student-5', 'Student');

    const paymentRef = sdb.collection('payments').doc('pay-1');
    await assertSucceeds(
      paymentRef.set({
        studentId: 'student-5',
        status: 'pending',
        amount: 500,
      })
    );

    await assertFails(
      paymentRef.update({ status: 'completed', transactionRef: 'FAKE-REF' })
    );
  });

  test('admin can confirm payment', async () => {
    const official = testEnv.authenticatedContext('admin-6');
    const db = official.firestore();
    await seedUser('admin-6', 'Official');

    await seedDoc('payments', 'pay-2', {
      studentId: 'student-5',
      status: 'pending',
      amount: 500,
    });

    await assertSucceeds(
      db.collection('payments').doc('pay-2').update({
        status: 'completed',
        transactionRef: 'REAL-REF',
        completedAt: 'now',
      })
    );
  });

  test('student cannot read other students grades', async () => {
    const student = testEnv.authenticatedContext('student-6');
    const db = student.firestore();
    await seedUser('student-6', 'Student');

    await seedDoc('grades', 'grade-other', {
      studentId: 'other-student',
      subject: 'Math',
      score: 90,
    });
    await assertFails(db.collection('grades').doc('grade-other').get());
  });

  test('student can read own grades', async () => {
    const student = testEnv.authenticatedContext('student-7');
    const db = student.firestore();
    await seedUser('student-7', 'Student');

    await seedDoc('grades', 'grade-own', {
      studentId: 'student-7',
      subject: 'Math',
      score: 90,
    });
    await assertSucceeds(db.collection('grades').doc('grade-own').get());
  });

  test('students cannot write lessons (teacher-only)', async () => {
    const student = testEnv.authenticatedContext('student-8');
    const db = student.firestore();
    await seedUser('student-8', 'Student');

    await assertFails(
      db.collection('lessons').doc('lesson-1').set({
        title: 'Math 101',
        studentId: 'student-8',
      })
    );
  });

  test('unauthenticated cannot read users directory', async () => {
    const anon = testEnv.unauthenticatedContext();
    const db = anon.firestore();
    await assertFails(db.collection('users').doc('student-1').get());
  });
});