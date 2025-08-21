import React, { useState } from 'react';
import { View, Text, Button } from 'react-native';
import * as Speech from 'expo-speech';
import { startRecording, stopRecording, recognizeSpeech } from './speechUtils';
import { translateText } from '../services/tpspeekApi';

export default function VoiceTranslator({ targetLang }) {
  const [status, setStatus] = useState('Idle');
  const [translated, setTranslated] = useState('');

  const handleStart = async () => {
    setStatus('Listening...');
    await startRecording();
  };

  const handleStop = async () => {
    setStatus('Processing...');
    const text = await stopRecording();   // ส่งเสียง -> STT
    const detectedLang = await recognizeSpeech(text); // detect language
    const result = await translateText(text, detectedLang, targetLang);
    setTranslated(result);
    Speech.speak(result, { language: targetLang }); // พูดผลลัพธ์
    setStatus('Idle');
  };

  return (
    <View style={{ padding: 20 }}>
      <Text>Status: {status}</Text>
      <Button title="Start Listening" onPress={handleStart} />
      <Button title="Stop & Translate" onPress={handleStop} />
      <Text>Translated: {translated}</Text>
    </View>
  );
}
