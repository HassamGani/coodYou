import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import { z } from "zod";
import "./onUserCreate";

admin.initializeApp();

const db = admin.firestore();
const runtimeOpts: functions.RuntimeOptions = {
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
} as const;

type OrderStatus = (typeof orderStatus)[keyof typeof orderStatus];

type ServiceWindow = "breakfast" | "lunch" | "dinner";

const windowPrices: Record<ServiceWindow, string> = {
  breakfast: "price_breakfast",
  lunch: "price_lunch",
  dinner: "price_dinner",
};

const STRIPE_PERCENT_FEE = 0.029;
const STRIPE_FIXED_FEE_CENTS = 30;

function assertAuth(context: functions.https.CallableContext): string {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "Authentication is required"
    );
  }
  return context.auth.uid;
}

async function computeLivePoolSnapshot(
  hallId: string,
  windowType: ServiceWindow
) {
  const snapshot = await db
    .collection("orders")
    .where("hallId", "==", hallId)
    .where("windowType", "==", windowType)
    .where("status", "in", [orderStatus.requested, orderStatus.pooled])
    .get();

  const now = admin.firestore.Timestamp.now();
  const avgWait = snapshot.docs.length
    ? snapshot.docs.reduce((acc, doc) => {
        const createdAt = doc.get("createdAt") as admin.firestore.Timestamp;
        return (
          acc + (now.toMillis() - createdAt.toMillis()) / snapshot.docs.length
        );
      }, 0)
    : 0;

  await db
    .collection("hallPools")
    .doc(`${hallId}_${windowType}`)
    .set(
      {
        hallId,
        windowType,
        queueSize: snapshot.size,
        averageWaitSeconds: Math.round(avgWait / 1000),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
}

async function fetchOrCreatePairGroup(
  hallId: string,
  windowType: ServiceWindow,
  transaction: FirebaseFirestore.Transaction
) {
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

export const queueOrder = functions
  .runWith(runtimeOpts)
  .https.onCall(async (data, context) => {
    const uid = assertAuth(context);
    const payload = z
      .object({
        orderId: z.string(),
      })
      .parse(data);

    const orderRef = db.collection("orders").doc(payload.orderId);

    await db.runTransaction(async (transaction) => {
      const orderSnap = await transaction.get(orderRef);
      if (!orderSnap.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "Order does not exist"
        );
      }
      const orderData = orderSnap.data()!;
      if (orderData.userId !== uid) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "Cannot queue another user's order"
        );
      }
      const hallId = orderData.hallId as string;
      const windowType = orderData.windowType as ServiceWindow;
      const pairDoc = await fetchOrCreatePairGroup(
        hallId,
        windowType,
        transaction
      );
      const groupData = pairDoc.data()!;
      if (groupData.filledCount >= groupData.targetSize) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "Pair group full"
        );
      }

      const groupPin = groupData.pin
        ? (groupData.pin as string)
        : Math.floor(100000 + Math.random() * 900000).toString();
      if (!groupData.pin) {
        transaction.update(pairDoc.ref, { pin: groupPin });
      }

      const newFilledCount = groupData.filledCount + 1;
      transaction.update(pairDoc.ref, { filledCount: newFilledCount });
      transaction.update(orderRef, {
        status:
          newFilledCount >= groupData.targetSize
            ? orderStatus.readyToAssign
            : orderStatus.pooled,
        pairGroupId: pairDoc.id,
        pinCode: groupPin,
      });

      if (newFilledCount >= groupData.targetSize) {
        transaction.update(pairDoc.ref, { status: "filled" });
        const runRef = db.collection("runs").doc();
        const ordersQuery = await transaction.get(
          db.collection("orders").where("pairGroupId", "==", pairDoc.id)
        );
        const estimatedPayout = ordersQuery.docs.reduce((sum, doc) => {
          return sum + (doc.get("priceCents") as number);
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
    await computeLivePoolSnapshot(
      orderSnapshot.get("hallId") as string,
      orderSnapshot.get("windowType") as ServiceWindow
    );

    return { ok: true };
  });

export const cancelOrder = functions
  .runWith(runtimeOpts)
  .https.onCall(async (data, context) => {
    const uid = assertAuth(context);
    const payload = z.object({ orderId: z.string() }).parse(data);
    const orderRef = db.collection("orders").doc(payload.orderId);
    await db.runTransaction(async (transaction) => {
      const orderSnap = await transaction.get(orderRef);
      if (!orderSnap.exists) {
        throw new functions.https.HttpsError("not-found", "Order missing");
      }
      const orderData = orderSnap.data()!;
      if (orderData.userId !== uid) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "Cannot cancel another user's order"
        );
      }
      const status = orderData.status as OrderStatus;
      if (status !== orderStatus.requested && status !== orderStatus.pooled) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "Order cannot be cancelled"
        );
      }
      transaction.update(orderRef, { status: orderStatus.cancelledBuyer });
    });

    const snapshot = await orderRef.get();
    await computeLivePoolSnapshot(
      snapshot.get("hallId") as string,
      snapshot.get("windowType") as ServiceWindow
    );

    return { ok: true };
  });

