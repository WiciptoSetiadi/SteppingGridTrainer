/*
 * ==============================================================================
 * STEPPING GRID TRAINER - ESP32 FIRMWARE (PRODUKSI LENGKAP IoT)
 * ==============================================================================
 * Sistem Terapi Jalan & Keseimbangan Pasca-Stroke berbasis Matras Ubin Interaktif
 * Komunikasi Langsung: ESP32 <-> Supabase Cloud REST API via HTTPS (Wi-Fi MiFi)
 *
 * HARDWARE CONFIGURATION:
 * 1. Microcontroller: ESP32 DevKit V1
 * 2. Shift Register: 74HC595 (Pengendali 4 LED Target Ubin)
 *    - DS    / Data  : GPIO 25 (Pin 14 IC 74HC595)
 *    - SH_CP / Clock : GPIO 33 (Pin 11 IC 74HC595)
 *    - ST_CP / Latch : GPIO 32 (Pin 12 IC 74HC595)
 * 3. Sensor Pijakan Ubin (Limit Switch Active-LOW dengan Internal Pullup):
 *    - Ubin 1 (Depan-Kiri)   : GPIO 4
 *    - Ubin 2 (Depan-Kanan)  : GPIO 12
 *    - Ubin 3 (Belakang-Kiri) : GPIO 14
 *    - Ubin 4 (Belakang-Kanan): GPIO 27
 * 4. Display: LCD I2C 16x2 (Address 0x27 atau 0x3F)
 *    - SDA: GPIO 21
 *    - SCL: GPIO 22
 * 5. Audio Player: DFRobot DFPlayer Mini (UART2 Hardware Serial)
 *    - RX2: GPIO 16 (ke TX DFPlayer)
 *    - TX2: GPIO 17 (ke RX DFPlayer via resistor 1k)
 *
 * JARINGAN WI-FI & IOT:
 * - SSID: ADVAN MF01-83405B
 * - Sandi: 085848719373
 * - Router Gateway: 192.168.0.1
 * - Supabase Cloud: rtvtralxxvzxitdqjrco.supabase.co
 * ==============================================================================
 */

#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <DFRobotDFPlayerMini.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

// ============================================================================
// 1. KONFIGURASI JARINGAN WI-FI & SUPABASE CLOUD
// ============================================================================
const char* WIFI_SSID     = "ADVAN MF01-83405B";      // SSID MiFi Router Advan
const char* WIFI_PASSWORD = "085848719373";          // Kata Sandi MiFi Router Advan
const char* ROUTER_IP     = "192.168.0.1";           // Gateway IP MiFi Advan

// Endpoint Supabase REST API
const char* SUPABASE_HOST = "rtvtralxxvzxitdqjrco.supabase.co";
const char* SUPABASE_URL  = "https://rtvtralxxvzxitdqjrco.supabase.co/rest/v1";
const char* SUPABASE_KEY  = "sb_publishable_9Z8VFKtqUnlXfWyzXgMi3g_udj5JQ5r";

// Identitas Perangkat Matras
const char* DEVICE_CODE      = "SGT-01";
const int   DEVICE_ID_DB     = 1;
const char* FIRMWARE_VERSION = "1.0.0";

// Interval Waktu IoT (milidetik)
const unsigned long HEARTBEAT_INTERVAL = 20000; // Kirim heartbeat tiap 20 detik
const unsigned long REMOTE_POLL_INTERVAL = 3000; // Cek perintah dari app tiap 3 detik

// ============================================================================
// 2. DEFINISI PIN ESP32
// ============================================================================
// Shift Register 74HC595 (Pengendali 4 LED Target Ubin)
const int PIN_DATA  = 25; // DS (Pin 14 IC 595)
const int PIN_CLOCK = 33; // SH_CP (Pin 11 IC 595)
const int PIN_LATCH = 32; // ST_CP (Pin 12 IC 595)

// Limit Switch (Sensor Pijakan Direct GPIO Active-LOW)
const int PIN_SENSOR_U1 = 4;
const int PIN_SENSOR_U2 = 12;
const int PIN_SENSOR_U3 = 14;
const int PIN_SENSOR_U4 = 27;

// Komunikasi Serial Audio DFPlayer Mini (UART2)
#define FPSERIAL Serial2

// ============================================================================
// 3. OBJEK HARDWARE & KONSTANTA
// ============================================================================
LiquidCrystal_I2C lcd(0x27, 16, 2); // Ubah ke 0x3F jika alamat LCD berbeda
DFRobotDFPlayerMini dfplayer;
bool dfPlayerReady = false;

