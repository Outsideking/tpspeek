import * as Audio from 'expo-av';
import { detectLanguage } from './tpspeekApi';

// เริ่มบันทึกเสียง
export async function startRecording() {
  const recording = new Audio.Recording();
  await recording.prepareToRecordAsync(Audio.RECORDING_OPTIONS_PRESET_HIGH_QUALITY);
  await recording.startAsync();
  global.currentRecording = recording;
}

// หยุดบันทึกและส่งเสียงเป็นข้อความ
export async function stopRecording() {
  const recording = global.currentRecording;
  await recording.stopAndUnloadAsync();
  const uri = recording.getURI();
  // ส่งเสียงไป backend STT
  const resp = await fetch('http://<SERVER_IP>:8000/stt', {
    method: 'POST',
    body: JSON.stringify({ file_uri: uri }),
    headers: { 'Content-Type': 'application/json' }
  });
  const data = await resp.json();
  return data.text;
}

// ตรวจจับภาษาอัตโนมัติ
export async function recognizeSpeech(text) {
  const detected = await detectLanguage(text); // backend API ตรวจภาษา
  return detected.language_code; // เช่น 'th', 'en'
}