export const claimRun = functions
  .runWith(runtimeOpts)
  .https.onCall(async (data, context) => {
    const uid = assertAuth(context);
    const payload = z.object({ runId: z.string() }).parse(data);
    const runRef = db.collection("runs").doc(payload.runId);

    await db.runTransaction(async (transaction) => {
      const runSnap = await transaction.get(runRef);
      if (!runSnap.exists) {
        throw new functions.https.HttpsError("not-found", "Run missing");
      }
      const runData = runSnap.data()!;
      if (runData.status !== orderStatus.readyToAssign) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "Run is not available"
        );
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

export const markPickedUp = functions
  .runWith(runtimeOpts)
  .https.onCall(async (data, context) => {
    const uid = assertAuth(context);
    const payload = z.object({ runId: z.string() }).parse(data);
    const runRef = db.collection("runs").doc(payload.runId);

    await db.runTransaction(async (transaction) => {
      const runSnap = await transaction.get(runRef);
      if (!runSnap.exists) {
        throw new functions.https.HttpsError("not-found", "Run missing");
      }
      const runData = runSnap.data()!;
      if (runData.dasherId !== uid) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "Cannot update another dasher's run"
        );
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

export const markDelivered = functions
  .runWith(runtimeOpts)
  .https.onCall(async (data, context) => {
    const uid = assertAuth(context);
    const payload = z
      .object({ runId: z.string(), pin: z.string().min(4) })
      .parse(data);
    const runRef = db.collection("runs").doc(payload.runId);

    await db.runTransaction(async (transaction) => {
      const runSnap = await transaction.get(runRef);
      if (!runSnap.exists) {
        throw new functions.https.HttpsError("not-found", "Run missing");
      }
      const runData = runSnap.data()!;
      if (runData.dasherId !== uid) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "Cannot update another dasher's run"
        );
      }
      const ordersRef = runRef.collection("orders");
      const ordersSnap = await transaction.get(ordersRef);
      const providedPins = payload.pin
        .split(/[,\s]+/)
        .map((value) => value.trim())
        .filter((value) => value.length > 0);
      const invalidPins = ordersSnap.docs.filter((doc) => {
        const storedPin = doc.get("pinCode") as string;
        return !providedPins.includes(storedPin);
      });
      if (invalidPins.length > 0) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "PIN does not match"
        );
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
        return sum + (doc.get("priceCents") as number);
      }, 0);
      const platformConfig = await transaction.get(
        db.collection("config").doc("platform_fee")
      );
      const platformFeeDefault = functions.config().platform?.fee_default
        ? Number(functions.config().platform?.fee_default)
        : 0;
      const hallFee = platformConfig.exists
        ? platformConfig.get(runData.hallId) ??
          platformConfig.get("default") ??
          platformFeeDefault
        : platformFeeDefault;
      const platformFeeCents = Math.round((hallFee as number) * 100);
      const processingFeeCents =
        Math.round(totalCents * STRIPE_PERCENT_FEE) + STRIPE_FIXED_FEE_CENTS;
      const payoutCents = Math.max(
        totalCents - platformFeeCents - processingFeeCents,
        0
      );

      const paymentRef = db.collection("payments").doc();
      transaction.set(paymentRef, {
        runId: runRef.id,
        dasherId: uid,
        buyerIds: ordersSnap.docs.map((doc) => doc.get("userId") as string),
        amountCents: totalCents,
        feeCents: platformFeeCents + processingFeeCents,
        payoutCents,
        status: "captured",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    return { ok: true };
  });

export const requestStripeOnboarding = functions
  .runWith(runtimeOpts)
  .https.onCall(async (data, context) => {
    const uid = assertAuth(context);
    const payload = z
      .object({
        uid: z.string(),
      })
      .parse(data);

    if (uid !== payload.uid) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Cannot bootstrap another account"
      );
    }

    // Placeholder response – integrate with Stripe onboarding link creation later.
    return { completed: false };
  });

export const recalculatePricing = functions.pubsub
  .schedule("every 24 hours")
  .onRun(async () => {
    const hallsSnap = await db.collection("dining_halls").get();
    const batch = db.batch();
    hallsSnap.docs.forEach((hallDoc) => {
      const price = hallDoc.get(windowPrices.dinner) as number;
      batch.set(
        db.collection("config").doc("pricing"),
        {
          [hallDoc.id]: {
            breakfast: hallDoc.get(windowPrices.breakfast),
            lunch: hallDoc.get(windowPrices.lunch),
            dinner: price,
          },
        },
        { merge: true }
      );
    });
    await batch.commit();
  });
