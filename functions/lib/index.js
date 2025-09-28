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
exports.recalculatePricing = exports.requestStripeOnboarding = exports.updateDasherAvailability = exports.requestSetSchool = exports.cleanupExpiredRequests = exports.completeDeliveryRequest = exports.respondToDeliveryRequest = exports.createDeliveryRequest = exports.markDelivered = exports.markPickedUp = exports.claimRun = exports.cancelOrder = exports.queueOrder = void 0;
const admin = __importStar(require("firebase-admin"));
const functions = __importStar(require("firebase-functions"));
const zod_1 = require("zod");
admin.initializeApp();
require("./onUserCreate");
const db = admin.firestore();
const runtimeOpts = {
    memory: "512MB",
    timeoutSeconds: 120,
};
const orderStatus = {
    requested: "requested",
    pooled: "pooled",
    readyToAssign: "readyToAssign",
    claimed: "claimed",
    inProgress: "inProgress",
    delivered: "delivered",
    paid: "paid",
    closed: "closed",
    expired: "expired",
    cancelledBuyer: "cancelledBuyer",
    cancelledDasher: "cancelledDasher",
    disputed: "disputed",
};
const windowPrices = {
    breakfast: "price_breakfast",
    lunch: "price_lunch",
    dinner: "price_dinner",
};
const STRIPE_PERCENT_FEE = 0.029;
const STRIPE_FIXED_FEE_CENTS = 30;
function assertAuth(context) {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Authentication is required");
    }
    return context.auth.uid;
}
async function computeLivePoolSnapshot(hallId, windowType) {
    const snapshot = await db
        .collection("orders")
        .where("hallId", "==", hallId)
        .where("windowType", "==", windowType)
        .where("status", "in", [orderStatus.requested, orderStatus.pooled])
        .get();
    const now = admin.firestore.Timestamp.now();
    const avgWait = snapshot.docs.length
        ? snapshot.docs.reduce((acc, doc) => {
            const createdAt = doc.get("createdAt");
            return (acc + (now.toMillis() - createdAt.toMillis()) / snapshot.docs.length);
        }, 0)
        : 0;
    await db
        .collection("hallPools")
        .doc(`${hallId}_${windowType}`)
        .set({
        hallId,
        windowType,
        queueSize: snapshot.size,
        averageWaitSeconds: Math.round(avgWait / 1000),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
}
async function fetchOrCreatePairGroup(hallId, windowType, transaction) {
    const pairGroupsRef = db.collection("pair_groups");
    const openGroupQuery = pairGroupsRef
        .where("hallId", "==", hallId)
        .where("windowType", "==", windowType)
        .where("status", "==", "open")
        .limit(1);
    const openGroupSnap = await transaction.get(openGroupQuery);
    if (!openGroupSnap.empty) {
        return openGroupSnap.docs[0];
    }
    const groupRef = pairGroupsRef.doc();
    const pin = Math.floor(100000 + Math.random() * 900000).toString();
    transaction.set(groupRef, {
        hallId,
        windowType,
        targetSize: 2,
        filledCount: 0,
        status: "open",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        pin,
    });
    return await transaction.get(groupRef);
}
exports.queueOrder = functions
    .runWith(runtimeOpts)
    .https.onCall(async (data, context) => {
    const uid = assertAuth(context);
    const payload = zod_1.z
        .object({
        orderId: zod_1.z.string(),
    })
        .parse(data);
    const orderRef = db.collection("orders").doc(payload.orderId);
    await db.runTransaction(async (transaction) => {
        const orderSnap = await transaction.get(orderRef);
        if (!orderSnap.exists) {
            throw new functions.https.HttpsError("not-found", "Order does not exist");
        }
        const orderData = orderSnap.data();
        if (orderData.userId !== uid) {
            throw new functions.https.HttpsError("permission-denied", "Cannot queue another user's order");
        }
        const hallId = orderData.hallId;
        const windowType = orderData.windowType;
        const pairDoc = await fetchOrCreatePairGroup(hallId, windowType, transaction);
        const groupData = pairDoc.data();
        if (groupData.filledCount >= groupData.targetSize) {
            throw new functions.https.HttpsError("failed-precondition", "Pair group full");
        }
        const groupPin = groupData.pin
            ? groupData.pin
            : Math.floor(100000 + Math.random() * 900000).toString();
        if (!groupData.pin) {
            transaction.update(pairDoc.ref, { pin: groupPin });
        }
        const newFilledCount = groupData.filledCount + 1;
        transaction.update(pairDoc.ref, { filledCount: newFilledCount });
        transaction.update(orderRef, {
            status: newFilledCount >= groupData.targetSize
                ? orderStatus.readyToAssign
                : orderStatus.pooled,
            pairGroupId: pairDoc.id,
            pinCode: groupPin,
        });
        if (newFilledCount >= groupData.targetSize) {
            transaction.update(pairDoc.ref, { status: "filled" });
            const runRef = db.collection("runs").doc();
            const ordersQuery = await transaction.get(db.collection("orders").where("pairGroupId", "==", pairDoc.id));
            const estimatedPayout = ordersQuery.docs.reduce((sum, doc) => {
                return sum + doc.get("priceCents");
            }, 0);
            transaction.set(runRef, {
                hallId,
                pairGroupId: pairDoc.id,
                status: orderStatus.readyToAssign,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                dasherId: null,
                estimatedPayoutCents: estimatedPayout,
                deliveryPin: groupPin,
            });
            ordersQuery.docs.forEach((doc) => {
                const orderData = doc.data();
                orderData.pinCode = groupPin;
                transaction.update(db.collection("orders").doc(doc.id), {
                    status: orderStatus.readyToAssign,
                    pinCode: groupPin,
                });
                transaction.set(runRef.collection("orders").doc(doc.id), orderData);
            });
        }
    });
    const orderSnapshot = await orderRef.get();
    await computeLivePoolSnapshot(orderSnapshot.get("hallId"), orderSnapshot.get("windowType"));
    return { ok: true };
});
exports.cancelOrder = functions
    .runWith(runtimeOpts)
    .https.onCall(async (data, context) => {
    const uid = assertAuth(context);
    const payload = zod_1.z.object({ orderId: zod_1.z.string() }).parse(data);
    const orderRef = db.collection("orders").doc(payload.orderId);
    await db.runTransaction(async (transaction) => {
        const orderSnap = await transaction.get(orderRef);
        if (!orderSnap.exists) {
            throw new functions.https.HttpsError("not-found", "Order missing");
        }
        const orderData = orderSnap.data();
        if (orderData.userId !== uid) {
            throw new functions.https.HttpsError("permission-denied", "Cannot cancel another user's order");
        }
        const status = orderData.status;
        if (status !== orderStatus.requested && status !== orderStatus.pooled) {
            throw new functions.https.HttpsError("failed-precondition", "Order cannot be cancelled");
        }
        transaction.update(orderRef, { status: orderStatus.cancelledBuyer });
    });
    const snapshot = await orderRef.get();
    await computeLivePoolSnapshot(snapshot.get("hallId"), snapshot.get("windowType"));
    return { ok: true };
});
exports.claimRun = functions
    .runWith(runtimeOpts)
    .https.onCall(async (data, context) => {
    const uid = assertAuth(context);
    const payload = zod_1.z.object({ runId: zod_1.z.string() }).parse(data);
    const runRef = db.collection("runs").doc(payload.runId);
    await db.runTransaction(async (transaction) => {
        const runSnap = await transaction.get(runRef);
        if (!runSnap.exists) {
            throw new functions.https.HttpsError("not-found", "Run missing");
        }
        const runData = runSnap.data();
        if (runData.status !== orderStatus.readyToAssign) {
            throw new functions.https.HttpsError("failed-precondition", "Run is not available");
        }
        transaction.update(runRef, {
            status: orderStatus.claimed,
            dasherId: uid,
            claimedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        const ordersRef = runRef.collection("orders");
        const ordersSnap = await transaction.get(ordersRef);
        ordersSnap.docs.forEach((doc) => {
            transaction.update(db.collection("orders").doc(doc.id), {
                status: orderStatus.claimed,
            });
            transaction.update(runRef.collection("orders").doc(doc.id), {
                status: orderStatus.claimed,
            });
        });
    });
    return { ok: true };
});
exports.markPickedUp = functions
    .runWith(runtimeOpts)
    .https.onCall(async (data, context) => {
    const uid = assertAuth(context);
    const payload = zod_1.z.object({ runId: zod_1.z.string() }).parse(data);
    const runRef = db.collection("runs").doc(payload.runId);
    await db.runTransaction(async (transaction) => {
        const runSnap = await transaction.get(runRef);
        if (!runSnap.exists) {
            throw new functions.https.HttpsError("not-found", "Run missing");
        }
        const runData = runSnap.data();
        if (runData.dasherId !== uid) {
            throw new functions.https.HttpsError("permission-denied", "Cannot update another dasher's run");
        }
        transaction.update(runRef, {
            status: orderStatus.inProgress,
            pickedUpAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        const ordersRef = runRef.collection("orders");
        const ordersSnap = await transaction.get(ordersRef);
        ordersSnap.docs.forEach((doc) => {
            transaction.update(db.collection("orders").doc(doc.id), {
                status: orderStatus.inProgress,
            });
            transaction.update(runRef.collection("orders").doc(doc.id), {
                status: orderStatus.inProgress,
            });
        });
    });
    return { ok: true };
});
exports.markDelivered = functions
    .runWith(runtimeOpts)
    .https.onCall(async (data, context) => {
    const uid = assertAuth(context);
    const payload = zod_1.z
        .object({ runId: zod_1.z.string(), pin: zod_1.z.string().min(4) })
        .parse(data);
    const runRef = db.collection("runs").doc(payload.runId);
    await db.runTransaction(async (transaction) => {
        const runSnap = await transaction.get(runRef);
        if (!runSnap.exists) {
            throw new functions.https.HttpsError("not-found", "Run missing");
        }
        const runData = runSnap.data();
        if (runData.dasherId !== uid) {
            throw new functions.https.HttpsError("permission-denied", "Cannot update another dasher's run");
        }
        const ordersRef = runRef.collection("orders");
        const ordersSnap = await transaction.get(ordersRef);
        const providedPins = payload.pin
            .split(/[,\s]+/)
            .map((value) => value.trim())
            .filter((value) => value.length > 0);
        const invalidPins = ordersSnap.docs.filter((doc) => {
            const storedPin = doc.get("pinCode");
            return !providedPins.includes(storedPin);
        });
        if (invalidPins.length > 0) {
            throw new functions.https.HttpsError("failed-precondition", "PIN does not match");
        }
        transaction.update(runRef, {
            status: orderStatus.delivered,
            deliveredAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        ordersSnap.docs.forEach((doc) => {
            transaction.update(db.collection("orders").doc(doc.id), {
                status: orderStatus.delivered,
            });
            transaction.update(runRef.collection("orders").doc(doc.id), {
                status: orderStatus.delivered,
            });
        });
        const totalCents = ordersSnap.docs.reduce((sum, doc) => {
            return sum + doc.get("priceCents");
        }, 0);
        const platformConfig = await transaction.get(db.collection("config").doc("platform_fee"));
        const platformFeeDefault = functions.config().platform?.fee_default
            ? Number(functions.config().platform?.fee_default)
            : 0;
        const hallFee = platformConfig.exists
            ? platformConfig.get(runData.hallId) ??
                platformConfig.get("default") ??
                platformFeeDefault
            : platformFeeDefault;
        const platformFeeCents = Math.round(hallFee * 100);
        const processingFeeCents = Math.round(totalCents * STRIPE_PERCENT_FEE) + STRIPE_FIXED_FEE_CENTS;
        const payoutCents = Math.max(totalCents - platformFeeCents - processingFeeCents, 0);
        const paymentRef = db.collection("payments").doc();
        transaction.set(paymentRef, {
            runId: runRef.id,
            dasherId: uid,
            buyerIds: ordersSnap.docs.map((doc) => doc.get("userId")),
            amountCents: totalCents,
            feeCents: platformFeeCents + processingFeeCents,
            payoutCents,
            status: "captured",
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    });
    return { ok: true };
});
exports.createDeliveryRequest = functions
    .runWith(runtimeOpts)
    .https.onCall(async (data, context) => {
    const uid = assertAuth(context);
    const payload = zod_1.z
        .object({
        orderId: zod_1.z.string(),
        hallId: zod_1.z.string(),
        windowType: zod_1.z.enum(["breakfast", "lunch", "dinner"]),
        items: zod_1.z.array(zod_1.z.string()),
        instructions: zod_1.z.string().optional(),
        meetPoint: zod_1.z.object({
            latitude: zod_1.z.number(),
            longitude: zod_1.z.number(),
            description: zod_1.z.string(),
        }),
    })
        .parse(data);
    const orderRef = db.collection("orders").doc(payload.orderId);
    const orderDoc = await orderRef.get();
    if (!orderDoc.exists) {
        throw new functions.https.HttpsError("not-found", "Order not found");
    }
    const orderData = orderDoc.data();
    if (orderData.userId !== uid) {
        throw new functions.https.HttpsError("permission-denied", "Cannot create delivery request for another user's order");
    }
    const availableDashersSnap = await db
        .collection("dasherAvailability")
        .where("isOnline", "==", true)
        .get();
    const candidateDasherIds = availableDashersSnap.docs
        .map(doc => doc.id)
        .filter(dasherId => dasherId !== uid);
    if (candidateDasherIds.length === 0) {
        throw new functions.https.HttpsError("failed-precondition", "No dashers currently available");
    }
    const requestRef = db.collection("deliveryRequests").doc();
    const expirationTime = new Date(Date.now() + 10 * 60 * 1000);
    await requestRef.set({
        id: requestRef.id,
        orderId: payload.orderId,
        buyerId: uid,
        hallId: payload.hallId,
        windowType: payload.windowType,
        status: "open",
        requestedAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: admin.firestore.Timestamp.fromDate(expirationTime),
        items: payload.items,
        instructions: payload.instructions || "",
        meetPoint: payload.meetPoint,
        assignedDasherId: null,
        candidateDasherIds,
        createdBy: uid,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await orderRef.update({
        deliveryRequestId: requestRef.id,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return { requestId: requestRef.id, candidateCount: candidateDasherIds.length };
});
exports.respondToDeliveryRequest = functions
    .runWith(runtimeOpts)
    .https.onCall(async (data, context) => {
    const uid = assertAuth(context);
    const payload = zod_1.z
        .object({
        requestId: zod_1.z.string(),
        response: zod_1.z.enum(["accept", "decline"]),
    })
        .parse(data);
    const requestRef = db.collection("deliveryRequests").doc(payload.requestId);
    await db.runTransaction(async (transaction) => {
        const requestDoc = await transaction.get(requestRef);
        if (!requestDoc.exists) {
            throw new functions.https.HttpsError("not-found", "Delivery request not found");
        }
        const requestData = requestDoc.data();
        if (!requestData.candidateDasherIds.includes(uid)) {
            throw new functions.https.HttpsError("permission-denied", "Not eligible to respond to this request");
        }
        if (requestData.status !== "open") {
            throw new functions.https.HttpsError("failed-precondition", "Request is no longer open");
        }
        if (payload.response === "accept") {
            transaction.update(requestRef, {
                status: "assigned",
                assignedDasherId: uid,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            const orderRef = db.collection("orders").doc(requestData.orderId);
            transaction.update(orderRef, {
                dasherId: uid,
                status: "assigned",
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }
        else {
            const updatedCandidates = requestData.candidateDasherIds.filter((id) => id !== uid);
            transaction.update(requestRef, {
                candidateDasherIds: updatedCandidates,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            if (updatedCandidates.length === 0) {
                transaction.update(requestRef, {
                    status: "expired",
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                });
            }
        }
    });
    return { ok: true };
});
exports.completeDeliveryRequest = functions
    .runWith(runtimeOpts)
    .https.onCall(async (data, context) => {
    const uid = assertAuth(context);
    const payload = zod_1.z
        .object({
        requestId: zod_1.z.string(),
        pin: zod_1.z.string().min(4),
    })
        .parse(data);
    const requestRef = db.collection("deliveryRequests").doc(payload.requestId);
    await db.runTransaction(async (transaction) => {
        const requestDoc = await transaction.get(requestRef);
        if (!requestDoc.exists) {
            throw new functions.https.HttpsError("not-found", "Delivery request not found");
        }
        const requestData = requestDoc.data();
        if (requestData.assignedDasherId !== uid) {
            throw new functions.https.HttpsError("permission-denied", "Not assigned to this delivery request");
        }
        const orderRef = db.collection("orders").doc(requestData.orderId);
        const orderDoc = await transaction.get(orderRef);
        if (!orderDoc.exists) {
            throw new functions.https.HttpsError("not-found", "Associated order not found");
        }
        const orderData = orderDoc.data();
        if (orderData.pinCode !== payload.pin) {
            throw new functions.https.HttpsError("failed-precondition", "Invalid PIN code");
        }
        transaction.update(requestRef, {
            status: "completed",
            completedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        transaction.update(orderRef, {
            status: "delivered",
            deliveredAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    });
    return { ok: true };
});
exports.cleanupExpiredRequests = functions.pubsub
    .schedule("every 5 minutes")
    .onRun(async () => {
    const now = admin.firestore.Timestamp.now();
    const expiredRequestsSnap = await db
        .collection("deliveryRequests")
        .where("status", "==", "open")
        .where("expiresAt", "<=", now)
        .get();
    const batch = db.batch();
    expiredRequestsSnap.docs.forEach((doc) => {
        batch.update(doc.ref, {
            status: "expired",
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    });
    await batch.commit();
    console.log(`Expired ${expiredRequestsSnap.size} delivery requests`);
});
exports.requestSetSchool = functions
    .runWith(runtimeOpts)
    .https.onCall(async (data, context) => {
    const uid = assertAuth(context);
    const payload = zod_1.z
        .object({
        schoolId: zod_1.z.string(),
        verificationData: zod_1.z.string().optional(),
    })
        .parse(data);
    const schoolDoc = await db.collection("schools").doc(payload.schoolId).get();
    if (!schoolDoc.exists) {
        throw new functions.https.HttpsError("not-found", "School not found");
    }
    const userRef = db.collection("users").doc(uid);
    await userRef.update({
        schoolId: payload.schoolId,
        canDash: true,
        rolePreferences: ["buyer", "dasher"],
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await admin.auth().setCustomUserClaims(uid, {
        canDash: true,
        schoolId: payload.schoolId,
    });
    return { ok: true };
});
exports.updateDasherAvailability = functions
    .runWith(runtimeOpts)
    .https.onCall(async (data, context) => {
    const uid = assertAuth(context);
    const payload = zod_1.z
        .object({
        dasherId: zod_1.z.string(),
        isOnline: zod_1.z.boolean(),
    })
        .parse(data);
    if (payload.dasherId !== uid) {
        throw new functions.https.HttpsError("permission-denied", "Dashers can only update their own availability");
    }
    await db.collection("dasherAvailability").doc(uid).set({
        id: uid,
        isOnline: payload.isOnline,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    return { ok: true };
});
exports.requestStripeOnboarding = functions
    .runWith(runtimeOpts)
    .https.onCall(async (data, context) => {
    const uid = assertAuth(context);
    const payload = zod_1.z
        .object({
        uid: zod_1.z.string(),
    })
        .parse(data);
    if (uid !== payload.uid) {
        throw new functions.https.HttpsError("permission-denied", "Cannot bootstrap another account");
    }
    return { completed: false };
});
exports.recalculatePricing = functions.pubsub
    .schedule("every 24 hours")
    .onRun(async () => {
    const hallsSnap = await db.collection("dining_halls").get();
    const batch = db.batch();
    hallsSnap.docs.forEach((hallDoc) => {
        const price = hallDoc.get(windowPrices.dinner);
        batch.set(db.collection("config").doc("pricing"), {
            [hallDoc.id]: {
                breakfast: hallDoc.get(windowPrices.breakfast),
                lunch: hallDoc.get(windowPrices.lunch),
                dinner: price,
            },
        }, { merge: true });
    });
    await batch.commit();
});
//# sourceMappingURL=index.js.map