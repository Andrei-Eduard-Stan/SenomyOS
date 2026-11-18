# SenomyOS calendar organizer

An optional persistent calendar feature inside the existing Control Centre.
The compact clock popup shares date selection and queries its selected-day agenda independently, with
direct Calendar and Event Briefing actions. Briefing groups only occupied dates
for the next 7, 30 or 90 days, including continuing multi-day events. Its query is
independent of the month/agenda range and runs only while a briefing view is visible. Calendar navigation, event storage and alarm scheduling are separate modules.

## Install and verify

From the authoritative source worktree:

```sh
scripts/senomy-calendar-setup
scripts/senomy-v2-deploy plan
scripts/senomy-v2-deploy apply
systemctl --user enable --now senomy-calendar.service
qs ipc call shell calendarState
```

Setup creates `${XDG_DATA_HOME:-$HOME/.local/share}/senomyos/calendar/runtime`
and installs only hash-locked wheels from `requirements.lock`. System Python is
unchanged. `requirements.txt` lists exact versions; the lock includes all upstream
release artifact hashes so compatible platforms can select their wheel. Reference
validation covers Linux x86_64 / Python 3.14 only. Missing compatible wheels are
an explicit installation failure. For offline installation set `PIP_NO_INDEX=1`
and `PIP_FIND_LINKS` to a trusted wheel directory. Dependencies are feature-specific
and recorded in `deploy/packages.json`; bootstrap does not silently run pip.
The unit skips activation if its private runtime is unavailable. Runtime setup
and credential entry are separate from account synchronization.

### 2 November 2026 reliability publication

Occurrence deletion preserves sibling delivered/snoozed alarms. Relative triggers
apply nominal days in the event timezone, then elapsed hours/minutes/seconds;
display-zone changes do not retime a zoned event's day-based alarm. Existing
schema and alarm keys are unchanged; notified/uncertain alarms are not resent.
The QML client now releases pending requests with an unverified-outcome error
on disconnect, then reconnects without replaying writes.

At publication, the active independent daemon was PID 1560 with its earlier imports.
The separately authorised 2 November closeout activated the reviewed Python in
PID 80263 and verified native Calendar Settings connectivity. One real-clock
reminder delivered exactly once to an isolated receiver across another scheduler
cycle; only its disposable store/event were cleaned. **WP08 core is closed.**
[Actual activation receipt](../../docs/PROJECT_STATE.md).
Future activation remains a separate reviewed operation. Activation is a **separately authorised**
`systemctl --user restart senomy-calendar.service`, after saving/closing calendar
edits, finishing sync and rechecking source hashes and the consistent DB backup.
This does not require restarting Quickshell or Hyprland. No event or reminder was added to the user's live store, and no live remote
provider was contacted; desktop-toast/provider acceptance remains separate. Calendar
preferences do not configure the system timezone or NTP.
[Maintained WP08 ledger and rollback](../../docs/PROJECT_STATE.md).

```sh
scripts/validate-calendar-organizer.py --out /tmp/senomy-calendar-qa
```

The validator uses private XDG state, runtime, D-Bus, an inert notification owner,
local HTTP protocol fixture and native offscreen UI; it never edits live calendars,
contacts external accounts, terminates user processes or changes live notifications.

## Data and actions

Private schema-1 SQLite state is in
`${XDG_STATE_HOME:-$HOME/.local/state}/senomyos/calendar/calendar.sqlite3`.
Canonical ICS retains masters, RECURRENCE-ID exceptions, exclusions and unknown
properties. Optimistic revisions reject stale edits. Save requests are idempotent;
new forms carry a stable UID. Drafts survive renderer/backend restart. The socket
is same-UID and 0600, with an exclusive owner lock and typed operations.

Local calendars support name/color/visibility/read-only policy. Personal is retained
as a fallback. Removing another source deletes only this device's cached events
and leaves the remote collection/credentials unchanged. A private SQLite backup
is taken before source removal or conflict resolution. Delete/transfer/sync reviews
expire after two minutes and reject stale state. Exports are private atomic files,
with changed-destination checks; duplicate import UIDs are skipped, not overwritten.

Daily, weekly, monthly and yearly recurrence is expanded by a maintained library.
The UI edits frequency, interval and count/until; imported advanced rules are
preserved when unchanged. Occurrence edits/deletes keep series identity. Event
zones may be IANA/local/floating. DST gaps are rejected; the second repeated hour
is stored unambiguously for non-repeating events. Repeating events anchored in a
second DST hour require UTC or the first hour. All-day DTEND is exclusive in ICS
and inclusive in the form. Search examines title, location and notes in the visible
range. Timetables use the display zone, 12/24-hour labels and configured work hours.

Event notes are plain text. A dedicated event link is stored as the standard
VEVENT URL property; web links in notes are also exposed as labelled actions.
Only validated HTTP/HTTPS addresses without embedded credentials can be opened,
and only on a user click, through the default browser. Links are never fetched
by the calendar, interpreted as markup or passed through a shell. Imported
unsupported URL properties are retained without a launch action. Up to ten
unique web links are shown. Search includes the event URL; notes/URLs survive
edits, recurrence, draft recovery and ICS export. Long addresses wrap in details.

