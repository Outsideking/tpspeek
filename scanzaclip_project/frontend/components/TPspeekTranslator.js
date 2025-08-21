import React, { useState } from 'react';

export default function TPspeekTranslator({ targetLang }) {
  const [text, setText] = useState('');
  const [translated, setTranslated] = useState('');

  const handleTextTranslate = async () => {
    const formData = new FormData();
    formData.append("text", text);
    formData.append("target_lang", targetLang);

    const resp = await fetch("/api/auto_translate_text/", {
      method: "POST",
      body: formData
    });
    const data = await resp.json();
    setTranslated(data.translated_text);
  };

  return (
    <div>
      <input value={text} onChange={e => setText(e.target.value)} placeholder="Type text" />
      <button onClick={handleTextTranslate}>Translate</button>
      <div>Translated: {translated}</div>
    </div>
  );
}
