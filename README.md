# SquatMate 🏋️‍♂️

An AI-powered real-time squat coaching companion that analyzes your exercise form. 

SquatMate uses on-device pose detection to track your movements in real-time, providing feedback to improve your squat form and prevent injuries. It features a complete user authentication system backed by a robust FastAPI and PostgreSQL server.

## 🚀 Tech Stack

**Frontend (Mobile App)**
- **Framework:** Flutter (Dart)
- **Pose Detection:** ML Kit / Kotlin (via Platform Channels)
- **Networking:** Dio
- **State Management / Local Storage:** SharedPreferences

**Backend (API)**
- **Framework:** FastAPI (Python)
- **Database:** PostgreSQL
- **Authentication:** JWT (JSON Web Tokens) & bcrypt password hashing
- **Email Service:** SendGrid (for OTP verification)
- **Deployment:** Docker & Docker Compose

---

## ✨ Key Features
- **Real-time Pose Analysis:** Detects body joints and analyzes squat depth and posture.
- **Secure Authentication:** Sign up, log in, and forgot password flows with OTP email verification.
- **Session Management:** Securely stores JWT tokens for persistent logins.
- **Modern UI/UX:** Clean, intuitive, and responsive design with micro-animations and password strength indicators.

---

## 📁 Project Architecture (Flutter)

The `lib/` directory is organized feature-by-feature for scalability:
```text
lib/
├── core/            # Global utilities, validators, and constants (app_constants.dart)
├── screens/         # UI feature modules
│   ├── auth/        # Login, Signup, Password reset flows & widgets
│   ├── dashboard/   # Main user dashboard and workout history
│   └── workout/     # Native camera feed and ML pose analysis screens
└── main.dart        # Application entry point and auth-gate routing
```

---

## 🛠️ Getting Started

To run this project locally, you will need to start both the backend API and the Flutter application.

### 1. Backend Setup (Docker)
The easiest way to run the backend is using Docker Compose, which sets up both the FastAPI server and the PostgreSQL database.

1. Ensure you have [Docker](https://www.docker.com/) installed and running.
2. Navigate to the root directory of the project.
3. Start the backend services in the background:
   ```bash
   docker compose up -d
   ```
   *The API will be accessible at `http://localhost:8000`.*
   *You can view the interactive API documentation at `http://localhost:8000/docs`.*

### 2. Frontend Setup (Flutter)
1. Ensure you have the [Flutter SDK](https://docs.flutter.dev/get-started/install) installed.
2. In the `lib/core/constants/app_constants.dart` file, update the `kApiBaseUrl` to match your computer's local IP address so the physical device/emulator can connect to the backend (e.g., `http://192.168.1.100:8000`).
3. Install Flutter dependencies:
   ```bash
   flutter pub get
   ```
4. Run the app on an emulator or physical device:
   ```bash
   flutter run
   ```

---

## 🛑 Stopping the Backend
To stop the backend services without losing your database data:
```bash
docker compose stop
```
If you want to completely destroy the containers and reset the database volume:
```bash
docker compose down -v
```
