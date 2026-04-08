from pydantic import BaseModel
from typing import List, Optional

class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"

class LoginRequest(BaseModel):
    username: str
    password: str

class ChatRequest(BaseModel):
    messages: List[dict]
    tools: Optional[List[str]] = None
    max_tokens: int = 20000
    temperature: float = 0.2
    top_p: float = 0.95

class RAGIngestResponse(BaseModel):
    doc_id: str
    chunks: int

class RAGQueryRequest(BaseModel):
    query: str
    k: int = 5

class RAGAnswer(BaseModel):
    answer: str
    sources: List[dict]

class RewriteRequest(BaseModel):
    text: str
    style: str  # e.g., "concise", "formal", "reviewer-response"

class OutlineRequest(BaseModel):
    title: str
    aims: List[str]

class BibUploadResponse(BaseModel):
    entries: int

class CiteRequest(BaseModel):
    keys: List[str]
    style_path: Optional[str] = None
