import React, { useState } from "react";
import { login, setToken, chat, chatReasoned, ragIngest, ragQuery, uploadBib, cite } from "./api";

export default function App() {
  const [username, setU] = useState("andrew");
  const [password, setP] = useState("password123");
  const [logged, setLogged] = useState(false);
  const [messages, setMessages] = useState<{role:string, content:string}[]>([]);
  const [input, setInput] = useState("");
  const [ragAnswer, setRagAnswer] = useState("");
  const [bibInfo, setBibInfo] = useState("");
  const [reasoning, setReasoning] = useState<'low'|'medium'|'high'>('medium');

  const doLogin = async () => {
    const tok = await login(username, password);
    setToken(tok.access_token);
    setLogged(true);
  };

  const send = async (useReasoned=false) => {
    const msgs = [...messages, { role: "user", content: input }];
    setMessages(msgs);
    const reply = useReasoned ? await chatReasoned(msgs, reasoning) : await chat(msgs);
    setMessages([...msgs, { role: "assistant", content: reply }]);
    setInput("");
  };

  const onUploadPDF = async (e: React.ChangeEvent<HTMLInputElement>) => {
    if (!e.target.files || !e.target.files[0]) return;
    const res = await ragIngest(e.target.files[0]);
    alert(`Ingested: ${res.doc_id} (chunks: ${res.chunks})`);
  };

  const askRAG = async (q: string) => {
    const res = await ragQuery(q);
    setRagAnswer(res.answer);
  };

  const onUploadBib = async (e: React.ChangeEvent<HTMLInputElement>) => {
    if (!e.target.files || !e.target.files[0]) return;
    const res = await uploadBib(e.target.files[0]);
    setBibInfo(`Loaded ${res.entries} references.`);
  };

  const doCite = async (keys: string) => {
    const out = await cite(keys.split(/\s*,\s*/));
    setBibInfo(out);
  };

  if (!logged) {
    return (
      <div style={{ maxWidth: 480, margin: "40px auto", fontFamily: "ui-sans-serif" }}>
        <h1>Manuscript Assistant</h1>
        <p>Login (demo creds prefilled)</p>
        <input placeholder="username" value={username} onChange={e=>setU(e.target.value)} />
        <input placeholder="password" type="password" value={password} onChange={e=>setP(e.target.value)} />
        <button onClick={doLogin}>Login</button>
      </div>
    );
  }

  return (
    <div style={{ display: "grid", gridTemplateColumns: "1fr 340px", gap: 16, padding: 16, fontFamily: "ui-sans-serif" }}>
      <div>
        <h2>Chat</h2>
        <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
          <label>Reasoning:</label>
          <select value={reasoning} onChange={e=>setReasoning(e.target.value as any)}>
            <option value="low">low</option>
            <option value="medium">medium</option>
            <option value="high">high</option>
          </select>
          <button onClick={() => send(false)}>Send (fast)</button>
          <button onClick={() => send(true)}>Send (reasoned)</button>
        </div>
        <div style={{ border: "1px solid #ddd", borderRadius: 8, padding: 12, minHeight: 320, marginTop: 8 }}>
          {messages.map((m, i) => (
            <div key={i} style={{ marginBottom: 8 }}>
              <b>{m.role}:</b> {m.content}
            </div>
          ))}
        </div>
        <div style={{ marginTop: 8 }}>
          <textarea value={input} onChange={(e)=>setInput(e.target.value)} rows={4} style={{ width: "100%" }} />
        </div>

        <h2 style={{ marginTop: 24 }}>RAG Ask</h2>
        <div>
          <input placeholder="Ask with your PDFs as context" onKeyDown={async (e:any)=>{ if(e.key==='Enter'){ await askRAG(e.target.value); e.target.value=''; }}} />
          <div style={{ whiteSpace: "pre-wrap", marginTop: 8 }}>{ragAnswer}</div>
        </div>
      </div>

      <div>
        <h3>Tools</h3>
        <div style={{ border: "1px solid #eee", padding: 8, borderRadius: 8 }}>
          <h4>Upload PDF</h4>
          <input type="file" accept="application/pdf" onChange={onUploadPDF} />
        </div>
        <div style={{ border: "1px solid #eee", padding: 8, borderRadius: 8, marginTop: 8 }}>
          <h4>Upload BibTeX</h4>
          <input type="file" accept=".bib" onChange={onUploadBib} />
          <div style={{ whiteSpace: "pre-wrap", marginTop: 8 }}>{bibInfo}</div>
          <input placeholder="cite keys, comma-separated" onKeyDown={async (e:any)=>{ if(e.key==='Enter'){ await doCite(e.target.value); e.target.value=''; }}} />
        </div>
      </div>
    </div>
  );
}
