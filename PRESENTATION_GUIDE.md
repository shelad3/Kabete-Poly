# Tent Presentation Guide

## KNP Management System — Sheldon Ramu

---

> This document is a reference, not a script. Read it through a few times before the event so the points sit in your head. When someone walks up to your tent, you will not be reading from paper — you will be having a conversation with them about something you built.

---

## Part 1: The Frame (Who You Are)

When someone asks "so who built this?", your answer matters more than you think. Do not lead with what you are not. Lead with what you did.

**Good answer:**

> "I built it. I am in my second year of electrical engineering here at Kabete. The app started because I got tired of losing PDFs in WhatsApp groups and showing up to the wrong lab sessions. Four months later it turned into this."

Why this works:
- You claim ownership immediately ("I built it")
- You name your actual situation (second year EE — relatable to students and impressive to faculty because it shows range)
- You anchor the project in a real problem, not in "I wanted to learn Flutter"

**If someone asks about your CS background:**

> "I do not have a formal CS background. I learned Flutter and Firebase as I went. The documentation is excellent, and trial and error teaches you things a degree never will."

This turns a potential weakness into a point about resourcefulness. Do not add "but I am still learning" — that is implied by the context. Stop after the second sentence.

---

## Part 2: The Walkthrough (3 Minutes)

You have someone standing at your table. Phone is in your hand (or theirs). Walk them through exactly one complete scenario. Pick one of the following based on who is standing in front of you.

### If they are a student:

> "Open the app. This is the Explore tab — every lesson posted by your lecturers shows up here, newest first. Tap any lesson. You get the full notes, the summary, any PDF attachments the teacher uploaded. Swipe to the Schedule tab. Your timetable for today. Tap a class and it shows you the room on the map. The Forum tab is where your class can discuss things without the WhatsApp noise. That green badge on the Alerts tab counts unread notifications — the college sends alerts here, they do not get lost in a group chat."

Let them take the phone and scroll. Answer questions as they come.

### If they are a lecturer or faculty member:

> "The problem this solves is that every class currently manages materials differently — some use WhatsApp, some use email, some use printed handouts. This brings everything into one place. You log in, you see only your class. You post a lesson, it shows up in real time for every student enrolled. You schedule a lab session, it goes on their timetable and sends them a push notification. You do not need to chase anyone to confirm they got the material."

Offer to show the posting flow on the phone. Let them tap through it.

### If they are an administrator or visitor (non-technical):

> "This is a mobile platform for the college. Students access their lessons, timetable, and class discussions here. Lecturers post materials. Administration sends alerts. Everything is organized by class cohort so nothing gets mixed up. It is live — what you see on this phone right now is what students use every day."

Show the main screens slowly. Do not go into technical details unless they ask.

### If they are a developer or technically-minded:

> "Flutter front end, Firebase back end. Firestore for the database with real-time listeners so updates appear instantly. Cloudinary handles file uploads. Google Maps for the campus map. The authentication uses Firebase Auth with email-password and Google Sign-In. State management is Provider. The app auto-updates by checking a GitHub release endpoint on startup."

Then ask them what they want to know more about. They will likely have specific questions about the architecture, which you can answer from the documentation we prepared.

---

## Part 3: Anticipated Questions & Answers

These are questions that will come up. Have answers ready so you do not get caught off guard.

### Q: "How is this different from Google Classroom?"

> "Google Classroom is a general platform designed for schools globally. This is built specifically for how Kabete Poly works — our class cohort naming system, our timetable structure, our campus map. It also works fully offline for cached content, integrates push notifications specific to our departments, and has an automatic update system so users do not need to download new versions manually."

The point is not to dismiss Google Classroom. The point is that this is tailored.

### Q: "How do you handle security? Can students access each other's data?"

> "Firestore security rules enforce role-based access. A student can only read lessons from their enrolled classes. They cannot edit or delete anything. Teachers can post and edit their own content. Only administrators can delete channels or send global alerts. The rules are written in the Firebase security rules language and are evaluated on every database request — there is no client-side bypass."

### Q: "What happens if the internet goes down?"

> "Firestore has local persistence enabled with an unlimited cache. Any data the user has previously loaded — lessons, messages, schedules — is available offline. Writes are queued and sync when connectivity returns. The app also detects connectivity issues on the splash screen and shows a retry button instead of hanging indefinitely."

### Q: "Did you work with a team?"

> "Solo developer. The entire codebase, the database design, the UI, the deployment — I did it myself. I started in February and the current version is 2.2.0."

