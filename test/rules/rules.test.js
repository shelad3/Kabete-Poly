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
      db.collection('users').doc('student-1').update({ fullName: 'New Name' })
    );
    await assertFails(
      db.collection('users').doc('student-1').update({ role: 'Teacher' })
    );
    await assertSucceeds(
      db.collection('users').doc('student-1').update({ bio: 'hello' })
    );
  });

  test('student can create own profile with app schema (fullName-based)', async () => {
    const student = testEnv.authenticatedContext('student-9');
    const db = student.firestore();

    await assertSucceeds(
      db.collection('users').doc('student-9').set({
        registrationNumber: 'EE-2026-009',
        fullName: 'New Student',
        email: 'student9@kabetepoly.ac.ke',
        role: 'Student',
        mobileNumber: '+254700000009',
        isHostelResident: false,
        enrolledClasses: [],
      })
    );

    // Cannot create a profile doc under someone else's uid.
    await assertFails(
      db.collection('users').doc('another-user').set({
        fullName: 'Imposter',
        email: 'imposter@kabetepoly.ac.ke',
        role: 'Student',
        registrationNumber: 'EE-2026-999',
        mobileNumber: '+254700000999',
      })
    );
  });

  test('student can append own uid to class members (enrol)', async () => {
    const student = testEnv.authenticatedContext('student-10');
    const db = student.firestore();
    await seedUser('student-10', 'Student');
    await seedDoc('classes', 'class-a', {
      id: 'class-a',
      members: ['teacher-1'],
      createdBy: 'teacher-1',
    });

    await assertSucceeds(
      db.collection('classes').doc('class-a').update({
        members: ['teacher-1', 'student-10'],
      })
    );

    // Cannot remove another member or rewrite membership.
    await assertFails(
      db.collection('classes').doc('class-a').update({
        members: ['student-10'],
      })
    );
    // Cannot change anything but members.
    await assertFails(
      db.collection('classes').doc('class-a').update({
        name: 'Hacked',
      })
    );
  });

  test('student can release own field index but not others', async () => {
    const student = testEnv.authenticatedContext('student-11');
    const db = student.firestore();
    await seedUser('student-11', 'Student');
    await seedDoc('field_indices', 'idx-own', {
      uid: 'student-11',
      type: 'regNo',
      value: 'EE-2026-011',
    });
    await seedDoc('field_indices', 'idx-other', {
      uid: 'student-5',
      type: 'regNo',
      value: 'EE-2026-005',
    });

    await assertSucceeds(db.collection('field_indices').doc('idx-own').delete());
    await assertFails(
      db.collection('field_indices').doc('idx-other').delete()
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

  test('unauthenticated can read classes list (cohort dropdown before login)', async () => {
    const anon = testEnv.unauthenticatedContext();
    const db = anon.firestore();
    await seedDoc('classes', 'class-public', {
      id: 'class-public',
      members: [],
      createdAt: 'now',
    });
    await assertSucceeds(db.collection('classes').doc('class-public').get());

    // ...but the timetable subcollection stays auth-gated.
    await seedDoc('classes/class-public/timetable', 'tt-1', {
      classId: 'class-public',
      day: 'MON',
    });
    await assertFails(
      db.collection('classes').doc('class-public').collection('timetable').doc('tt-1').get()
    );
  });
});