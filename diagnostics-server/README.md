# eScive diagnostic collector

This service accepts diagnostic events. It cannot send commands to the scooter.

## Deployment

Deploy this directory to Railway. Mount a persistent volume at `/data`.
Set distinct random `UPLOAD_TOKEN` and `READ_TOKEN` values of at least 32 characters.
Use Railway's HTTPS domain. The health endpoint is `/health`.
Never commit tokens or include the read token in the phone app.

Build the phone app with `--dart-define-from-file` pointing to a private JSON file:

```json
{
  "DIAGNOSTICS_URL": "https://YOUR-DOMAIN/events",
  "DIAGNOSTICS_TOKEN": "UPLOAD-TOKEN"
}
```

Only a configured diagnostic build uploads automatically while the app runs.
Normal builds do not upload. The dashboard layout and Bluetooth commands stay unchanged.
The upload token is recoverable from a distributed IPA; treat it as upload-only and rotate it after testing.

## Evidence

The app records a random session ID, UTC time, connection state, outgoing Bluetooth bytes,
all received Bluetooth bytes, all decoded scooter telemetry, write failures, and parking request/result events.
Telemetry includes electronic lock, brake lock, Bluetooth binding, speed, gears, and firmware version bytes.
From 1.2.5, it also includes the saved scooter name, Bluetooth address, and protocol.
The user authorizes expanded scooter logging. It does not collect unrelated account credentials or GPS.
A result confirms reported state only. The user must still report physical P and immobilization.

Uploads run every five seconds, in batches of up to 100 events.
The in-memory queue holds up to 500 events. An eight-second network timeout never blocks Bluetooth.
The queue can lose older events during a long outage and is lost when the app terminates.
Retries can duplicate a batch if the server accepts it but the reply is lost.
Match session, time, kind, and data when interpreting duplicate events.

The collector retains up to 20,000 events, for up to seven days.
Cleanup runs during uploads and reads. Expired rows are never returned.
SQLite lives on the Railway volume. Multiple service replicas are not supported.

## Retrieval

`GET /events` with `Authorization: Bearer <READ_TOKEN>` returns the latest 1,000 events.
`POST /events` requires the separate upload token.
Keep credentials in private local configuration or a secret manager, not command output.
Server request logging is disabled to avoid exposing event bodies or credentials.

## Validation

Run `python3 -m unittest discover -s diagnostics-server` from the repository root.
Run `flutter test test/scooter_diagnostics_test.dart` for upload retries, queue limits, and disabled builds.
These tests use synthetic data. They do not prove scooter behavior.

## Current deployment

Project: `05da55b6-4e32-4184-b8c0-6bbad3edd29c` (user account).
Service: `04a92b37-2992-4cfd-97aa-f56579e0b31b` (`escive-diagnostics`).
Endpoint: `https://escive-diagnostics-production.up.railway.app/events`.
Volume: `82365545-2ec9-4d14-aa8a-12716a4d3a3e`, mounted at `/data`.
Private local credentials and build settings live in the ignored `.diagnostics` directory, with restricted file permissions.
Run `python3 diagnostics-server/read_events.py` to retrieve recent events during follow-up work.
This prints diagnostic data but never the access credentials.

The live test uses the actual Dart uploader against Railway with synthetic data.
It confirms that upload credentials cannot read events and anonymous reads fail.
Use `test/diagnostics_live_test.dart` with the private build defines and the read token supplied through the environment.
The ordinary test suite skips this external test.
