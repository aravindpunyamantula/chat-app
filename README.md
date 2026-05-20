# Real-Time Chat App 

A production-ready, full-stack real-time chat application modeled after WhatsApp and Telegram. The frontend is built using **Flutter (Material 3)**, and the backend is powered by **Node.js, Express, Socket.IO, and MongoDB**.

## 🚀 Core Features

- **Offline-First Architecture**: Drift SQLite handles local storage. All chat UI acts reactively to local database changes, avoiding all UI blocking entirely. Background synchronization and a robust pending-message queue ensure that you never lose data when offline.
- **Real-Time Websockets**: Instant messaging, typing indicators, and delivery/read receipts via Socket.IO.
- **Premium Material 3 UI**: Polished dynamic status indicators, sliding connection warning banners, comprehensive empty states, and smooth staggered entry animations. 
- **Message Parsing & Replies**: Supports blockquote parsing for robust in-thread reply UI rendering.

---

## 🏗️ System Architecture

### Frontend (Flutter)
- **Local Database Layer**: Drift (SQLite for Android, sql.js WASM for Web).
- **State Management Layer**: Provider handling reactive subscription streams from Drift DAOs.
- **Network Layer**: Dio for HTTP background synchronization and Socket.IO for event bus.

### Backend (Node.js)
- **Database**: MongoDB (Mongoose ORM).
- **Security**: Helmet, custom XSS middleware, CORS configurations, JWT authentication.
- **WebSockets**: Socket.IO integrated with JWT authentication middleware for real-time presence, dispatch, and message state.

---

## 🛠️ Installation & Setup

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.11.4+)
- [Node.js](https://nodejs.org/) (v18+)
- [MongoDB URI](https://www.mongodb.com/) (Local or Atlas)

### 1. Backend Setup
Navigate to the `backend` directory:
```bash
cd backend
npm install
```
Configure your `.env` file (create one based on `.env.example` if it exists):
```env
PORT=5000
MONGODB_URI=mongodb+srv://<user>:<password>@cluster.mongodb.net/chat
JWT_SECRET=your_super_secret_key
NODE_ENV=development
```
Start the server:
```bash
npm run start
```
*The server runs on http://localhost:5000 by default.*

### 2. Frontend Setup
Navigate to the `frontend` directory:
```bash
cd frontend
flutter pub get
```

#### Drift Code Generation
Because this project utilizes Drift, you must generate the data class accessors and DAOs:
```bash
dart run build_runner build --delete-conflicting-outputs
```

---

## 🏃 Running the Application

### Android
Connect your emulator or physical device:
```bash
flutter run -d android
```

### Flutter Web
The Drift setup utilizes WASM to provide a full SQL environment directly inside Chrome:
```bash
flutter run -d chrome
```

---

## 📚 Codebase Overview

### Offline-First Lifecycle
1. App boots and opens the Drift `AppDatabase`.
2. UI binds to Drift reactive streams via `ChatProvider` & `watchMessages`.
3. Background `SyncManager` securely fetches new changes and commits to Drift, UI automatically rebuilds to match. 
4. Outbound messages save locally as `pending`, queue via `PendingQueueService`, execute over Socket.IO, and update status seamlessly to `sent`/`delivered`. 

### Key Files
- `lib/data/local/app_database.dart`: SQLite config and tables.
- `lib/providers/chat_provider.dart`: Re-architected reactive layer driving UI.
- `lib/core/services/sync_manager.dart`: Background engine writing to Drift.
- `lib/core/services/pending_queue_service.dart`: The offline retry-loop engine.
