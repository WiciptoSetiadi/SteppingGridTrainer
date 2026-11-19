/*
 * ==============================================================================
 * STEPPING GRID TRAINER - ESP32 FIRMWARE (DevKit V1)
 * ==============================================================================
 * Sistem Terapi Jalan Pasca-Stroke berbasis Matras Ubin Interaktif IoT
 * Komunikasi Langsung: ESP32 <-> Supabase Cloud REST API via HTTPS
 * Sesuai spesifikasi Software Design Document (SDD) M-04 & M-05
 * ==============================================================================
 */

#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

// ==============================================================================
// 1. KONFIGURASI WI-FI & SUPABASE CLOUD
// ==============================================================================
// Sesuai jaringan MiFi ADVAN MF01 Anda:
const char* WIFI_SSID     = "ADVAN MF01-83405B";      // SSID MiFi Advan
const char* WIFI_PASSWORD = "085848719373";          // Kata Sandi MiFi Advan
const char* ROUTER_IP     = "192.168.0.1";           // Gateway IP MiFi Advan

// Supabase Project Credentials (Terkoneksi ke project rtvtralxxvzxitdqjrco)
const char* SUPABASE_HOST = "rtvtralxxvzxitdqjrco.supabase.co";
const char* SUPABASE_URL  = "https://rtvtralxxvzxitdqjrco.supabase.co/rest/v1";
const char* SUPABASE_KEY  = "sb_publishable_9Z8VFKtqUnlXfWyzXgMi3g_udj5JQ5r";

// Identitas Perangkat
const char* DEVICE_CODE      = "SGT-01";
const int   DEVICE_ID_DB     = 1;          // ID pada tabel public.device
const char* FIRMWARE_VERSION = "1.0.0";

// ==============================================================================
// 2. KONFIGURASI PINOUT HARDWARE (ESP32 DEVKIT V1)
// ==============================================================================
// 4 Sensor Tekan / Microswitch Ubin (Port P1 - P4) - Active LOW (GND saat ditekan)
const int PIN_SENSOR_P1 = 18;  // Ubin P1 (Misal: 2x2 Front-Left / FL)
const int PIN_SENSOR_P2 = 19;  // Ubin P2 (Misal: 2x2 Front-Right / FR)
const int PIN_SENSOR_P3 = 22;  // Ubin P3 (Misal: 2x2 Back-Left / BL)
const int PIN_SENSOR_P4 = 23;  // Ubin P4 (Misal: 2x2 Back-Right / BR)

// 4 Lampu LED Indikator Ubin (Port P1 - P4) - Active HIGH
const int PIN_LED_P1    = 13;  // LED Ubin P1
const int PIN_LED_P2    = 14;  // LED Ubin P2
const int PIN_LED_P3    = 27;  // LED Ubin P3
const int PIN_LED_P4    = 26;  // LED Ubin P4

// Audio Feedback / Buzzer Aba-aba
const int PIN_BUZZER    = 25;  // Buzzer Pasif / Aktif (PWM channel 0)
const int BUZZER_CH     = 0;

// Indikator Status Wi-Fi Board (LED Bawaan ESP32 GPIO 2)
const int PIN_BOARD_LED = 2;

// ==============================================================================
// 3. VARIABEL STATE SISTEM
// ==============================================================================
unsigned long lastHeartbeatTime = 0;
const unsigned long HEARTBEAT_INTERVAL = 30000; // Kirim heartbeat tiap 30 detik

unsigned long lastPollTime = 0;
const unsigned long POLL_INTERVAL = 2000;       // Periksa sesi baru tiap 2 detik

bool isSessionRunning = false;
long currentSessionId = 0;
int  targetTempoMs    = 1500; // Cadence bawaan (40 langkah/menit)
int  totalTargets     = 20;

// Array pemetaan pin port
const int SENSOR_PINS[4] = { PIN_SENSOR_P1, PIN_SENSOR_P2, PIN_SENSOR_P3, PIN_SENSOR_P4 };
const int LED_PINS[4]    = { PIN_LED_P1, PIN_LED_P2, PIN_LED_P3, PIN_LED_P4 };

// Posisi & Pola Target Sesi
int sessionPortSequence[64];
int sessionPositionIds[64];
int sequenceLength = 0;

// ==============================================================================
// 4. FUNGSI AUDIO & VISUAL FEEDBACK
// ==============================================================================
void playTone(int freqHz, int durationMs) {
  ledcWriteTone(BUZZER_CH, freqHz);
  delay(durationMs);
  ledcWriteTone(BUZZER_CH, 0);
}