New events default to a ten-minute reminder. Preferences can change the default
or leave it blank to disable it; each event can override it, and existing events
are not altered. Today's new-event time defaults to an upcoming quarter-hour
at least fifteen minutes ahead, using the configured display zone. Future/past
selected dates retain the 09:00 default. Alarm delivery, not calendar-source
synchronization, is connected to native notifications.

Reminders reconcile every 30 seconds independently of Quickshell visibility;
they use the existing notification server and DND. Snooze, dismissal and uncertain
delivery state persist. Native actions validate unique owner, notification ID,
nonce and current alarm state. No owner means no competing daemon is activated.
Ambiguous delivery is not resent automatically; review it in Reminders. Missed
checks have a rolling seven-day horizon. The service does not wake the machine
or promise notifications after logout. Only DISPLAY alarms are delivered;
unsupported imported alarm actions are retained without execution.

CalDAV uses an explicit HTTPS collection URL and manual reviewed two-way sync.
Passwords are entered via `senomy-calendar-credential ACCOUNT_ID` in a terminal,
then stored/retrieved using `secret-tool`. A functioning user Secret Service is
required. Passwords never enter QML, arguments or SQLite. Plain HTTP is permitted
only for localhost in explicit tests. Remote writes use If-Match/If-None-Match;
conflicting edits remain cached until a reviewed choice. Read-only calendars can
be marked locally; server permissions are authoritative and rejected writes remain
queued. Real providers/accounts have not been integration-tested.

## Limits and remaining work

Queries: 1–93 days, 500 shown occurrences. Grouped agendas render at most
1000 event-day rows and show a limit notice when a shorter range is needed. Imports/resources: 2 MiB, 2000 local series. Dense sub-day recurrence and attachments are rejected. Native floating,
all-day and timezone events are supported; malformed or out-of-range event dates
return errors. Navigation's years 0001–9999 are independent of event-engine
boundary-date constraints. Import/export is a manual file-path flow.

Automatic sync, principal/collection discovery, OAuth, invitations/RSVP, multiple
reminder editing, arbitrary custom recurrence builders, tasks and shared-calendar
permission administration remain future work. No universal cloud/hardware/mobile
support is claimed. Notification archive grouping/search/migration remains a
separate roadmap; calendar integration does not finish that work.

## Recovery

Stop the calendar unit before replacing its state directory. Back up the complete
SQLite directory including WAL/SHM while stopped, or use SQLite's backup API.
Do not lower the schema version to force an unsupported database to open.
Private `backup-*.sqlite3` files are complete SQLite backups made by the engine;
retain the newer database before restoring one. Removing the runtime does not
remove saved events. Source-code publication has a separate scoped recovery
receipt documented in `docs/qa/calendar-organizer-20261011/RESULTS.md`.

## Date actions, notes and bulk additions

In full Calendar, click or press Enter/Space on a date to open its action menu: Add event,
Add note, View this day, Import a list, and existing items in the displayed view.
Notes are dated items with optional titles, plain text and links. They do not
block time or create reminders by default. Events retain their separate notes.
Clear changes the draft; Save applies edits. Delete still requires review.
Date fields have calendar pickers, reminder presets include Off and Custom,
and less common event fields appear under More options. Dirty drafts remain guarded.

Calendar → Import / Bulk Add supports a native file chooser for ICS, CSV and TSV,
or pasting spreadsheet rows. Preview checks every row before saving; malformed
lists write nothing. Confirmation is atomic and refuses a stale calendar revision.
CSV/TSV lists accept at most 200 nonblank rows and 24,000 UTF-8 bytes. Required
headers are `date,title`; dates are YYYY-MM-DD. Optional columns are `start,end`,
`end_date,notes,link,location,reminder,repeat,count,interval,kind`. Times use HH:MM
and both must be provided together. Blank times mean all day. `kind=note` requires
notes and blank times; its title may be blank. Reminder `none` disables reminders;
otherwise events use the default. Repeat accepts DAILY, WEEKLY, MONTHLY or YEARLY.

```csv
date,title,start,end,notes,kind
2026-10-20,Planning,09:00,10:00,Discuss next steps,event
2026-10-21,,,,Remember tickets,note
```

Automation uses the same authenticated local socket and reviewed import protocol:

```sh
senomy-calendar-batch < schedule.csv
senomy-calendar-batch --confirm < schedule.csv
```

The first command only previews; `--confirm` explicitly saves. Identical normalized
rows in the same source retain stable UIDs, so repeated imports skip them, even
if preferences change. Changed rows are new items, not automatic updates. Existing
items are never overwritten. The helper never automatically retries an uncertain
save. Imports into remote calendars are local queued edits until explicit manual
sync; no invitations or background remote writes are introduced.


## Quick-panel composition and verification

The clock popup selects dates directly, keeps the viewed month and focused day
independent of selection, and uses a bounded selected-day agenda. Today comes
from the local minute clock; event times use the configured display zone. Full
Calendar retains notes, advanced date entry, source management and transfer tools.
See `docs/qa/calendar-design-20261024/REVIEW.md` for the audit, actual live render
and physical acceptance limits. Run `python3 scripts/validate-calendar-quick-quality.py`
from the repository root for isolated composition/native compilation and actual
private socket tests. The optional calendar Python runtime must already exist;
`SENOMY_CALENDAR_PYTHON` can select another interpreter with its dependencies.
