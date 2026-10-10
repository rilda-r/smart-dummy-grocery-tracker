import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

export const deleteUserData = functions.https.onCall(async (_, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "User must be authenticated to delete account");
  }

  const uid = context.auth.uid;
  const db = admin.firestore();
  const bucket = admin.storage().bucket();

  // 1. Fetch all groups where user is a member
  const groupsSnapshot = await db.collection("groups").where("memberIds", "array-contains", uid).get();

  for (const groupDoc of groupsSnapshot.docs) {
    const groupId = groupDoc.id;
    const groupData = groupDoc.data();
    const isOwner = groupData.ownerId === uid;
    const memberIds: string[] = groupData.memberIds || [];
    const remainingMembers = memberIds.filter((id) => id !== uid);

    if (isOwner) {
      if (remainingMembers.length === 0) {
        // Sole owner: delete group, subcollections, and group storage
        const batch = db.batch();

        // Delete members subcollection
        const membersSnap = await groupDoc.ref.collection("members").get();
        membersSnap.forEach((doc) => batch.delete(doc.ref));

        // Delete lists and items
        const listsSnap = await groupDoc.ref.collection("lists").get();
        for (const listDoc of listsSnap.docs) {
          const itemsSnap = await listDoc.ref.collection("items").get();
          itemsSnap.forEach((item) => batch.delete(item.ref));
          batch.delete(listDoc.ref);
        }

        // Delete expenses
        const expensesSnap = await groupDoc.ref.collection("expenses").get();
        expensesSnap.forEach((doc) => batch.delete(doc.ref));

        // Delete activity
        const activitySnap = await groupDoc.ref.collection("activity").get();
        activitySnap.forEach((doc) => batch.delete(doc.ref));

        // Delete group doc itself
        batch.delete(groupDoc.ref);
        await batch.commit();

        // Delete receipts in Storage for this group
        try {
          await bucket.deleteFiles({ prefix: `receipts/${groupId}/` });
        } catch (e) {
          console.warn(`Error deleting storage prefix receipts/${groupId}:`, e);
        }
      } else {
        // Ownership transfer: transfer to next oldest member
        const newOwnerId = remainingMembers[0];
        await groupDoc.ref.update({
          ownerId: newOwnerId,
          memberIds: admin.firestore.FieldValue.arrayRemove(uid),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        await groupDoc.ref.collection("members").doc(newOwnerId).update({ role: "owner" });
        await groupDoc.ref.collection("members").doc(uid).delete();
      }
    } else {
      // Regular member: remove from group
      await groupDoc.ref.update({
        memberIds: admin.firestore.FieldValue.arrayRemove(uid),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      await groupDoc.ref.collection("members").doc(uid).delete();
    }
  }

  // 2. Delete user's personal receipts across storage
  try {
    const [files] = await bucket.getFiles({ prefix: `receipts/` });
    const userFiles = files.filter((file) => file.name.includes(`/${uid}/`));
    await Promise.all(userFiles.map((f) => f.delete()));
  } catch (e) {
    console.warn("Storage deletion error:", e);
  }

  // 3. Delete user document from users/{uid}
  await db.collection("users").doc(uid).delete();

  // 4. Delete Firebase Auth user
  await admin.auth().deleteUser(uid);

  return { success: true };
});
