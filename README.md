# SquatMate 🏋️‍♂️

An AI-powered real-time squat coaching companion that analyzes your exercise form. 

SquatMate uses on-device pose detection (MediaPipe via Kotlin Platform Channels) to track body landmarks in real-time, offering instant visual overlays, voice cues, and detailed rep analytics to improve your squat technique and prevent injuries. It includes full user authentication, workout history logging, and a FastAPI + PostgreSQL backend.

---

## 🚀 Tech Stack

### Frontend (Mobile App)
- **Framework:** Flutter (Dart)
- **Native Integration:** Kotlin & Platform Channels (`MethodChannel` & `EventChannel`)
- **Pose Detection Engine:** MediaPipe Pose Landmark Detection
- **Networking:** Dio
- **Local Storage:** SharedPreferences

### Backend (API)
- **Framework:** FastAPI (Python 3.10+)
- **Database:** PostgreSQL
- **Authentication:** JWT (JSON Web Tokens) & bcrypt password hashing
- **Email Service:** SendGrid (for OTP verification)
- **Hosting & Deployment:** Docker & Microsoft Azure VM / Cloud Hosting

---

## ✨ Key Features & Optimizations

- **Real-Time 60 FPS Pose Analysis:** High-frequency landmark rendering via zero-`setState()` `ValueNotifier` listeners and `RepaintBoundary` isolation.
- **Form & Depth Heuristics:** Evaluates squat depth presets (Explosive Power ¼, Athletic Strength ½, Full Strength), knee caving, and forward torso lean.
- **Accurate Fault Tracking:** Deduplicates movement faults per repetition, eliminating frame-rate noise in workout summary JSON metrics.
- **Idle Session Protection:** Automatically prompts the user and auto-ends the session if no movement is detected for an extended period.
- **Audio Feedback:** Real-time audio cues for squat form correction.
- **Secure Authentication:** Email/password login, Google Sign-In, and OTP-based password resets via SendGrid.
- **Workout Analytics & History:** Detailed tracking of reps, fault counts, and knee/hip joint angle statistics.

---

## 📁 Project Directory Structure

```text
Flutter-Kotlin-Real-time-Squat-Exercise-Analysis/
├── android/                                    # Native Android & Kotlin Engine
│   └── app/src/main/kotlin/com/example/flt_kotlin_pose/
│       ├── MainActivity.kt                     # MethodChannel & EventChannel handlers
│       ├── PoseCameraView.kt                   # Native CameraX preview implementation
│       ├── PoseDetector.kt                     # MediaPipe ML pose landmark detector
│       ├── PoseLandmarkEventBus.kt             # Landmark stream event channel bus
│       ├── SquatAudioController.kt             # Audio voice cues controller
│       ├── SquatFeedbackEventBus.kt            # Feedback stream event channel bus
│       ├── SquatHeuristicEngine.kt             # Real-time squat form analysis engine
│       └── SquatModels.kt                      # Kotlin data structures & payloads
│
├── backend/                                    # FastAPI Backend & Database API
│   ├── app/
│   │   ├── core/                               # Security, config, database session
│   │   ├── models/                             # SQLAlchemy database models
│   │   ├── routers/                            # API endpoints (auth, workouts)
│   │   ├── schemas/                            # Pydantic validation schemas
│   │   └── main.py                             # FastAPI application entry point
│   ├── Dockerfile                              # Backend container build specification
│   └── requirements.txt                        # Python dependencies
│
├── lib/                                        # Flutter Mobile App Framework
│   ├── core/
│   │   ├── constants/
│   │   │   └── app_constants.dart              # API base URL & UI spacing constants
│   │   └── utils/
│   │       └── validators.dart                 # Form validation utilities
│   ├── screens/
│   │   ├── auth/
│   │   │   ├── components/
│   │   │   │   └── login_components.dart       # Reusable auth input widgets
│   │   │   ├── forgot_password_screen.dart     # Password recovery flow
│   │   │   ├── loginscreen.dart                # User login screen & Google Auth
│   │   │   ├── reset_password_screen.dart      # OTP password reset screen
│   │   │   └── signup_screen.dart              # User registration screen
│   │   ├── dashboard/
│   │   │   ├── dashboard_screen.dart           # Bottom navigation shell
│   │   │   ├── history_screen.dart             # Workout history & log deletion
│   │   │   ├── home_screen.dart                # Weekly stats chart & quick start
│   │   │   └── profile_screen.dart             # User profile & account details
│   │   └── workout/
│   │       ├── pose_screen.dart                # Real-time camera & pose painter UI
│   │       └── workout_screen.dart             # Workout start card & details summary
│   └── main.dart                               # App entry point & auth gate
│
├── docker-compose.yml                          # PostgreSQL & FastAPI compose stack
├── pubspec.yaml                                # Flutter package dependencies
└── README.md                                   # Project documentation
```

---

## 🛠️ Backend Deployment & Hosting Options

### Option A: Azure Cloud Hosting (Production / Cloud)
The backend service is configured for hosting on **Microsoft Azure** (Azure Virtual Machines / Container Instances) connected to a managed PostgreSQL database.

1. Configure the app's `kApiBaseUrl` in `lib/core/constants/app_constants.dart` to point to the Azure endpoint:
   ```dart
   const String kApiBaseUrl = 'http://<YOUR_AZURE_IP_OR_DOMAIN>:8000';
   ```
2. Interactive Swagger API documentation is available at `http://<YOUR_AZURE_IP_OR_DOMAIN>:8000/docs`.

### Option B: Docker Hosting (Local / Self-Hosted)
Run the backend server and PostgreSQL database locally using Docker Compose:

1. Ensure [Docker](https://www.docker.com/) is installed and running.
2. From the project root directory, launch the services:
   ```bash
   docker compose up -d
   ```
   *The local API will be accessible at `http://localhost:8000` (Docs: `http://localhost:8000/docs`).*

---

## 📱 Frontend Setup (Flutter)

1. Ensure the [Flutter SDK](https://docs.flutter.dev/get-started/install) is installed.
2. In `lib/core/constants/app_constants.dart`, ensure `kApiBaseUrl` matches your active backend (Azure server IP or your local network IP if testing via physical device).
3. Fetch dependencies:
   ```bash
   flutter pub get
   ```
4. Run the app on an Android device or emulator:
   ```bash
   flutter run
   ```

---

## 🛑 Managing Local Docker Backend

To stop local Docker containers without losing database data:
```bash
docker compose stop
```

To destroy containers and reset the local database volume:
```bash
docker compose down -v
```
