import os
import openai
openai.api_key = os.getenv('OPENAI_API_KEY')

# Simple wrapper using OpenAI for translation. For high-volume or offline, replace with self-hosted model.
def translate_text(text: str, source_lang: str, target_lang: str) -> str:
    prompt = f"Translate the following text from {source_lang} to {target_lang}:\n\n{text}"
    resp = openai.ChatCompletion.create(
        model="gpt-4o-mini",
        messages=[{"role":"user","content":prompt}],
        max_tokens=2000,
        temperature=0.0,
    )
    return resp.choices[0].message['content'].strip()
