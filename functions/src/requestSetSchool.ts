import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

export const requestSetSchool = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Authentication required"
      );
    }
    const uid = context.auth.uid;
    const schoolId = data.schoolId as string | undefined;
    if (!schoolId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "schoolId is required"
      );
    }

    // Fetch user doc if present
    const userDocRef = db.collection("users").doc(uid);
    const userSnap = await userDocRef.get();
    const userData = userSnap.exists ? userSnap.data() : {};

    // If server already wrote eligibleSchoolIds, prefer that list for verification
    const eligible: string[] | undefined = userData?.eligibleSchoolIds as
      | string[]
      | undefined;
    if (eligible && eligible.length > 0) {
      if (!eligible.includes(schoolId)) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "User not eligible for requested school"
        );
      }
      // OK - set authoritative schoolId
      await userDocRef.set({ schoolId }, { merge: true });
      return { success: true };
    }

    // Fallback: verify by email domain against the school's allowed domains
    const userEmail = context.auth.token.email as string | undefined;
    if (!userEmail) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "No email available for user"
      );
    }
    const domain = userEmail.split("@").pop()?.toLowerCase();
    if (!domain) {
      throw new functions.https.HttpsError("invalid-argument", "Invalid email");
    }

    const schoolSnap = await db.collection("schools").doc(schoolId).get();
    if (!schoolSnap.exists) {
      throw new functions.https.HttpsError("not-found", "School not found");
    }
    const school = schoolSnap.data();
    const allowed: string[] = school?.allowedEmailDomains || [];
    if (!allowed.map((d) => d.toLowerCase()).includes(domain)) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Email domain not allowed for school"
      );
    }

    await userDocRef.set({ schoolId }, { merge: true });
    return { success: true };
  }
);
