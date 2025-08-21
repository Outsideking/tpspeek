import whisper
from transformers import MarianMTModel, MarianTokenizer
from TTS.api import TTS
import base64

class TPspeekOffline:
    def __init__(self):
        # โหลด STT
        self.stt_model = whisper.load_model("small")
        # โหลด Translation
        self.translator_model_name = "Helsinki-NLP/opus-mt-th-en"
        self.tokenizer = MarianTokenizer.from_pretrained(self.translator_model_name)
        self.translator = MarianMTModel.from_pretrained(self.translator_model_name)
        # โหลด TTS
        self.tts = TTS(model_name="tts_models/en/ljspeech/tacotron2-DDC", progress_bar=False, gpu=False)

    def speech_to_text(self, audio_file):
        result = self.stt_model.transcribe(audio_file)
        return result['text']

    def translate_text(self, text, source_lang="th", target_lang="en"):
        # ปรับชื่อ model ตามภาษาได้ถ้าต้องการ
        translated = self.translator.generate(**self.tokenizer(text, return_tensors="pt", padding=True))
        return self.tokenizer.decode(translated[0], skip_special_tokens=True)

    def text_to_speech(self, text, output_file="output.wav"):
        self.tts.tts_to_file(text=text, file_path=output_file)
        return output_file

    def speech_to_speech(self, input_audio, output_audio="output.wav"):
        text = self.speech_to_text(input_audio)
        translated_text = self.translate_text(text)
        self.text_to_speech(translated_text, output_file=output_audio)
        return output_audio
