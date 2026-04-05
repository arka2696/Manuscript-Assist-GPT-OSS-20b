import React, { useState, useRef, useEffect } from "react";
import { login, setToken, chat, chatReasoned, ragIngest, ragQuery, uploadBib, cite, streamLogs } from "./api";

export default function App() {
  const [username, setU] = useState("andrew");
  const [password, setP] = useState("password123");
  const [logged, setLogged] = useState(false);
  const [messages, setMessages] = useState<{role:string, content:string, image?:string}[]>([]);
  const [input, setInput] = useState("");
  const [ragAnswer, setRagAnswer] = useState("");
  const [bibInfo, setBibInfo] = useState("");
  const [reasoning, setReasoning] = useState<'low'|'medium'|'high'>('medium');
  const [visionImage, setVisionImage] = useState<File | null>(null);
  const [isGenerating, setIsGenerating] = useState(false);
  const [consoleLogs, setConsoleLogs] = useState({drafter: "", reviewer: "", router: ""});
  const [showConsole, setShowConsole] = useState(false);
  
  const fileInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (!isGenerating) return;
    const interval = setInterval(async () => {
      try {
        const logs = await streamLogs();
        setConsoleLogs(logs);
      } catch (err) {}
    }, 1000);
    return () => clearInterval(interval);
  }, [isGenerating]);

  const doLogin = async () => {
    const tok = await login(username, password);
    setToken(tok.access_token);
    setLogged(true);
  };

  const send = async (useReasoned=false) => {
    const msgs = [...messages, { role: "user", content: input, image: visionImage ? visionImage.name : undefined }];
    setMessages(msgs);
    setInput("");
    setVisionImage(null);
    setIsGenerating(true);
    setShowConsole(true);
    try {
      const reply = useReasoned ? await chatReasoned(msgs, reasoning) : await chat(msgs);
      setMessages([...msgs, { role: "assistant", content: reply }]);
    } catch (err) {
      setMessages([...msgs, { role: "assistant", content: "Error connecting to agents." }]);
    } finally {
      setIsGenerating(false);
    }
  };

  const attachImage = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files[0]) {
      setVisionImage(e.target.files[0]);
    }
  };

  const onUploadPDF = async (e: React.ChangeEvent<HTMLInputElement>) => {
    if (!e.target.files || !e.target.files[0]) return;
    const res = await ragIngest(e.target.files[0]);
    alert(`Document Ingested: ID ${res.doc_id} with ${res.chunks} chunks mapped.`);
  };

  const askRAG = async (q: string) => {
    const res = await ragQuery(q);
    setRagAnswer(res.answer);
  };

  const onUploadBib = async (e: React.ChangeEvent<HTMLInputElement>) => {
    if (!e.target.files || !e.target.files[0]) return;
    const res = await uploadBib(e.target.files[0]);
    setBibInfo(`Successfully loaded ${res.entries} references.`);
  };

  const doCite = async (keys: string) => {
    const out = await cite(keys.split(/\s*,\s*/));
    setBibInfo(out);
  };

  const styles = {
    font: { fontFamily: "'Inter', 'Roboto', 'Helvetica Neue', sans-serif" },
    btn: { background: "#fff", border: "1px solid #d1d5db", padding: "6px 12px", borderRadius: "6px", cursor: "pointer", fontSize: "14px", fontWeight: 500, color: "#374151" },
    btnPrimary: { background: "#1f2937", border: "1px solid #111827", padding: "6px 12px", borderRadius: "6px", cursor: "pointer", fontSize: "14px", fontWeight: 500, color: "#f9fafb" },
    input: { padding: "8px 12px", border: "1px solid #d1d5db", borderRadius: "6px", fontSize: "14px", width: "100%", boxSizing: "border-box" as const },
    panel: { backgroundColor: "#fff", border: "1px solid #e5e7eb", borderRadius: "8px", padding: "20px", boxShadow: "0 1px 2px 0 rgba(0, 0, 0, 0.05)" },
  };

  if (!logged) {
    return (
      <div style={{ ...styles.font, display: "flex", justifyContent: "center", alignItems: "center", height: "100vh", backgroundColor: "#f9fafb" }}>
        <div style={{ ...styles.panel, width: "400px" }}>
          <h1 style={{ fontSize: "20px", margin: "0 0 8px 0", color: "#111827" }}>Manuscript Assistant</h1>
          <p style={{ color: "#6b7280", fontSize: "14px", marginBottom: "24px" }}>Secure Lab Login</p>
          <div style={{ display: "flex", flexDirection: "column", gap: "12px" }}>
            <input style={styles.input} placeholder="Username" value={username} onChange={e=>setU(e.target.value)} />
            <input style={styles.input} placeholder="Password" type="password" value={password} onChange={e=>setP(e.target.value)} />
            <button style={{ ...styles.btnPrimary, marginTop: "8px" }} onClick={doLogin}>Authenticate</button>
          </div>
        </div>
      </div>
    );
  }

  return (
    <div style={{ ...styles.font, backgroundColor: "#f9fafb", minHeight: "100vh", padding: "32px", color: "#111827" }}>
      <div style={{ maxWidth: "1200px", margin: "0 auto", display: "grid", gridTemplateColumns: "1fr 340px", gap: "24px" }}>
        
        {/* Left Column - Main Workspace */}
        <div style={{ display: "flex", flexDirection: "column", gap: "24px" }}>
          <div style={styles.panel}>
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "16px" }}>
              <h2 style={{ fontSize: "18px", margin: 0, fontWeight: 600 }}>Multi-Agent Workspace</h2>
              <div style={{ display: "flex", gap: "8px", alignItems: "center" }}>
                <span style={{ fontSize: "14px", color: "#6b7280" }}>Routing Loop:</span>
                <select style={{ ...styles.input, width: "auto", padding: "4px 8px" }} value={reasoning} onChange={e=>setReasoning(e.target.value as any)}>
                  <option value="low">Standard</option>
                  <option value="medium">Rigorous</option>
                  <option value="high">Peer-Review Level</option>
                </select>
              </div>
            </div>
            
            <div style={{ border: "1px solid #e5e7eb", backgroundColor: "#f3f4f6", borderRadius: "6px", padding: "16px", minHeight: "400px", marginBottom: "16px", overflowY: "auto" }}>
              {messages.length === 0 && <p style={{ color: "#9ca3af", textAlign: "center", marginTop: "150px" }}>Start drafting your manuscript or querying your index.</p>}
              {messages.map((m, i) => (
                <div key={i} style={{ marginBottom: "16px", padding: "12px", backgroundColor: "#fff", borderRadius: "6px", border: "1px solid #e5e7eb" }}>
                  <b style={{ color: m.role === "assistant" ? "#1f2937" : "#4b5563", fontSize: "13px", textTransform: "uppercase" }}>{m.role === 'assistant' ? 'Agent Node' : 'You'}</b>
                  <div style={{ marginTop: "4px", fontSize: "15px", lineHeight: "1.6" }}>{m.content}</div>
                  {m.image && <div style={{ marginTop: "8px", fontSize: "12px", color: "#6b7280" }}>📎 Attached: {m.image}</div>}
                </div>
              ))}
            </div>

            <div style={{ display: "flex", flexDirection: "column", gap: "8px" }}>
              <textarea style={{ ...styles.input, minHeight: "80px", resize: "vertical" }} value={input} onChange={(e)=>setInput(e.target.value)} placeholder="E.g., 'Draft the methods section based on my RAG index.'" />
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
                <div style={{ display: "flex", alignItems: "center", gap: "8px" }}>
                  <button style={styles.btn} onClick={() => fileInputRef.current?.click()}>
                    📎 {visionImage ? visionImage.name : "Attach Image"}
                  </button>
                  <input type="file" accept="image/*" ref={fileInputRef} style={{ display: "none" }} onChange={attachImage} />
                  {visionImage && <button style={{ ...styles.btn, border: 'none', color: '#ef4444' }} onClick={() => setVisionImage(null)}>✕</button>}
                </div>
                <div style={{ display: "flex", gap: "8px" }}>
                  <button style={styles.btn} onClick={() => send(false)} disabled={isGenerating}>
                    {isGenerating ? "Processing..." : "Submit"}
                  </button>
                  <button style={{...styles.btnPrimary, opacity: isGenerating ? 0.7 : 1}} onClick={() => send(true)} disabled={isGenerating}>
                    {isGenerating ? "Processing..." : "Submit & Review"}
                  </button>
                </div>
              </div>
              
              {showConsole && (
                <div style={{ marginTop: "16px", backgroundColor: "#0f172a", color: "#10b981", padding: "16px", borderRadius: "6px", fontFamily: "monospace", fontSize: "11px", maxHeight: "250px", overflowY: "auto", position: "relative", boxShadow: "inset 0 2px 4px 0 rgb(0 0 0 / 0.05)" }}>
                  <div style={{ position: "absolute", top: "8px", right: "8px", display: "flex", gap: "8px" }}>
                    {isGenerating && <span style={{ color: "#fbbf24" }}>● Live Hardware Stream</span>}
                    <button style={{ background: "none", border: "none", color: "#9ca3af", cursor: "pointer", fontSize: "14px" }} onClick={() => setShowConsole(false)}>✕</button>
                  </div>
                  <div style={{ marginBottom: "8px", color: "#60a5fa", fontWeight: "bold", borderBottom: "1px solid #1e293b", paddingBottom: "4px" }}>&gt; DRAFTER LOG (PORT 8001):</div>
                  <pre style={{ margin: 0, whiteSpace: "pre-wrap", opacity: 0.8 }}>{consoleLogs.drafter || "Waiting for signal..."}</pre>
                  <div style={{ marginTop: "16px", marginBottom: "8px", color: "#f87171", fontWeight: "bold", borderBottom: "1px solid #1e293b", paddingBottom: "4px" }}>&gt; REVIEWER LOG (PORT 8002):</div>
                  <pre style={{ margin: 0, whiteSpace: "pre-wrap", opacity: 0.8 }}>{consoleLogs.reviewer || "Waiting for signal..."}</pre>
                </div>
              )}

            </div>
          </div>
        </div>

        {/* Right Column - Lab Tools */}
        <div style={{ display: "flex", flexDirection: "column", gap: "16px" }}>
          
          <div style={styles.panel}>
            <h3 style={{ fontSize: "16px", margin: "0 0 12px 0" }}>Document Context (RAG)</h3>
            <div style={{ marginBottom: "16px" }}>
              <p style={{ fontSize: "13px", color: "#6b7280", margin: "0 0 8px 0" }}>Upload PDFs to local FAISS index.</p>
              <input type="file" accept="application/pdf" onChange={onUploadPDF} style={{ fontSize: "13px", width: "100%" }} />
            </div>
            <div style={{ borderTop: "1px solid #e5e7eb", paddingTop: "12px" }}>
              <p style={{ fontSize: "13px", color: "#6b7280", margin: "0 0 8px 0" }}>Direct Query Test</p>
              <input style={styles.input} placeholder="Probe index..." onKeyDown={async (e:any)=>{ if(e.key==='Enter'){ await askRAG(e.target.value); e.target.value=''; }}} />
              {ragAnswer && <div style={{ fontSize: "13px", marginTop: "8px", padding: "8px", backgroundColor: "#f3f4f6", borderRadius: "4px" }}>{ragAnswer}</div>}
            </div>
          </div>

          <div style={styles.panel}>
            <h3 style={{ fontSize: "16px", margin: "0 0 12px 0" }}>Citations & References</h3>
            <div style={{ marginBottom: "16px" }}>
               <p style={{ fontSize: "13px", color: "#6b7280", margin: "0 0 8px 0" }}>Upload BibTeX library (.bib)</p>
               <input type="file" accept=".bib" onChange={onUploadBib} style={{ fontSize: "13px", width: "100%" }} />
               {bibInfo && !bibInfo.includes("Formatted") && <div style={{ fontSize: "12px", color: "#10b981", marginTop: "4px" }}>{bibInfo}</div>}
            </div>
            <div style={{ borderTop: "1px solid #e5e7eb", paddingTop: "12px" }}>
              <p style={{ fontSize: "13px", color: "#6b7280", margin: "0 0 8px 0" }}>Generate CSL Formatted Output</p>
              <input style={styles.input} placeholder="cite_key1, cite_key2" onKeyDown={async (e:any)=>{ if(e.key==='Enter'){ await doCite(e.target.value); e.target.value=''; }}} />
              {bibInfo && bibInfo.includes("Formatted") && <div style={{ fontSize: "13px", marginTop: "8px", padding: "8px", backgroundColor: "#f3f4f6", borderRadius: "4px", borderLeft: "2px solid #6b7280" }}>{bibInfo}</div>}
            </div>
          </div>

        </div>
      </div>
    </div>
  );
}

