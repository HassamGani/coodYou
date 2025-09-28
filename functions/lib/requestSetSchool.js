"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.requestSetSchool = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
admin.initializeApp();
const db = admin.firestore();
exports.requestSetSchool = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Authentication required");
    }
    const uid = context.auth.uid;
    const schoolId = data.schoolId;
    if (!schoolId) {
        throw new functions.https.HttpsError("invalid-argument", "schoolId is required");
    }
    const userDocRef = db.collection("users").doc(uid);
    const userSnap = await userDocRef.get();
    const userData = userSnap.exists ? userSnap.data() : {};
    const eligible = userData?.eligibleSchoolIds;
    if (eligible && eligible.length > 0) {
        if (!eligible.includes(schoolId)) {
            throw new functions.https.HttpsError("permission-denied", "User not eligible for requested school");
        }
        await userDocRef.set({ schoolId }, { merge: true });
        return { success: true };
    }
    const userEmail = context.auth.token.email;
    if (!userEmail) {
        throw new functions.https.HttpsError("failed-precondition", "No email available for user");
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
    const allowed = school?.allowedEmailDomains || [];
    if (!allowed.map((d) => d.toLowerCase()).includes(domain)) {
        throw new functions.https.HttpsError("permission-denied", "Email domain not allowed for school");
    }
    await userDocRef.set({ schoolId }, { merge: true });
    return { success: true };
});
//# sourceMappingURL=requestSetSchool.js.map