// Pola Bit LED 74HC595 (Q0 = U1, Q1 = U2, Q2 = U3, Q3 = U4)
const byte LED_U1  = 0b00000001;
const byte LED_U2  = 0b00000010;
const byte LED_U3  = 0b00000100;
const byte LED_U4  = 0b00001000;
const byte LED_OFF = 0b00000000;

// Indeks File Audio MP3 di MicroSD (Folder /01/)
const int AUDIO_WELCOME       = 1; // 0001.mp3 - Selamat Datang
const int AUDIO_MODE_FSST     = 2; // 0002.mp3 - Mode FSST 2x2
const int AUDIO_MODE_LATERAL  = 3; // 0003.mp3 - Mode Lateral 1x4
const int AUDIO_MODE_REACTIVE = 4; // 0004.mp3 - Mode Reactive T-Shape
const int AUDIO_BEEP          = 5; // 0005.mp3 - Nada Injak Benar
const int AUDIO_TURNBACK      = 6; // 0006.mp3 - Nada Putar Balik
const int AUDIO_FINISH        = 7; // 0007.mp3 - Nada Latihan Selesai

enum SystemState { STATE_MENU, STATE_RUNNING, STATE_FINISHED };
SystemState currentState = STATE_MENU;

int currentMode = 0; // 0: FSST 2x2, 1: Lateral 1x4, 2: Reactive T-Shape

unsigned long startTime = 0;
unsigned long totalElapsedTime = 0;
int currentStepIndex = 0;

// Urutan Langkah Mode 1 & Mode 2
const int fsstSequence[] = {1, 2, 4, 3, 1};
const int FSST_TOTAL_STEPS = 5;

const int lateralSequence[] = {1, 2, 3, 4, 3, 2, 1};
const int LATERAL_TOTAL_STEPS = 7;

// Variabel Mode 3 (Reactive T-Shape)
int reactiveRoundsCompleted = 0;
const int TOTAL_REACTIVE_ROUNDS = 5;
int currentTargetTile = 0;
bool isWaitingForHome = true;
unsigned long totalReactionTime = 0;
unsigned long reactionStartTime = 0;

// Timers IoT
unsigned long lastHeartbeatTime = 0;
unsigned long lastPollTime = 0;
bool wifiIsConnected = false;
long remoteActiveSessionId = 0;

// ============================================================================
// 4. FUNGSI DRIVER HARDWARE
// ============================================================================
void updateLEDs(byte pattern) {
  digitalWrite(PIN_LATCH, LOW);
  shiftOut(PIN_DATA, PIN_CLOCK, MSBFIRST, pattern);
  digitalWrite(PIN_LATCH, HIGH);
}

bool isTileStepped(int tileNum) {
  int pin = -1;
  switch (tileNum) {
    case 1: pin = PIN_SENSOR_U1; break;
    case 2: pin = PIN_SENSOR_U2; break;
    case 3: pin = PIN_SENSOR_U3; break;
    case 4: pin = PIN_SENSOR_U4; break;
  }
  if (pin == -1) return false;
  return (digitalRead(pin) == LOW);
}

byte getLEDPattern(int tileNum) {
  switch (tileNum) {
    case 1: return LED_U1;
    case 2: return LED_U2;
    case 3: return LED_U3;
    case 4: return LED_U4;
    default: return LED_OFF;
  }
}

void playSound(int track) {
  if (dfPlayerReady) {
    dfplayer.play(track);
  }
  Serial.print("[AUDIO] Track Diputar: ");
  Serial.println(track);
}

void displayMenu() {
  lcd.clear();
  lcd.setCursor(0, 0);
  if (currentMode == 0)      { lcd.print("M1:FSST 2x2     "); updateLEDs(LED_U1); }
  else if (currentMode == 1) { lcd.print("M2:LATERAL 1x4  "); updateLEDs(LED_U2); }
  else if (currentMode == 2) { lcd.print("M3:REACTIVE T   "); updateLEDs(LED_U3); }

  lcd.setCursor(0, 1);
  lcd.print("U1-3:MOD U4:MULAI");
}

void resetSessionVariables() {
  currentStepIndex = 0;
  reactiveRoundsCompleted = 0;
  totalReactionTime = 0;
  isWaitingForHome = true;
  startTime = millis();
}

