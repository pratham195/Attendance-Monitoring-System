# 📱 Attendance Monitoring System

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat&logo=flutter&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=flat&logo=firebase&logoColor=black)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=flat&logo=dart&logoColor=white)

A cross-platform mobile application built with **Flutter** and **Firebase** as a college project for the course **- Cross Platform Mobile App Development**.

> 🎓 **GLS University — Faculty of Computer Applications & IT**
> iMSc.IT Programme | Semester VIII

---

## About

This project was built to learn Flutter and Firebase during Semester VIII of the iMSc.IT programme. It is an attendance management system for educational institutions that replaces manual attendance methods with a mobile-based digital system.

> **Note:** This repository contains only the source code (`lib/`). Configuration files, build outputs, and platform-specific files are not included. You will need to set up your own Firebase project to run this application.

---

## Features

| Role | Capabilities |
|------|-------------|
| 🎓 Student | View subject-wise attendance, session history, and attendance percentage |
| 👨‍🏫 Faculty | Mark attendance, manage subjects, view attendance history |
| 🔧 Admin | Manage students, faculty, and subjects across the system |
| ☁️ Firebase | Real-time data sync, authentication, and cloud storage |

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| Frontend | Flutter (Dart) |
| Backend | Firebase Firestore |
| Auth | Firebase Authentication |
| Storage | Cloud Firestore |

---

## Setup Instructions

1. **Clone the repo**
   ```bash
   git clone https://github.com/pratham195/Attendance-Monitoring-System.git
   cd Attendance-Monitoring-System
   ```

2. **Set up a Flutter project** and copy the `lib/` folder into it

3. **Install dependencies** — add these to your `pubspec.yaml`:
   ```yaml
   dependencies:
     flutter:
       sdk: flutter
     firebase_core: latest
     firebase_auth: latest
     cloud_firestore: latest
   ```
   Then run:
   ```bash
   flutter pub get
   ```

4. **Set up Firebase**
   - Create a project at [Firebase Console](https://console.firebase.google.com)
   - Add an Android app and download `google-services.json` → place in `android/app/`
   - Add your Firebase credentials in `main.dart`

5. **Run the app**
   ```bash
   flutter run
   ```

---

## Project Structure

```
lib/
├── main.dart
├── pages/
│   ├── login_page.dart
│   ├── admin_page.dart
│   ├── dashboard_page.dart
│   ├── faculty_home_page.dart
│   ├── faculty_registration_page.dart
│   ├── create_subject_page.dart
│   ├── mark_attendance_page.dart
│   ├── student_attendance_page.dart
│   └── edit_profile_page.dart
└── widgets/
    └── app_drawer.dart
```

---
