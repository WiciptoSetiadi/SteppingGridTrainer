"""
ESP32 Hardware Client Simulator
Simulates ESP32 DevKit V1 behavior according to SDD 3.2.4 (M-04) & 3.2.5 (M-05).
- Sends periodic heartbeat
- Polls for waiting sessions
- Executes stepping sequence based on layout (2x2, Horizontal, T-Shape)
- Sends step_log to Supabase in real-time
- Completes session to trigger AI pipeline
"""

import os
import sys
import time
import random
import argparse
from datetime import datetime
import httpx

SUPABASE_URL = os.getenv("SUPABASE_URL", "http://localhost:54321")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_ROLE_KEY", os.getenv("SUPABASE_ANON_KEY", "placeholder-key"))
DEVICE_CODE = os.getenv("DEVICE_CODE", "SGT-01")

class ESP32Simulator:
    def __init__(self, base_url: str, api_key: str, device_code: str = "SGT-01"):
        self.base_url = f"{base_url.rstrip('/')}/rest/v1"
        self.functions_url = f"{base_url.rstrip('/')}/functions/v1"
        self.headers = {
            "apikey": api_key,
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
            "Prefer": "return=representation"
        }
        self.device_code = device_code
        self.device_id = None
        self.firmware_version = "1.0.0"

    def get_or_register_device(self):
        """Mendapatkan device_id dari database."""
        with httpx.Client() as client:
            resp = client.get(
                f"{self.base_url}/device",
                params={"device_code": f"eq.{self.device_code}"},
                headers=self.headers
            )
            if resp.status_code == 200 and resp.json():
                self.device_id = resp.json()[0]["device_id"]
                print(f"[ESP32] Terhubung sebagai device_id={self.device_id} ({self.device_code})")
                return self.device_id
            else:
                print(f"[ESP32] Warning: Device {self.device_code} tidak ditemukan di database.")
                return None

    def send_heartbeat(self):
        """Mengirim heartbeat ke Edge Function atau tabel device (SDD 3.2.11)."""
        payload = {
            "device_code": self.device_code,
            "firmware_version": self.firmware_version,
            "status": "online"
        }
        try:
            with httpx.Client() as client:
                # Coba via Edge Function
                resp = client.post(
                    f"{self.functions_url}/device-heartbeat",
                    json=payload,
                    headers=self.headers,
                    timeout=5.0
                )
                if resp.status_code == 200:
                    print(f"[ESP32] Heartbeat berhasil dikirim (Edge Function).")
                    return
        except Exception:
            pass

        # Fallback via direct REST
        try:
            with httpx.Client() as client:
                client.patch(
                    f"{self.base_url}/device",
                    params={"device_code": f"eq.{self.device_code}"},
                    json={"last_seen_at": "now()", "status": "online"},
                    headers=self.headers,
                    timeout=5.0
                )
                print(f"[ESP32] Heartbeat berhasil dikirim (REST API).")
        except Exception as e:
            print(f"[ESP32] Gagal mengirim heartbeat: {e}")

    def poll_waiting_session(self):
        """Memeriksa apakah ada sesi waiting yang ditujukan untuk perangkat ini (SDD 3.2.5)."""
        if not self.device_id:
            self.get_or_register_device()
            if not self.device_id:
                return None

        with httpx.Client() as client:
            resp = client.get(
                f"{self.base_url}/training_session",
                params={
                    "device_id": f"eq.{self.device_id}",
                    "session_status": "eq.waiting",
                    "select": "*,session_config(*,layout(*,tile_position(*)))",
                    "order": "created_at.asc",
                    "limit": 1
                },
                headers=self.headers
            )
            if resp.status_code == 200 and resp.json():
                return resp.json()[0]
            return None

    def execute_session(self, session: dict, error_rate: float = 0.1):
        """Menjalankan simulasi terapi langkah untuk sesi yang diterima."""
        session_id = session["session_id"]
        config = session.get("session_config") or {}
        layout = config.get("layout") or {}
        layout_name = layout.get("layout_name", "2x2")
        total_targets = config.get("total_targets", 20)
        tempo_ms = config.get("target_tempo_ms", 1500)
        positions = layout.get("tile_position") or []

        if not positions:
            print(f"[ESP32] Error: Tidak ada data posisi ubin untuk layout!")
            return

        print(f"\n[ESP32] Memulai Sesi #{session_id} - Layout: {layout_name}, Target: {total_targets}, Tempo: {tempo_ms}ms")

        # 1. Update status sesi ke 'running'
        with httpx.Client() as client:
            client.patch(
                f"{self.base_url}/training_session",
                params={"session_id": f"eq.{session_id}"},
                json={"session_status": "running", "started_at": datetime.utcnow().isoformat()},
                headers=self.headers
            )
        print(f"[ESP32] Status sesi diubah menjadi 'running'. Pasien berdiri di posisi awal...")
        time.sleep(1.5)  # Simulasi debounce penahanan posisi awal (2 detik)

        # 2. Loop simulasi langkah
        step_number = 1
        pos_map = {p["position_code"]: p for p in positions}
        pattern = layout.get("sequential_pattern") or list(pos_map.keys())

        pattern_idx = 0
        while step_number <= total_targets:
            target_code = pattern[pattern_idx % len(pattern)]
            target_pos = pos_map.get(target_code) or positions[0]

            # Simulasi waktu reaksi pasien (misal 600 - 1500 ms)
            reaction_time = int(random.uniform(tempo_ms * 0.5, tempo_ms * 1.2))
            is_correct = random.random() >= error_rate

            if is_correct:
                actual_pos = target_pos
                event_type = "target_hit"
                print(f"[ESP32] Step #{step_number}: Injak {actual_pos['position_code']} (BENAR) - Reaksi: {reaction_time}ms [Beep Tinggi]")
                pattern_idx += 1
            else:
                # Pasien menginjak ubin yang salah
                other_positions = [p for p in positions if p["position_code"] != target_code]
                actual_pos = random.choice(other_positions) if other_positions else target_pos
                event_type = "wrong_step"
                print(f"[ESP32] Step #{step_number}: Injak {actual_pos['position_code']} (SALAH! Target: {target_code}) [Beep Rendah]")

            # Kirim step_log ke Supabase
            step_payload = {
                "session_id": session_id,
                "position_id": actual_pos["position_id"],
                "step_number": step_number,
                "event_type": event_type,
                "is_correct": is_correct,
                "reaction_time_ms": reaction_time if is_correct else None,
                "event_at": datetime.utcnow().isoformat()
            }

            with httpx.Client() as client:
                resp = client.post(
                    f"{self.base_url}/step_log",
                    json=step_payload,
                    headers=self.headers
                )
                if resp.status_code not in (200, 201):
                    print(f"[ESP32] Gagal mengirim log langkah: {resp.text}")

            step_number += 1
            # Interval antar langkah
            time.sleep(reaction_time / 1000.0)

        # 3. Selesaikan sesi -> 'completed'
        print(f"[ESP32] Target terpenuhi! Menyelesaikan sesi #{session_id}...")
        with httpx.Client() as client:
            resp = client.patch(
                f"{self.base_url}/training_session",
                params={"session_id": f"eq.{session_id}"},
                json={"session_status": "completed", "ended_at": datetime.utcnow().isoformat()},
                headers=self.headers
            )
            if resp.status_code == 200:
                print(f"[ESP32] Sesi #{session_id} berstatus 'completed'. AI Webhook terpicu otomatis.\n")