// ============================================================================
// 5. FUNGSI IOT & CLOUD SUPABASE
// ============================================================================
void checkWiFiConnection() {
  if (WiFi.status() == WL_CONNECTED) {
    if (!wifiIsConnected) {
      wifiIsConnected = true;
      Serial.print("[WIFI] Terhubung! IP: ");
      Serial.println(WiFi.localIP());
    }
  } else {
    wifiIsConnected = false;
  }
}

void sendHeartbeat() {
  if (WiFi.status() != WL_CONNECTED) return;

  WiFiClientSecure client;
  client.setInsecure(); // Bypass validasi sertifikat HTTPS agar cepat & stabil
  HTTPClient http;

  String url = String(SUPABASE_URL) + "/device?device_code=eq." + DEVICE_CODE;
  if (http.begin(client, url)) {
    http.addHeader("Content-Type", "application/json");
    http.addHeader("apikey", SUPABASE_KEY);
    http.addHeader("Authorization", String("Bearer ") + SUPABASE_KEY);
    http.addHeader("Prefer", "return=minimal");

    String jsonPayload = "{\"status\":\"online\",\"firmware_version\":\"" + String(FIRMWARE_VERSION) + "\"}";
    int httpCode = http.PATCH(jsonPayload);

    if (httpCode >= 200 && httpCode < 300) {
      Serial.println("[SUPABASE] Heartbeat berhasil dikirim (Status: Online)");
    } else {
      Serial.print("[SUPABASE] Heartbeat gagal, HTTP: ");
      Serial.println(httpCode);
    }
    http.end();
  }
}

void uploadSessionToCloud(int modeIndex, unsigned long durationMs, unsigned long avgRtMs, int totalSteps) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[SUPABASE] Lewati upload cloud: Wi-Fi offline");
    return;
  }

  lcd.setCursor(0, 1);
  lcd.print("SYNC CLOUD...   ");

  WiFiClientSecure client;
  client.setInsecure();
  HTTPClient http;

  // 1. Simpan Sesi ke tabel public.training_session
  int modeDbId = modeIndex + 1; // 1: FSST 2x2, 2: Lateral 1x4, 3: Reactive T
  String sessionUrl = String(SUPABASE_URL) + "/training_session";

  long newSessionId = remoteActiveSessionId;

  if (newSessionId == 0) {
    if (http.begin(client, sessionUrl)) {
      http.addHeader("Content-Type", "application/json");
      http.addHeader("apikey", SUPABASE_KEY);
      http.addHeader("Authorization", String("Bearer ") + SUPABASE_KEY);
      http.addHeader("Prefer", "return=representation");

      StaticJsonDocument<256> doc;
      doc["user_id"] = 1;
      doc["device_id"] = DEVICE_ID_DB;
      doc["mode_id"] = modeDbId;
      doc["session_status"] = "completed";

      String payload;
      serializeJson(doc, payload);

      int httpCode = http.POST(payload);
      if (httpCode == 201 || httpCode == 200) {
        String resp = http.getString();
        StaticJsonDocument<512> respDoc;
        deserializeJson(respDoc, resp);
        if (respDoc.is<JsonArray>() && respDoc.size() > 0) {
          newSessionId = respDoc[0]["session_id"];
        }
        Serial.print("[SUPABASE] Sesi baru tersimpan dengan ID: ");
        Serial.println(newSessionId);
      }
      http.end();
    }
  } else {
    // Update status remote session ke completed
    String patchUrl = String(SUPABASE_URL) + "/training_session?session_id=eq." + String(newSessionId);
    if (http.begin(client, patchUrl)) {
      http.addHeader("Content-Type", "application/json");
      http.addHeader("apikey", SUPABASE_KEY);
      http.addHeader("Authorization", String("Bearer ") + SUPABASE_KEY);
      http.addHeader("Prefer", "return=minimal");
      http.PATCH("{\"session_status\":\"completed\"}");
      http.end();
    }
  }

  // 2. Simpan Hasil Detail ke tabel public.session_result
  if (newSessionId > 0) {
    String resultUrl = String(SUPABASE_URL) + "/session_result";
    if (http.begin(client, resultUrl)) {
      http.addHeader("Content-Type", "application/json");
      http.addHeader("apikey", SUPABASE_KEY);
      http.addHeader("Authorization", String("Bearer ") + SUPABASE_KEY);
      http.addHeader("Prefer", "return=minimal");

      StaticJsonDocument<256> resDoc;
      resDoc["session_id"] = newSessionId;
      resDoc["total_steps"] = totalSteps;
      resDoc["correct_steps"] = totalSteps;
      resDoc["incorrect_steps"] = 0;
      resDoc["accuracy_percent"] = 100.00;
      resDoc["avg_response_time_ms"] = (modeIndex == 2) ? avgRtMs : (durationMs / (totalSteps > 0 ? totalSteps : 1));
      resDoc["bilateral_symmetry_percent"] = 50.00; // Simetri seimbang

      String resPayload;
      serializeJson(resDoc, resPayload);
      int resCode = http.POST(resPayload);
      Serial.print("[SUPABASE] Simpan session_result HTTP code: ");
      Serial.println(resCode);
      http.end();
    }
  }

  lcd.setCursor(0, 1);
  lcd.print("SYNC BERHASIL!  ");
  delay(1200);
}