Short and direct. No need to explain why you worked alone. It is normal for a project of this scope at this level.

### Q: "How many users does it have?"

Be honest here. If it is 30 students and 2 teachers, say that. Do not inflate numbers. But frame it as early adoption, not low adoption:

> "It is currently being used by [X] students and [Y] lecturers across [Z] classes. We are rolling it out gradually — the focus has been on getting the core experience right before pushing it campus-wide."

### Q: "What would you do differently if you started over?"

> "I would have set up the Firestore indexes and security rules before writing any front-end code. I spent the first few weeks writing queries that worked in testing but failed in production because I had not planned the data access patterns. Also, I would have added offline support from day one instead of as a patch later."

This shows maturity. Admitting what you would improve is more impressive than claiming everything was perfect.

### Q: "Is the code open source?"

> "The repository is private right now because it contains configuration keys and some institutional data. I plan to clean the history and make it public once I have removed the sensitive information — the Firebase setup guide and the architecture documentation will be included so other institutions can adapt it."

---

## Part 4: Answers To Questions You Might Get About Yourself

### "You are an electrical engineering student. Why build an app?"

> "The problem existed in my class. I am the one who was losing PDFs and missing schedule changes. Fixing it mattered to me personally. The fact that it involved software instead of circuits was incidental — I used whatever tool solved the problem."

This reframes the question. You are not a programmer who wandered into engineering. You are an engineer who identified a problem and picked up whatever tools were needed to solve it.

### "How long did it take you to learn Flutter?"

> "I wrote my first Dart code in early February. The first working version of the app that could display a lesson from Firestore took about three weeks. The rest was iterative — adding features, breaking things, fixing them, getting feedback from classmates."

Do not downplay the learning curve. But do not exaggerate it either. Three weeks to a working prototype is honest and impressive.

### "Are you planning to pursue software development as a career?"

If yes: "That is the direction I am considering. The process of building something from nothing and watching people use it is deeply satisfying."

If unsure: "I am keeping my options open. Electrical engineering and software are converging rapidly — I think having both perspectives will serve me well regardless of which direction I go."

Both answers are strong. Pick the one that is true.

---

## Part 5: The Setup (Physical)

### What to bring

| Item | Purpose |
|---|---|
| Phone or tablet with the app installed | Primary demo device |
| Backup phone (if available) with the app installed | In case the primary dies |
| Power bank + charging cable | Phones die at events. Guaranteed. |
| Mobile hotspot or prepaid data | Venue Wi-Fi is never reliable |
| Printed sign (A4 or larger) | "KNP Management System — Live Demo" |
| Printed screenshots (optional) | Backup if the network fails entirely |
| Water bottle | Speaking dries your throat |

### Tent layout

- Place the phone on a stand or small riser so it is visible without being picked up
- Keep the sign at eye level
- Do not sit behind a table. Stand beside it. Sitting creates a barrier. Standing says "come talk to me"
- If you have slides on a laptop, angle the screen so visitors can see it from the walking path

### Dealing with network failure

If the network is completely dead and your hotspot is not working:

1. Open the app beforehand while you still have signal. Firestore cache will keep the data visible.
2. If even that fails, use the printed screenshots.
3. Explain: "The app normally runs live, but the network here is struggling. The screenshots show the actual interface — let me walk you through what each screen does."

Even if the demo does not work perfectly, the conversation still matters.

---

## Part 6: The Close

When the conversation is winding down, end with a clear next step:

> "I appreciate you stopping by. If you want to try it yourself, the app is available for download — I can send you the link. I am also open to feedback if there is something you would like to see added."

If they are faculty or administration:

> "If you would like to see how this could work for your department, I can set up a walkthrough with your class. It takes about five minutes to onboard a cohort."

---

## Part 7: Mindset

A few things to keep in mind walking in:

**You built something real.** It is installed on phones. People use it. That already separates you from most projects at a tent fair. Do not compare yourself to Google or Microsoft. Compare yourself to yourself four months ago.

**The technical questions are the easy ones.** You know how every part of this app works because you wrote every line. If someone asks something you do not know, that is fine — "I have not tested that path yet, but I can look into it" is a perfectly good answer.

**The nerves do not go away.** They get quieter after the first conversation. By the third or fourth person, you will find your rhythm. Trust that.

**Your background is not a disadvantage.** An electrical engineering student who built a production mobile app is more interesting than a CS student who built a to-do list. The story is better. The context makes people pay attention.

---

*Prepared for Sheldon Ramu — Kabete National Polytechnique*
*KNP Management System — Version 2.2.0*
*June 2026*
