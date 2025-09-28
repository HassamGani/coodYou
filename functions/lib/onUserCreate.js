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
exports.onUserCreate = void 0;
const admin = __importStar(require("firebase-admin"));
const functions = __importStar(require("firebase-functions"));
const db = admin.firestore();
const auth = admin.auth();
function emailDomain(email) {
    if (!email)
        return null;
    const parts = email.toLowerCase().trim().split("@");
    if (parts.length < 2)
        return null;
    return parts[parts.length - 1];
}
exports.onUserCreate = functions.auth.user().onCreate(async (user) => {
    try {
        const uid = user.uid;
        const email = user.email ?? "";
        const firstName = user.displayName ? user.displayName.split(" ")[0] : "";
        const lastName = user.displayName
            ? user.displayName.split(" ").slice(1).join(" ")
            : "";
        const domain = emailDomain(email);
        let matchedSchoolId = null;
        let matchedSchoolIds = [];
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
        };
        await db.collection("users").doc(uid).set(userDoc);
        if (canDash) {
            const claims = { canDash: true };
            if (matchedSchoolIds.length > 0) {
                claims.schoolIds = matchedSchoolIds;
            }
            await auth.setCustomUserClaims(uid, claims);
        }
        console.log(`Created user document for uid=${uid}, matchedSchool=${matchedSchoolId}, canDash=${canDash}`);
    }
    catch (err) {
        console.error("onUserCreate error:", err);
    }
});
//# sourceMappingURL=onUserCreate.js.map