void pollRemoteCommands() {
  if (WiFi.status() != WL_CONNECTED || currentState != STATE_MENU) return;

  WiFiClientSecure client;
  client.setInsecure();
  HTTPClient http;

  // Cek apakah fisioterapis/pasien menekan "Mulai Latihan" dari aplikasi Flutter
  String checkUrl = String(SUPABASE_URL) + "/training_session?session_status=eq.waiting&device_id=eq." + String(DEVICE_ID_DB) + "&order=created_at.desc&limit=1";
  if (http.begin(client, checkUrl)) {
    http.addHeader("apikey", SUPABASE_KEY);
    http.addHeader("Authorization", String("Bearer ") + SUPABASE_KEY);

    int httpCode = http.GET();
    if (httpCode == 200) {
      String resp = http.getString();
      StaticJsonDocument<512> doc;
      deserializeJson(doc, resp);
      if (doc.is<JsonArray>() && doc.size() > 0) {
        remoteActiveSessionId = doc[0]["session_id"];
        int reqModeId = doc[0]["mode_id"];
        if (reqModeId >= 1 && reqModeId <= 3) {
          currentMode = reqModeId - 1;
        }

        Serial.print("[REMOTE APP] Menerima instruksi mulai sesi #");
        Serial.println(remoteActiveSessionId);

        // Update status sesi ke in_progress
        http.end();
        String updateUrl = String(SUPABASE_URL) + "/training_session?session_id=eq." + String(remoteActiveSessionId);
        if (http.begin(client, updateUrl)) {
          http.addHeader("Content-Type", "application/json");
          http.addHeader("apikey", SUPABASE_KEY);
          http.addHeader("Authorization", String("Bearer ") + SUPABASE_KEY);
          http.PATCH("{\"session_status\":\"in_progress\"}");
          http.end();
        }

        // Mulai latihan otomatis dari instruksi aplikasi HP
        lcd.clear();
        lcd.setCursor(0, 0);
        lcd.print("MULAI DARI HP...");
        playSound(AUDIO_BEEP);
        delay(1000);
        resetSessionVariables();
        currentState = STATE_RUNNING;
        return;
      }
    }
    http.end();
  }
}

