Development Firestore rules and deployment

This project doesn't include Firestore rules by default. For local development
you can use the provided `firestore.rules` file which allows authenticated
users to read/write documents. IMPORTANT: these rules are permissive and are
NOT suitable for production.

How to deploy (requires Firebase CLI and being logged in):

1. Install/authorize Firebase CLI if you haven't already:

```powershell
npm install -g firebase-tools
firebase login
```

2. Deploy only rules to your project (replace `<PROJECT_ID>`):

```powershell
cd backend
firebase deploy --only firestore:rules --project <PROJECT_ID>
```

3. Alternatively, open the Firebase Console → Firestore → Rules and paste
   the contents of `firestore.rules` for manual editing.

Notes and safety
- These rules allow any authenticated user to read/write any document.
  Use them only during development or when running against a test project.
- For production, scope rules to collections and fields (e.g. limit writes to
  a user's own profile doc) and require admin-only paths to use custom claims.
- If your app expects writes to succeed for new users during sign-up, ensure
  the rules permit writes from authenticated users and that your sign-up
  sequence obtains an auth token before writing user profile documents.

If you want, I can:
- Deploy these rules to a Firebase project you indicate (you must provide the
  project id and confirm you want a permissive dev rule deployed), or
- Create a safer example rules file that allows unauthenticated writes only to
  `users/{uid}` with validation, suitable for typical sign-up flows.