def main():
    parser = argparse.ArgumentParser(description="Simulator Perangkat ESP32 Stepping Grid Trainer")
    parser.add_argument("--url", default=SUPABASE_URL, help="Supabase REST Base URL")
    parser.add_argument("--key", default=SUPABASE_KEY, help="Supabase Service Role Key")
    parser.add_argument("--device", default=DEVICE_CODE, help="Device Code (default: SGT-01)")
    parser.add_argument("--poll-interval", type=int, default=2, help="Interval polling sesi (detik)")
    parser.add_argument("--auto", action="store_true", help="Jalankan loop daemon polling otomatis")
    args = parser.parse_args()

    simulator = ESP32Simulator(args.url, args.key, args.device)
    simulator.get_or_register_device()
    simulator.send_heartbeat()

    if args.auto:
        print(f"[ESP32] Mode otomatis aktif. Polling sesi setiap {args.poll_interval} detik... (Tekan Ctrl+C untuk berhenti)")
        last_hb = time.time()
        try:
            while True:
                if time.time() - last_hb > 30:
                    simulator.send_heartbeat()
                    last_hb = time.time()

                session = simulator.poll_waiting_session()
                if session:
                    simulator.execute_session(session)
                time.sleep(args.poll_interval)
        except KeyboardInterrupt:
            print("\n[ESP32] Simulator dihentikan.")
    else:
        print("[ESP32] Melakukan 1 kali pemeriksaan sesi...")
        session = simulator.poll_waiting_session()
        if session:
            simulator.execute_session(session)
        else:
            print("[ESP32] Tidak ada sesi dengan status 'waiting'. Gunakan --auto untuk polling terus-menerus.")

if __name__ == "__main__":
    main()