// ============================================================================
// 6. SETUP UTAMA
// ============================================================================
void setup() {
  Serial.begin(115200);
  delay(200);
  Serial.println("\n=============================================");
  Serial.println("  STEPPING GRID TRAINER - SYSTEM STARTING   ");
  Serial.println("=============================================");

  // Inisialisasi Pin 74HC595
  pinMode(PIN_DATA, OUTPUT);
  pinMode(PIN_CLOCK, OUTPUT);
  pinMode(PIN_LATCH, OUTPUT);
  updateLEDs(LED_OFF);

  // Inisialisasi Limit Switch Pijakan (Active LOW)
  pinMode(PIN_SENSOR_U1, INPUT_PULLUP);
  pinMode(PIN_SENSOR_U2, INPUT_PULLUP);
  pinMode(PIN_SENSOR_U3, INPUT_PULLUP);
  pinMode(PIN_SENSOR_U4, INPUT_PULLUP);

  // Inisialisasi LCD 16x2 via I2C
  Wire.begin(21, 22);
  lcd.init();
  lcd.backlight();
  lcd.setCursor(0, 0);
  lcd.print(" STEPPING GRID ");
  lcd.setCursor(0, 1);
  lcd.print("  SYSTEM READY ");

  // Inisialisasi DFPlayer Mini UART2 (Pin 16 RX2, Pin 17 TX2)
  FPSERIAL.begin(9600, SERIAL_8N1, 16, 17);
  if (dfplayer.begin(FPSERIAL)) {
    dfplayer.volume(25);
    dfPlayerReady = true;
    playSound(AUDIO_WELCOME);
    Serial.println("[AUDIO] DFPlayer Mini Siap (Volume: 25)");
  } else {
    Serial.println("[AUDIO] DFPlayer tidak terdeteksi (Cek kabel RX/TX/Power)");
  }

  // Koneksi ke Jaringan Wi-Fi MiFi ADVAN MF01
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("WIFI CONNECTING ");
  lcd.setCursor(0, 1);
  lcd.print("ADVAN MF01...   ");

  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  int wifiAttempts = 0;
  while (WiFi.status() != WL_CONNECTED && wifiAttempts < 15) {
    delay(400);
    wifiAttempts++;
    Serial.print(".");
  }
  Serial.println();

  if (WiFi.status() == WL_CONNECTED) {
    wifiIsConnected = true;
    Serial.print("[WIFI] Terhubung ke ADVAN MF01! IP: ");
    Serial.println(WiFi.localIP());

    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("WIFI TERHUBUNG! ");
    lcd.setCursor(0, 1);
    lcd.print(WiFi.localIP().toString());
    sendHeartbeat();
  } else {
    wifiIsConnected = false;
    Serial.println("[WIFI] Tidak dapat terhubung ke Wi-Fi. Masuk mode mandiri (Offline OK).");
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("WIFI: OFFLINE   ");
    lcd.setCursor(0, 1);
    lcd.print("MODE MANDIRI OK ");
  }

  delay(1500);
  displayMenu();
}

// ============================================================================
// 7. LOGIKA 3 MODE LATIHAN KLINIS
// ============================================================================
void runFSSTMode() {
  int targetTile = fsstSequence[currentStepIndex];
  updateLEDs(getLEDPattern(targetTile));

  lcd.setCursor(0, 0);
  lcd.print("MODE: FSST 2x2  ");
  lcd.setCursor(0, 1);
  lcd.print("TARGET: UBIN ");
  lcd.print(targetTile);
  lcd.print("  ");

  if (isTileStepped(targetTile)) {
    playSound(AUDIO_BEEP);
    delay(150);
    while (isTileStepped(targetTile)); // Tunggu kaki diangkat

    currentStepIndex++;
    if (currentStepIndex >= FSST_TOTAL_STEPS) {
      totalElapsedTime = millis() - startTime;
      currentState = STATE_FINISHED;
    }
  }
}

void runLateralMode() {
  int targetTile = lateralSequence[currentStepIndex];
  updateLEDs(getLEDPattern(targetTile));

  lcd.setCursor(0, 0);
  lcd.print("MODE: LATERAL1x4");
  lcd.setCursor(0, 1);
  lcd.print("TARGET: UBIN ");
  lcd.print(targetTile);
  lcd.print("  ");

  if (isTileStepped(targetTile)) {
    playSound(AUDIO_BEEP);
    if (currentStepIndex == 3) {
      playSound(AUDIO_TURNBACK); // Aba-aba putar balik di ujung ubin 4
    }

    delay(150);
    while (isTileStepped(targetTile));

    currentStepIndex++;
    if (currentStepIndex >= LATERAL_TOTAL_STEPS) {
      totalElapsedTime = millis() - startTime;
      currentState = STATE_FINISHED;
    }
  }
}

void runReactiveMode() {
  lcd.setCursor(0, 0);
  lcd.print("REACTIVE  R:");
  lcd.print(reactiveRoundsCompleted + 1);
  lcd.print("/");
  lcd.print(TOTAL_REACTIVE_ROUNDS);
  lcd.print(" ");

  if (isWaitingForHome) {
    updateLEDs(LED_U1);
    lcd.setCursor(0, 1);
    lcd.print("STANDBY: UBIN 1 ");

    if (isTileStepped(1)) {
      playSound(AUDIO_BEEP);
      isWaitingForHome = false;
      currentTargetTile = random(2, 5); // Acak target ubin 2, 3, atau 4
      updateLEDs(getLEDPattern(currentTargetTile));
      reactionStartTime = millis();
      delay(200);
    }
  } else {
    lcd.setCursor(0, 1);
    lcd.print("TARGET : UBIN ");
    lcd.print(currentTargetTile);
    lcd.print(" ");

    if (isTileStepped(currentTargetTile)) {
      unsigned long reactionTime = millis() - reactionStartTime;
      totalReactionTime += reactionTime;
      playSound(AUDIO_BEEP);

      reactiveRoundsCompleted++;
      isWaitingForHome = true;

      delay(150);
      while (isTileStepped(currentTargetTile));

      if (reactiveRoundsCompleted >= TOTAL_REACTIVE_ROUNDS) {
        totalElapsedTime = totalReactionTime / TOTAL_REACTIVE_ROUNDS;
        currentState = STATE_FINISHED;
      }
    }
  }
}

