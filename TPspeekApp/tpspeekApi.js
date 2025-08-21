const API_KEY = 'YOUR_API_KEY';
const BASE_URL = 'http://<SERVER_IP>:8000';

export async function translateText(text, sourceLang, targetLang) {
  const resp = await fetch(`${BASE_URL}/translate`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${API_KEY}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ text, source_lang: sourceLang, target_lang: targetLang })
  });
  const data = await resp.json();
  return data.translated_text;
}

export async function detectLanguage(text) {
  const resp = await fetch(`${BASE_URL}/detect`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${API_KEY}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ text })
  });
  return await resp.json(); // { language_code: 'th' }
}