void beepCorrect() {
  // Nada Tinggi 880 Hz (A5) saat injakan benar
  playTone(880, 120);
}

void beepWrong() {
  // Nada Rendah 220 Hz (A3) saat injakan salah
  playTone(220, 250);
}

void beepStartSequence() {
  playTone(523, 100); // C5
  delay(50);
  playTone(659, 100); // E5
  delay(50);
  playTone(784, 150); // G5
}

void beepCompletedSequence() {
  playTone(523, 120);
  delay(50);
  playTone(659, 120);
  delay(50);
  playTone(784, 120);
  delay(50);
  playTone(1046, 300); // C6
}

void setAllLeds(bool state) {
  for (int i = 0; i < 4; i++) {
    digitalWrite(LED_PINS[i], state ? HIGH : LOW);
  }
}

void setTileLed(int portIndex, bool state) {
  if (portIndex >= 0 && portIndex < 4) {
    digitalWrite(LED_PINS[portIndex], state ? HIGH : LOW);
  }
}

// ==============================================================================
// 5. HELPER KONEKSI WI-FI & HTTP SUPABASE
// ==============================================================================
void checkWiFiConnection() {
  if (WiFi.status() == WL_CONNECTED) {
    digitalWrite(PIN_BOARD_LED, HIGH);
    return;
  }

  digitalWrite(PIN_BOARD_LED, LOW);
  Serial.print("[WiFi] Menghubungkan ke ");
  Serial.println(WIFI_SSID);

  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  int retries = 0;
  while (WiFi.status() != WL_CONNECTED && retries < 25) {
    delay(500);
    Serial.print(".");
    retries++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n[WiFi] Terhubung ke " + String(WIFI_SSID));
    Serial.println("[WiFi] IP ESP32 : " + WiFi.localIP().toString());
    Serial.println("[WiFi] Gateway  : " + WiFi.gatewayIP().toString());
    digitalWrite(PIN_BOARD_LED, HIGH);
    beepStartSequence();
  } else {
    Serial.println("\n[WiFi] Gagal terhubung. Akan dicoba lagi di loop.");
  }
}

// Helper pengiriman HTTP ke Supabase REST
bool sendSupabaseRequest(const String& endpoint, const String& method, const String& payload, String& responseOut) {
  if (WiFi.status() != WL_CONNECTED) return false;

  WiFiClientSecure client;
  client.setInsecure(); // Mengabaikan validasi rantai sertifikat SSL demi stabilitas RAM ESP32

  HTTPClient http;
  String fullUrl = String(SUPABASE_URL) + endpoint;
  http.begin(client, fullUrl);

  http.addHeader("apikey", SUPABASE_KEY);
  http.addHeader("Authorization", String("Bearer ") + SUPABASE_KEY);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("Prefer", "return=representation");
  http.setTimeout(7000);

  int httpCode = -1;
  if (method == "GET") {
    httpCode = http.GET();
  } else if (method == "POST") {
    httpCode = http.POST(payload);
  } else if (method == "PATCH") {
    httpCode = http.PATCH(payload);
  }

  if (httpCode > 0) {
    responseOut = http.getString();
    http.end();
    return (httpCode >= 200 && httpCode < 300);
  } else {
    Serial.printf("[HTTP] Error %s ke %s: %s\n", method.c_str(), endpoint.c_str(), http.errorToString(httpCode).c_str());
    http.end();
    return false;
  }
}

// ==============================================================================
// 6. FUNGSI IOT: HEARTBEAT, POLLING, & LOG LANGKAH
// ==============================================================================

// Mengirim status online ke tabel public.device
void sendHeartbeat() {
  String response;
  String payload = "{\"status\":\"online\",\"last_seen_at\":\"now()\"}";
  String endpoint = String("/device?device_code=eq.") + DEVICE_CODE;

  if (sendSupabaseRequest(endpoint, "PATCH", payload, response)) {
    Serial.println("[IoT] Heartbeat terkirim: Device " + String(DEVICE_CODE) + " ONLINE");
  }
}

