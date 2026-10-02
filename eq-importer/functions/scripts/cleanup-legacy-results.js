const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");

initializeApp();
const db = getFirestore();

/**
 * Remove v2 child collections after checking that v3 data exists.
 * @param {string} eventId EQ Timing event id.
 */
async function cleanupEvent(eventId) {
  const eventRef = db.collection("events").doc(String(eventId));
  const [eventSnapshot, classSnapshot, stageSnapshot] = await Promise.all([
    eventRef.get(),
    eventRef.collection("classes").get(),
    eventRef.collection("stages").get(),
  ]);
  if (!eventSnapshot.exists || eventSnapshot.get("schemaVersion") !== 3) {
    throw new Error(`Event ${eventId} is not schema version 3`);
  }
  if (stageSnapshot.empty) {
    throw new Error(`Event ${eventId} has no stages`);
  }

  for (const classDocument of classSnapshot.docs) {
    const stageClassSnapshots = await Promise.all(
        stageSnapshot.docs.map((stage) =>
          stage.ref.collection("classes").doc(classDocument.id).get()),
    );
    if (!stageClassSnapshots.some((snapshot) => snapshot.exists)) {
      throw new Error(
          `Refusing to clean class ${classDocument.id}: no v3 stage class`,
      );
    }
  }

  for (const classDocument of classSnapshot.docs) {
    await db.recursiveDelete(classDocument.ref.collection("results"));
    await db.recursiveDelete(classDocument.ref.collection("splitDefs"));
  }
  console.log(`Cleaned legacy result data for event ${eventId}`);
}

/** CLI entry point. */
async function main() {
  const eventIds = process.argv.slice(2);
  if (!eventIds.length) throw new Error("Pass at least one event id");
  for (const eventId of eventIds) await cleanupEvent(eventId);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
