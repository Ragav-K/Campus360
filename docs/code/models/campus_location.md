# lib/models/campus_location.dart

## Purpose
Models a point of interest on campus (building, department, canteen, etc.) with optional coordinates and weekly opening hours.

## Key members
- `OpenHours` class — one weekday's open/close window (`day` 1-7, `open`/`close` as "HH:mm" strings); `fromMap`/`toMap`; `containsTime(DateTime)` handles midnight-crossing windows.
- `CampusLocation` class — fields `id`, `name`, `category` (`LocationCategory`), `building`, `floor`, `roomCode`, `description`, `lat`/`lng`, `openHours`, `isActive`.
- `hasCoordinates`, `subtitle` (building/floor/room joined for list rows), `isOpenAt(DateTime)` (nullable — null means hours unknown), `matches(String query)` free-text search.

## Dependencies & relationships
Imports `enums/location_enums.dart` (`LocationCategory`). Maps to the `campusLocations/{id}` Firestore collection. Consumed by the Map feature (markers, list, detail header) and likely by location pickers in Lost & Found/Pulse. No `fromMap`/`toMap` on `CampusLocation` itself — Firestore mapping presumably lives in a repository/DTO.

## Notable behavior / gotchas
`isOpenAt` returns `null` (not false) when no hours are recorded, so the UI must distinguish "hours not listed" from "closed" rather than assuming closed. `OpenHours.containsTime` supports overnight windows where close < open.
