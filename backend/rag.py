import os, uuid, json
from typing import List, Tuple, Dict
import numpy as np
from pypdf import PdfReader
from sentence_transformers import SentenceTransformer
import faiss

INDEX_DIR = os.getenv("INDEX_DIR", "backend/storage/faiss_index")
UPLOAD_DIR = os.getenv("UPLOAD_DIR", "backend/storage/uploads")
EMBED_MODEL = os.getenv("EMBED_MODEL", "sentence-transformers/all-MiniLM-L6-v2")

os.makedirs(INDEX_DIR, exist_ok=True)
os.makedirs(UPLOAD_DIR, exist_ok=True)

_model = None

def _get_model():
    global _model
    if _model is None:
        _model = SentenceTransformer(EMBED_MODEL)
    return _model

def _chunk_text(text: str, chunk_size: int = 1200, overlap: int = 200) -> List[str]:
    words = text.split()
    chunks = []
    i = 0
    while i < len(words):
        chunk = words[i:i+chunk_size]
        chunks.append(" ".join(chunk))
        i += chunk_size - overlap
    return chunks

def ingest_pdf(path: str) -> Tuple[str, int]:
    reader = PdfReader(path)
    pages = [p.extract_text() or "" for p in reader.pages]
    text = "\n".join(pages)
    chunks = _chunk_text(text)

    model = _get_model()
    embeddings = model.encode(chunks, convert_to_numpy=True)

    dim = embeddings.shape[1]
    index_path = os.path.join(INDEX_DIR, "index.faiss")
    meta_path = os.path.join(INDEX_DIR, "meta.jsonl")

    if os.path.exists(index_path):
        index = faiss.read_index(index_path)
    else:
        index = faiss.IndexFlatIP(dim)

    faiss.normalize_L2(embeddings)
    index.add(embeddings)
    faiss.write_index(index, index_path)

    doc_id = str(uuid.uuid4())
    with open(meta_path, "a", encoding="utf-8") as f:
        for i, c in enumerate(chunks):
            f.write(json.dumps({"doc_id": doc_id, "chunk_id": i, "text": c, "source": os.path.basename(path)})+"\n")
    return doc_id, len(chunks)

def query(q: str, k: int = 5) -> List[Dict]:
    model = _get_model()
    emb = model.encode([q], convert_to_numpy=True)
    faiss.normalize_L2(emb)

    index_path = os.path.join(INDEX_DIR, "index.faiss")
    meta_path = os.path.join(INDEX_DIR, "meta.jsonl")

    if not os.path.exists(index_path) or not os.path.exists(meta_path):
        return []

    index = faiss.read_index(index_path)
    D, I = index.search(emb, k)

    metas = []
    with open(meta_path, "r", encoding="utf-8") as f:
        for line in f:
            metas.append(json.loads(line))

    hits = []
    for idx in I[0]:
        if idx < 0 or idx >= len(metas):
            continue
        m = metas[idx]
        hits.append({"text": m["text"], "source": m["source"], "doc_id": m["doc_id"], "chunk_id": m["chunk_id"]})
    return hits
