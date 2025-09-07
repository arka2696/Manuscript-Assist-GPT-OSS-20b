import os
from fastapi import FastAPI, UploadFile, File, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from typing import Optional

from .schemas import *
from .auth import create_token, verify_password, require_auth
from .llm_client import chat as llm_chat
from .rag import ingest_pdf, query as rag_query
from .refs import load_bibtex, cite
from .tools import build_outline_messages, build_rewrite_messages

app = FastAPI(title="Manuscript Assistant")

origins = ["*"]  # tighten in prod
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.post("/login", response_model=Token)
async def login(req: LoginRequest):
    if not verify_password(req.username, req.password):
        raise HTTPException(status_code=401, detail="Invalid credentials")
    token = create_token(req.username)
    return Token(access_token=token)

@app.post("/chat")
async def chat(req: ChatRequest, user=Depends(require_auth)):
    content = await llm_chat(req.messages, max_tokens=req.max_tokens, temperature=req.temperature, top_p=req.top_p)
    return {"content": content}

@app.post("/chat/reasoned")
async def chat_reasoned(req: ChatRequest, reasoning_level: Optional[str] = "medium", user=Depends(require_auth)):
    content = await llm_chat(req.messages, max_tokens=req.max_tokens, temperature=req.temperature, top_p=req.top_p, reasoning_level=reasoning_level)
    return {"content": content}

@app.post("/rag/ingest", response_model=RAGIngestResponse)
async def rag_ingest(file: UploadFile = File(...), user=Depends(require_auth)):
    os.makedirs(os.getenv("UPLOAD_DIR", "backend/storage/uploads"), exist_ok=True)
    path = os.path.join(os.getenv("UPLOAD_DIR", "backend/storage/uploads"), file.filename)
    with open(path, "wb") as f:
        f.write(await file.read())
    doc_id, chunks = ingest_pdf(path)
    return RAGIngestResponse(doc_id=doc_id, chunks=chunks)

@app.post("/rag/query", response_model=RAGAnswer)
async def rag_query_api(req: RAGQueryRequest, user=Depends(require_auth)):
    hits = rag_query(req.query, k=req.k)
    context = "\n\n".join(f"[Source: {h['source']} p{h['chunk_id']}] {h['text']}" for h in hits)
    messages = [
        {"role":"system","content":"Use harmony format. Answer precisely. Cite sources as [source p#]."},
        {"role":"user","content": f"Question: {req.query}\n\nContext:\n{context}"}
    ]
    answer = await llm_chat(messages)
    return RAGAnswer(answer=answer, sources=hits)

@app.post("/tools/outline")
async def outline(req: OutlineRequest, user=Depends(require_auth)):
    messages = build_outline_messages(req.title, req.aims)
    result = await llm_chat(messages)
    return {"outline": result}

@app.post("/tools/rewrite")
async def rewrite(req: RewriteRequest, user=Depends(require_auth)):
    messages = build_rewrite_messages(req.text, req.style)
    result = await llm_chat(messages)
    return {"rewritten": result}

@app.post("/refs/upload", response_model=BibUploadResponse)
async def refs_upload(file: UploadFile = File(...), user=Depends(require_auth)):
    text = (await file.read()).decode("utf-8")
    n = load_bibtex(text)
    return BibUploadResponse(entries=n)

@app.post("/refs/cite")
async def refs_cite(req: CiteRequest, user=Depends(require_auth)):
    out = cite(req.keys, style_path=req.style_path or os.getenv("CSL_STYLE"))
    return {"bibliography": out}

@app.get("/health")
async def health():
    return {"status": "ok"}
