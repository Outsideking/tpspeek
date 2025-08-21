from tpspeek.tpspeek import TPspeekOffline

# เรียกใช้งาน
tp = TPspeekOffline()

# แปลงไฟล์เสียง input.wav -> แปล -> output.wav
tp.speech_to_speech("input.wav", "output.wav")

print("✅ เสร็จแล้ว! ดูไฟล์ output.wav")