// Memeriksa apakah ada sesi latihan yang dibuat oleh aplikasi (Status: 'waiting')
bool pollWaitingSession() {
  String response;
  // Ambil sesi waiting untuk perangkat ini, beserta konfigurasi layout & tile_position
  String endpoint = String("/training_session?device_id=eq.") + String(DEVICE_ID_DB) +
                    "&session_status=eq.waiting" +
                    "&select=*,session_config(*,layout(*,tile_position(*)))" +
                    "&order=created_at.asc&limit=1";

  if (!sendSupabaseRequest(endpoint, "GET", "", response)) return false;

  DynamicJsonDocument doc(8192);
  DeserializationError err = deserializeJson(doc, response);
  if (err || doc.size() == 0) return false;

  JsonObject session = doc[0];
  currentSessionId = session["session_id"].as<long>();
  Serial.printf("\n[IoT] DITEMUKAN SESI BARU! ID: #%ld\n", currentSessionId);

  JsonObject config = session["session_config"];
  targetTempoMs = config["target_tempo_ms"] | 1500;
  totalTargets  = config["total_targets"] | 20;

  JsonObject layout = config["layout"];
  String layoutName = layout["layout_name"].as<String>();
  Serial.printf("[IoT] Mode: %s, Tempo: %d ms, Target: %d langkah\n", layoutName.c_str(), targetTempoMs, totalTargets);

  // Ambil data posisi ubin & port (1-4)
  JsonArray positions = layout["tile_position"];
  sequenceLength = 0;

  // Baca urutan langkah (sequential_pattern)
  JsonArray pattern = layout["sequential_pattern"];
  if (pattern.size() > 0) {
    for (JsonVariant codeVar : pattern) {
      const char* code = codeVar.as<const char*>();
      for (JsonObject pos : positions) {
        if (strcmp(pos["position_code"].as<const char*>(), code) == 0) {
          int port = pos["port_number"].as<int>() - 1; // 0-indexed port
          if (port >= 0 && port < 4 && sequenceLength < 64) {
            sessionPortSequence[sequenceLength] = port;
            sessionPositionIds[sequenceLength]  = pos["position_id"].as<int>();
            sequenceLength++;
          }
          break;
        }
      }
    }
  }

  // Jika pola kosong, gunakan port 0..3 berurutan
  if (sequenceLength == 0) {
    for (int i = 0; i < 4; i++) {
      sessionPortSequence[i] = i;
      sessionPositionIds[i] = i + 1;
    }
    sequenceLength = 4;
  }

  return true;
}

// Mengubah status sesi menjadi 'running'
void startSessionOnDatabase() {
  String response;
  String payload = "{\"session_status\":\"running\",\"started_at\":\"now()\"}";
  String endpoint = String("/training_session?session_id=eq.") + String(currentSessionId);
  sendSupabaseRequest(endpoint, "PATCH", payload, response);
  Serial.println("[IoT] Sesi #" + String(currentSessionId) + " dimulai (status: running)");
}

// Mengirim rekam langkah per injakan kaki (M-08 step_log)
void sendStepLog(int stepNum, int posId, bool isCorrect, long reactionTimeMs, const char* eventType) {
  String response;
  DynamicJsonDocument doc(512);
  doc["session_id"] = currentSessionId;
  doc["position_id"] = posId;
  doc["step_number"] = stepNum;
  doc["event_type"] = eventType;
  doc["is_correct"] = isCorrect;
  if (isCorrect) {
    doc["reaction_time_ms"] = reactionTimeMs;
  } else {
    doc["reaction_time_ms"] = nullptr;
  }

  String payload;
  serializeJson(doc, payload);
  sendSupabaseRequest("/step_log", "POST", payload, response);
}

// Mengubah status sesi menjadi 'completed' (Memicu AI Webhook)
void completeSessionOnDatabase() {
  String response;
  String payload = "{\"session_status\":\"completed\",\"ended_at\":\"now()\"}";
  String endpoint = String("/training_session?session_id=eq.") + String(currentSessionId);
  sendSupabaseRequest(endpoint, "PATCH", payload, response);
  Serial.printf("\n[IoT] SESI #%ld SELESAI (status: completed)!\n", currentSessionId);
  Serial.println("[IoT] AI Analytics & Rekomendasi otomatis diproses oleh Supabase Webhook.");
}

