import serial
import json
import time

# --- Windows Configuration ---
SERIAL_PORT = 'COM8' # <-- UPDATE THIS TO YOUR ESP32'S COM PORT
BAUD_RATE = 115200

def read_edge_node():
    print(f"🔌 Connecting to Edge Node on {SERIAL_PORT}...")
    
    try:
        edge_device = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=1)
        time.sleep(2) 
        print("✅ Connection Established. Listening for live data...\n")
        
        while True:
            if edge_device.in_waiting > 0:
                raw_line = edge_device.readline().decode('utf-8').strip()
                
                if not raw_line.startswith('{'):
                    continue
                
                try:
                    data = json.loads(raw_line)
                    rms = data.get('rms', 0)
                    status = data.get('status', 0)
                    confidence = data.get('confidence', 0)
                    
                    if status == 1:
                        print(f"🔴 FAULT DETECTED | RMS: {rms:.4f}v | Confidence: {confidence:.2f}%")
                    else:
                        print(f"🟢 HEALTHY | RMS: {rms:.4f}v | Confidence: {confidence:.2f}%")
                        
                except json.JSONDecodeError:
                    pass 

    except serial.SerialException:
        print(f"❌ Error: Could not open {SERIAL_PORT}.")
        print("Check that the ESP32 is plugged in and the Arduino Serial Monitor is CLOSED.")
    except KeyboardInterrupt:
        print("\n🛑 Disconnected from Edge Node.")
        if 'edge_device' in locals() and edge_device.is_open:
            edge_device.close()

if __name__ == "__main__":
    read_edge_node()