# Livestock Tracker — Offline GPS-LoRa Geofencing App for Himalayan Pastures

A mobile application for real-time, offline monitoring and virtual fencing of free-grazing livestock in remote Himalayan terrain, built as the mobile-side component of a LoRa-based livestock tracking collar system.

---

## Introduction

In the high-altitude pastures of Nepal, livestock such as yak, cattle, and sheep are often left to graze freely across vast, rugged terrain with no cellular coverage and no fencing infrastructure. Herders traditionally rely on physical presence, memory of terrain, and occasional visual sighting to keep track of their animals — a method that is time-consuming, error-prone, and increasingly difficult as grazing areas expand and herding labor becomes scarce.

This project addresses that gap with a low-cost, fully offline tracking and virtual geofencing system. GPS-equipped collars transmit location data over long-range LoRa radio to a local base station, which in turn serves that data to a mobile application. The application displays live animal positions on a locally cached (offline) map, allows herders to define virtual boundaries, and issues alerts the moment an animal strays outside the defined safe zone — all without requiring internet connectivity or cloud infrastructure at any point in the pipeline.

---

## Motivation & Problem Statement

Existing commercial livestock trackers (e.g., cellular or satellite-based ear tags and collars) are largely unsuitable for Himalayan pastoral contexts for three reasons:

1. **No connectivity** — cellular and satellite-dependent systems fail outright in regions with no network coverage, which describes most high-altitude grazing land in Nepal.
2. **Cost** — commercial trackers and their recurring data-plan or satellite-airtime costs are economically infeasible for smallholder herders.
3. **Cloud dependency** — most existing solutions assume a live internet connection to a remote server for both data storage and the geofencing logic itself, which breaks down completely in a no-connectivity environment.

The research gap this project targets is the absence of an **affordable, fully offline, locally-computed geofencing system** designed specifically for terrain-constrained, connectivity-poor pastoral environments — where all computation (position tracking, boundary checking, alerting) must happen at the edge, on inexpensive hardware, without ever touching a server.

---

## Objectives

- Track the live location of multiple livestock collars on a mobile device, entirely offline.
- Allow a user to define and edit custom geofence boundaries directly on the app.
- Detect and alert when an animal exits a defined boundary, using only local computation.
- Maintain a local history of animal movement for later review.
- Report collar device health (battery, signal strength) to help with maintenance.
- Operate the entire pipeline — collar to base station to phone — without internet or cloud services at any stage.

---

## System Architecture

```
┌──────────────┐     LoRa      ┌───────────────────┐     WiFi      ┌─────────────────┐
│  GPS Collar   │ ────────────▶ │  ESP32 Base        │ ────────────▶ │  Mobile App      │
│  (NEO-6M/M8N  │   long-range, │  Station            │  local AP,    │  (Flutter,       │
│   + SX1276/78)│   low-power   │  (SX1276/78 + WiFi) │  no internet  │   offline-first) │
└──────────────┘               └───────────────────┘               └─────────────────┘
```

- **Collar unit:** GPS module (NEO-6M or NEO-M8N) reads position; an SX1276/78 LoRa radio transmits it periodically to the base station.
- **Base station:** An ESP32 receives LoRa packets from all collars in range, aggregates them, and exposes the latest readings as JSON over its own local WiFi access point — no router or internet uplink required.
- **Mobile app:** Connects to the base station's WiFi AP directly, polls for updated collar data, renders positions on an offline map, and runs all geofence logic locally on-device.

---

## Methodology / Core Algorithms

**Position acquisition:** Each collar's GPS module resolves latitude/longitude at a fixed interval and transmits it via LoRa, chosen over WiFi/Bluetooth/cellular for its multi-kilometer range at very low power draw — critical for a battery-powered collar expected to run unattended for extended periods.

**Geofence boundary check — Point-in-Polygon:** A geofence is defined as a set of GPS coordinate vertices forming a closed polygon. For each incoming collar position, the app determines whether the point lies inside or outside this polygon using a standard ray-casting algorithm: a horizontal ray is cast from the point, and the number of times it crosses the polygon's edges is counted — an odd count means the point is inside, an even count means outside.

**Distance/proximity calculation — Haversine formula:** For simplified circular geofences and for estimating how far an animal has strayed from a boundary, the great-circle distance between two GPS coordinates is computed using the Haversine formula, which accounts for the Earth's curvature and is accurate at the short distances relevant to pasture-scale monitoring.

**Alerting:** The moment a position update places a collar outside its assigned geofence, the app triggers a local notification and logs an alert record — no server round-trip involved, so the alert fires the instant the app receives the data.

---

## Workflow (Data Flow)

1. Collar acquires GPS fix → packages `{id, lat, lon, battery, timestamp}` → transmits via LoRa.
2. ESP32 base station receives the LoRa packet, updates its in-memory table of latest collar readings.
3. Mobile app polls the base station's local HTTP endpoint every few seconds.
4. App parses the JSON response, updates on-screen markers on the offline map.
5. App runs the point-in-polygon / haversine check against the active geofence(s).
6. If a violation is detected, an alert is raised and stored locally.
7. All readings are logged to a local database for later movement-history review — no data ever leaves the device.

---

## Tech Stack

| Component | Choice | Why |
|---|---|---|
| Mobile framework | Flutter (Dart) | Single codebase, strong offline-map ecosystem, no cost |
| Offline maps | `flutter_map` + OpenStreetMap tiles (pre-downloaded MBTiles) | Open-source, no API key, works fully offline once cached |
| State management | Riverpod | Predictable data flow for live-updating map markers |
| Local storage | `sqflite` (SQLite) | Lightweight, no server, reliable on-device persistence |
| Base-station comms | HTTP over local WiFi AP | No internet dependency, simple to implement on ESP32 |
| Base station | ESP32 | Low-cost, WiFi + sufficient processing for LoRa packet aggregation |
| LoRa radio | SX1276 / SX1278 | Long range, low power, license-free ISM band |
| GPS module | NEO-6M / NEO-M8N | Low-cost, adequate accuracy for pasture-scale geofencing |

---

## Setup Guide

### Prerequisites
- Flutter SDK (stable channel)
- A Linux, macOS, or Windows development machine
- Android SDK (only required for building/testing the final Android APK — not needed for early development)

### Installation
```bash
git clone <repository-url>
cd livestock_tracker
flutter pub get
```

### Running (development)
```bash
flutter run -d chrome     # fastest iteration for UI/logic (no SQLite support)
flutter run -d linux      # required for any feature using local storage (sqflite)
```

### Building for Android
```bash
flutter build apk --release
```
Requires Android Studio/SDK installed on the build machine. The generated APK is fully portable and can be installed on any Android device without further setup.

### Offline map data
Map tiles for the target pasture region must be downloaded once, while internet access is available, and bundled into the app's assets before field deployment. See `/tools/download_mbtiles.py` for the tile-fetching script.

---

## Future Scope

- Peer-to-peer mesh networking between collars (delay-tolerant networking) to remove reliance on a single base station and extend effective coverage across larger, more fragmented terrain.
- Solar-assisted charging for extended unattended collar deployment.
- Multi-herd, multi-geofence management for larger operations.