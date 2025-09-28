import * as admin from "firebase-admin";
import * as functions from "firebase-functions";

const db = admin.firestore();
const auth = admin.auth();

function emailDomain(email?: string): string | null {
  if (!email) return null;
  const parts = email.toLowerCase().trim().split("@");
  if (parts.length < 2) return null;
  return parts[parts.length - 1];
}

export const onUserCreate = functions.auth.user().onCreate(async (user) => {
  try {
    const uid = user.uid;
    const email = user.email ?? "";
    const firstName = user.displayName ? user.displayName.split(" ")[0] : "";
    const lastName = user.displayName
      ? user.displayName.split(" ").slice(1).join(" ")
      : "";

    const domain = emailDomain(email);

    let matchedSchoolId: string | null = null;
    let matchedSchoolIds: string[] = [];
    let canDash = false;

    if (domain) {
      const schoolsSnap = await db
        .collection("schools")
        .where("allowedEmailDomains", "array-contains", domain)
        .get();

      if (!schoolsSnap.empty) {
        matchedSchoolIds = schoolsSnap.docs.map((d) => d.id);
        matchedSchoolId = matchedSchoolIds[0] ?? null;
        canDash = matchedSchoolIds.length > 0;
      }
    }

    const now = admin.firestore.FieldValue.serverTimestamp();

    const userDoc = {
      id: uid,
      firstName: firstName ?? "",
      lastName: lastName ?? "",
      email: email,
      phoneNumber: user.phoneNumber ?? null,
      rolePreferences: canDash ? ["buyer", "dasher"] : ["buyer"],
      canDash: canDash,
      eligibleSchoolIds: matchedSchoolIds,
      rating: 5.0,
      completedRuns: 0,
      stripeConnected: false,
      pushToken: null,
      schoolId: matchedSchoolId,
      defaultPaymentMethodId: null,
      paymentProviderPreferences: ["applePay", "stripeCard"],
      settings: {
        pushNotificationsEnabled: true,
        locationSharingEnabled: false,
        autoAcceptDashRuns: false,
        applePayDoubleConfirmation: true,
      },
      createdAt: now,
    } as const;

    await db.collection("users").doc(uid).set(userDoc);

    if (canDash) {
      const claims: Record<string, any> = { canDash: true };
      if (matchedSchoolIds.length > 0) {
        claims.schoolIds = matchedSchoolIds;
      }
      await auth.setCustomUserClaims(uid, claims);
    }

    console.log(
      `Created user document for uid=${uid}, matchedSchool=${matchedSchoolId}, canDash=${canDash}`
    );
  } catch (err) {
    console.error("onUserCreate error:", err);
  }
});
