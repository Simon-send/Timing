# Registration choices

Email registration and new Google accounts record three separate choices through
Rundeanalyse's private europe-west1 consent callables: required acknowledgement
of the privacy notice, optional cloud activity/health processing, and optional
marketing email. Optional choices start unchecked. Ordinary login has no boxes.
Existing Google accounts without an unfinished-registration marker log in as
before. Mine sider allows changing optional preferences; withdrawing cloud consent
requires confirmation because it erases cloud activities/groups across the two
apps. Marketing withdrawal does not erase activities.

Deploy the paired Rundeanalyse backend before publishing this client. Canonical
wording/version is in Rundeanalyse's saved-functions/consent-texts.json; do not
change displayed purpose wording without updating both clients and the backend.
Receipts are own-UID, revision checked and private. Interrupted registration keeps
an own-UID browser/server marker; a lost response is recovered by loading the
completed receipt before showing fresh editable choices. No mailing sender/export
or production deployment is included.

Validated locally: formatting, analyzer, all 355 Flutter tests and release web
build. UI tests include new/existing Google accounts, pending recovery, optional
false defaults, revision/account changes and a 320px profile view. Screenshots use
synthetic users. Real OAuth accounts and live data were not used for these checks.