// ==============================================================================
// 7. LOOP PELAKSANAAN SESI LATIHAN REAL-TIME
// ==============================================================================
void runTrainingSession() {
  startSessionOnDatabase();
  beepStartSequence();

  // Debounce penahanan posisi awal (Pasien berdiri di matras 2 detik)
  Serial.println("[IoT] Siap melangkah... 3, 2, 1, Mulai!");
  setAllLeds(true);
  delay(800);
  setAllLeds(false);
  delay(600);

  int stepNumber = 1;
  int patternIdx = 0;

  while (stepNumber <= totalTargets) {
    int targetPort = sessionPortSequence[patternIdx % sequenceLength];
    int targetPosId = sessionPositionIds[patternIdx % sequenceLength];

    // Nyalakan LED sasaran
    setTileLed(targetPort, true);
    unsigned long stepStartTime = millis();
    bool stepDetected = false;

    // Tunggu injakan pasien (dengan batas waktu timeout tempo x 2 atau 6 detik)
    unsigned long timeoutMs = targetTempoMs * 2;
    if (timeoutMs < 3000) timeoutMs = 3000;

    while ((millis() - stepStartTime) < timeoutMs) {
      // Periksa 4 sensor
      for (int p = 0; p < 4; p++) {
        // Sensor ditekan (Active LOW dengan INPUT_PULLUP)
        if (digitalRead(SENSOR_PINS[p]) == LOW) {
          delay(40); // Hardware debounce filter
          if (digitalRead(SENSOR_PINS[p]) == LOW) {
            unsigned long reactionMs = millis() - stepStartTime;

            if (p == targetPort) {
              // INJAKAN BENAR
              Serial.printf("[Step #%d] Target Port P%d -> BENAR! (Reaksi: %lu ms)\n", stepNumber, p + 1, reactionMs);
              beepCorrect();
              setTileLed(targetPort, false);
              sendStepLog(stepNumber, targetPosId, true, reactionMs, "target_hit");
              patternIdx++;
              stepDetected = true;
            } else {
              // INJAKAN SALAH (Ubin yang keliru)
              Serial.printf("[Step #%d] Target Port P%d, Terinjak P%d -> SALAH!\n", stepNumber, targetPort + 1, p + 1);
              beepWrong();
              sendStepLog(stepNumber, targetPosId, false, 0, "wrong_step");
              stepDetected = true;
            }

            // Tunggu sampai kaki diangkat dari ubin
            while (digitalRead(SENSOR_PINS[p]) == LOW) {
              delay(20);
            }
            break;
          }
        }
      }

      if (stepDetected) break;
      delay(10);
    }

    // Tangani jika terjadi Timeout (tidak melangkah sama sekali)
    if (!stepDetected) {
      Serial.printf("[Step #%d] Timeout! Pasien tidak melangkah dalam %lu ms\n", stepNumber, timeoutMs);
      beepWrong();
      setTileLed(targetPort, false);
      sendStepLog(stepNumber, targetPosId, false, 0, "timeout");
      patternIdx++;
    }

    stepNumber++;

    // Jeda ritmis antar langkah sesuai tempo target
    delay(200);
  }

  // Akhiri sesi latihan
  setAllLeds(false);
  beepCompletedSequence();
  completeSessionOnDatabase();
}

// ==============================================================================
// 8. ARDUINO SETUP & MAIN LOOP
// ==============================================================================
void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("\n==============================================");
  Serial.println("  STEPPING GRID TRAINER - ESP32 DevKit V1");
  Serial.println("  Sistem Terapi Jalan Pasca-Stroke IoT");
  Serial.println("==============================================");

  // Inisialisasi Pin Sensor (INPUT_PULLUP)
  for (int i = 0; i < 4; i++) {
    pinMode(SENSOR_PINS[i], INPUT_PULLUP);
  }

  // Inisialisasi Pin LED (OUTPUT)
  for (int i = 0; i < 4; i++) {
    pinMode(LED_PINS[i], OUTPUT);
    digitalWrite(LED_PINS[i], LOW);
  }

  pinMode(PIN_BOARD_LED, OUTPUT);
  digitalWrite(PIN_BOARD_LED, LOW);

  // Inisialisasi Buzzer PWM
  ledcSetup(BUZZER_CH, 2000, 8);
  ledcAttachPin(PIN_BUZZER, BUZZER_CH);

  // Tes LED dan Buzzer saat menyala
  setAllLeds(true);
  playTone(880, 150);
  delay(300);
  setAllLeds(false);

  // Koneksi Wi-Fi awal
  checkWiFiConnection();
  sendHeartbeat();
}

void loop() {
  // 1. Pastikan Wi-Fi selalu terhubung
  if (WiFi.status() != WL_CONNECTED) {
    checkWiFiConnection();
    delay(1000);
    return;
  }

  // 2. Kirim Heartbeat periodik
  unsigned long now = millis();
  if (now - lastHeartbeatTime > HEARTBEAT_INTERVAL) {
    sendHeartbeat();
    lastHeartbeatTime = now;
  }

  // 3. Periksa apakah ada sesi baru dari Aplikasi (Polling)
  if (!isSessionRunning && (now - lastPollTime > POLL_INTERVAL)) {
    lastPollTime = now;
    if (pollWaitingSession()) {
      isSessionRunning = true;
      runTrainingSession();
      isSessionRunning = false;
      sendHeartbeat(); // Refresh status setelah selesai
    }
  }

  delay(20);
}
