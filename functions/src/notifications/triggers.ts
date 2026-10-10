import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

export const onItemAddedOrAssigned = functions.firestore
  .document("groups/{groupId}/lists/{listId}/items/{itemId}")
  .onWrite(async (change, context) => {
    const groupId = context.params.groupId;
    const db = admin.firestore();

    if (!change.after.exists) {
      // Item was deleted
      return;
    }

    const newData = change.after.data()!;
    const oldData = change.before.exists ? change.before.data()! : null;

    // Check if new assignment occurred
    if (newData.assignedTo && (!oldData || oldData.assignedTo !== newData.assignedTo)) {
      const assignedToUid = newData.assignedTo;
      const userDoc = await db.collection("users").doc(assignedToUid).get();
      const fcmTokens: string[] = userDoc.exists ? userDoc.data()?.fcmTokens || [] : [];

      if (fcmTokens.length > 0) {
        await admin.messaging().sendEachForMulticast({
          tokens: fcmTokens,
          notification: {
            title: "New Item Assigned",
            body: `You've been assigned: ${newData.name} (${newData.quantity} ${newData.unit})`,
          },
          data: {
            groupId,
            itemId: context.params.itemId,
            type: "item_assigned",
          },
        });
      }

      // Add to activity audit log
      await db.collection("groups").doc(groupId).collection("activity").add({
        type: "item_assigned",
        actorId: newData.addedBy || "system",
        summary: `Assigned "${newData.name}" to member`,
        targetId: context.params.itemId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else if (!oldData) {
      // Item was newly added
      await db.collection("groups").doc(groupId).collection("activity").add({
        type: "item_added",
        actorId: newData.addedBy || "system",
        summary: `Added "${newData.name}" to grocery list`,
        targetId: context.params.itemId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });

export const onExpenseCreated = functions.firestore
  .document("groups/{groupId}/expenses/{expenseId}")
  .onCreate(async (snap, context) => {
    const groupId = context.params.groupId;
    const expenseData = snap.data();
    const paidBy = expenseData.paidBy;
    const splits: Record<string, number> = expenseData.splits || {};
    const db = admin.firestore();

    // Get list of participant UIDs (excluding payer)
    const participantUids = Object.keys(splits).filter((uid) => uid !== paidBy);

    // Fetch tokens for participants
    const tokens: string[] = [];
    for (const uid of participantUids) {
      const userDoc = await db.collection("users").doc(uid).get();
      if (userDoc.exists && userDoc.data()?.fcmTokens) {
        tokens.push(...(userDoc.data()!.fcmTokens as string[]));
      }
    }

    if (tokens.length > 0) {
      await admin.messaging().sendEachForMulticast({
        tokens,
        notification: {
          title: "New Group Expense",
          body: `${expenseData.description || "An expense"} of $${expenseData.total.toFixed(2)} was recorded.`,
        },
        data: {
          groupId,
          expenseId: context.params.expenseId,
          type: "expense_created",
        },
      });
    }

    // Add activity log
    await db.collection("groups").doc(groupId).collection("activity").add({
      type: "expense_created",
      actorId: paidBy,
      summary: `Recorded expense "${expenseData.description || "Groceries"}" ($${expenseData.total.toFixed(2)})`,
      targetId: context.params.expenseId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
