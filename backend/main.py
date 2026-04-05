import os
from fastapi import FastAPI, UploadFile, File, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from typing import Optional

from .schemas import *
from .auth import create_token, verify_password, require_auth
from .llm_client import chat_agent
from .rag import ingest_pdf, query as rag_query
from .refs import load_bibtex, cite
from .tools import build_outline_messages, build_rewrite_messages
from .agents import manuscript_graph, AgentState

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
    initial_state = {"messages": req.messages, "revision_count": 0, "status": "", "feedback": ""}
    # Await the langgraph cyclic execution
    final_state = await manuscript_graph.ainvoke(initial_state)
    # Extract the final message content produced by the Drafter (after potential Reviewer loops)
    final_content = final_state["messages"][-1]["content"] if final_state["messages"] else "Error in processing."
    return {"content": final_content}

@app.post("/chat/reasoned")
async def chat_reasoned(req: ChatRequest, reasoning_level: Optional[str] = "medium", user=Depends(require_auth)):
    # The reasoning levels will dictate which models are hit if the Router was set up for it.
    initial_state = {"messages": req.messages, "revision_count": 0, "status": "", "feedback": ""}
    final_state = await manuscript_graph.ainvoke(initial_state)
    final_content = final_state["messages"][-1]["content"] if final_state["messages"] else "Error in processing."
    return {"content": final_content}

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
    answer = await chat_agent(role="drafter", messages=messages)
    return RAGAnswer(answer=answer, sources=hits)

@app.post("/tools/outline")
async def outline(req: OutlineRequest, user=Depends(require_auth)):
    messages = build_outline_messages(req.title, req.aims)
    result = await chat_agent(role="router", messages=messages)
    return {"outline": result}

@app.post("/tools/rewrite")
async def rewrite(req: RewriteRequest, user=Depends(require_auth)):
    messages = build_rewrite_messages(req.text, req.style)
    result = await chat_agent(role="drafter", messages=messages)
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

@app.get("/logs/stream")
async def get_logs_stream(user=Depends(require_auth)):
    # Safely tail the ends of the hardware logs for the new UI component
    def read_tail(filepath, lines=20):
        try:
            with open(filepath, "r", encoding="utf-8", errors="replace") as f:
                f.seek(0, os.SEEK_END)
                pos = f.tell()
                f.seek(max(0, pos - 4096))
                lines_list = f.readlines()
                return "".join(lines_list[-lines:])
        except Exception:
            return "Log file buffering or not found..."
    
    return {
        "drafter": read_tail("slurm_logs/drafter.log", 15),
        "reviewer": read_tail("slurm_logs/reviewer.log", 15),
        "router": read_tail("slurm_logs/router.log", 15)
    }