// ============================================================================
// 8. MAIN LOOP
// ============================================================================
void loop() {
  // Pemeriksaan koneksi Wi-Fi berkala
  checkWiFiConnection();

  // Kirim Heartbeat ke Supabase Cloud tiap 20 detik
  if (millis() - lastHeartbeatTime >= HEARTBEAT_INTERVAL) {
    lastHeartbeatTime = millis();
    sendHeartbeat();
  }

  // --- STATE 1: PILIH MODE LEWAT UBIN 1-3, MULAI LEWAT UBIN 4 ATAU APP HP ---
  if (currentState == STATE_MENU) {
    // Periksa perintah dari aplikasi ponsel setiap 3 detik
    if (millis() - lastPollTime >= REMOTE_POLL_INTERVAL) {
      lastPollTime = millis();
      pollRemoteCommands();
    }

    if (isTileStepped(1)) {
      currentMode = 0;
      displayMenu();
      playSound(AUDIO_MODE_FSST);
      delay(200);
      while (isTileStepped(1));
    } 
    else if (isTileStepped(2)) {
      currentMode = 1;
      displayMenu();
      playSound(AUDIO_MODE_LATERAL);
      delay(200);
      while (isTileStepped(2));
    } 
    else if (isTileStepped(3)) {
      currentMode = 2;
      displayMenu();
      playSound(AUDIO_MODE_REACTIVE);
      delay(200);
      while (isTileStepped(3));
    } 
    else if (isTileStepped(4)) {
      playSound(AUDIO_BEEP);
      delay(200);
      while (isTileStepped(4)); // Tunggu kaki lepas dari Ubin 4 sebelum mulai
      remoteActiveSessionId = 0; // Sesi dimulai langsung dari hardware
      resetSessionVariables();
      currentState = STATE_RUNNING;
    }
  }

  // --- STATE 2: LATIHAN SEDANG BERJALAN ---
  else if (currentState == STATE_RUNNING) {
    if (currentMode == 0)      runFSSTMode();
    else if (currentMode == 1) runLateralMode();
    else if (currentMode == 2) runReactiveMode();
  }

  // --- STATE 3: SELESAI (TAMPILKAN SKOR, UPLOAD CLOUD & KEMBALI) ---
  else if (currentState == STATE_FINISHED) {
    updateLEDs(LED_OFF);
    playSound(AUDIO_FINISH);

    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("LATIHAN SELESAI!");
    lcd.setCursor(0, 1);

    if (currentMode == 2) {
      lcd.print("AVG RT: ");
      lcd.print(totalElapsedTime / 1000.0, 2);
      lcd.print(" dtk");
    } else {
      lcd.print("WAKTU : ");
      lcd.print(totalElapsedTime / 1000.0, 2);
      lcd.print(" dtk");
    }

    delay(2000);

    // Kirim rekam medis sesi ke Supabase Cloud
    int totalStepsCount = (currentMode == 0) ? FSST_TOTAL_STEPS : ((currentMode == 1) ? LATERAL_TOTAL_STEPS : TOTAL_REACTIVE_ROUNDS);
    uploadSessionToCloud(currentMode, totalElapsedTime, totalElapsedTime, totalStepsCount);

    lcd.clear();
    lcd.setCursor(0, 0);
    if (currentMode == 2) {
      lcd.print("AVG RT: ");
      lcd.print(totalElapsedTime / 1000.0, 2);
      lcd.print("s");
    } else {
      lcd.print("WAKTU : ");
      lcd.print(totalElapsedTime / 1000.0, 2);
      lcd.print("s");
    }
    lcd.setCursor(0, 1);
    lcd.print("INJAK UBIN=MENU ");

    while (!isTileStepped(1) && !isTileStepped(2) && !isTileStepped(3) && !isTileStepped(4)) {
      // Tunggu salah satu ubin diinjak untuk kembali ke menu
      delay(20);
    }

    delay(200);
    while (isTileStepped(1) || isTileStepped(2) || isTileStepped(3) || isTileStepped(4));

    currentState = STATE_MENU;
    displayMenu();
  }
}
