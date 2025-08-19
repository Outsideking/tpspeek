import os, openai
openai.api_key = os.getenv("OPENAI_API_KEY")

def translate_text(text: str, source_lang: str, target_lang: str) -> str:
    response = openai.ChatCompletion.create(
        model="gpt-4o-mini",
        messages=[{"role":"user","content":f"Translate from {source_lang} to {target_lang}: {text}"}]
    )
    return response.choices[0].message['content']
