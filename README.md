# GeneTrust+ 🚀

**Empowering Everyone to Understand Medical Reports Instantly!**

---

## 🏆 Hackathon Submission: GeneTrust+

### 👩‍⚕️ The Problem
Medical reports are packed with jargon and complexity. Patients and even busy clinicians struggle to quickly grasp the essentials, leading to confusion, anxiety, and missed insights.

### 💡 Our Solution
**GeneTrust+** is a Flutter app that uses Google Gemini AI to instantly summarize any medical report in plain English. No backend, no waiting—just paste, tap, and understand. Built for privacy, speed, and accessibility.

---

## ✨ What Makes GeneTrust+ Stand Out?
- **AI Summaries, Instantly:** Paste or type any medical report, get a clear summary in seconds.
- **Gemini AI On-Device:** All AI logic runs in the app—no server or cloud function needed for AI calls.
- **Modern, Intuitive UI:** Designed for patients, doctors, and researchers alike.
- **Firebase Auth:** Secure sign-in for personalized experience.
- **Sample Report Loader:** Try it out with a single tap!
- **Error Handling & Feedback:** Always know what's happening.

---

## 🎥 Quick Demo
1. **Sign in** (or use guest mode)
2. **Tap the floating action button** on the home screen: "Analyze Report"
3. **Paste or type a medical report**
4. **Tap "Generate Summary"**
5. **See the AI-powered summary instantly!**
6. Or, **tap "Load Sample"** to try a pre-filled example

> _Screenshots and demo video can be found in the `/demo` folder_

---

## 🛠️ Features At a Glance
- Gemini AI-powered medical report summarization
- Clean, responsive Flutter UI
- Firebase authentication
- Riverpod state management
- No backend required for AI
- Sample report loader
- Loading indicators and error messages

---

## 🧑‍💻 Tech Stack
- **Flutter** (UI)
- **Dart** (Logic)
- **Firebase Core & Auth**
- **Google Gemini AI SDK**
- **Riverpod**

---

## 🚀 Try It Yourself (Setup)

1. **Clone the Repo**
   ```sh
   git clone https://github.com/vishnu252005/genetrust.git
   cd genetrust
   ```
2. **Install Dependencies**
   ```sh
   flutter pub get
   ```
3. **Firebase Setup**
   - Add your Firebase project and config files (`google-services.json`/`GoogleService-Info.plist`)
   - Enable Firebase Auth
4. **Gemini AI Setup**
   - Get your API key from [Google AI Studio](https://makersuite.google.com/app/apikey)
   - Paste it in `lib/services/servicegemini.dart`
5. **Run the App**
   ```sh
   flutter run
   ```

---

## 🙌 Thank You, Judges!
GeneTrust+ is about making healthcare more understandable for everyone. We hope you enjoy trying it as much as we enjoyed building it!

---

## 📄 License
[MIT](LICENSE)
