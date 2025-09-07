import os, httpx
from typing import List, Dict, Optional

VLLM_ENDPOINT = os.getenv("VLLM_ENDPOINT", "http://127.0.0.1:8001/v1")
MODEL_NAME = os.getenv("MODEL_NAME", "openai/gpt-oss-20b")
DEFAULT_MAX_TOKENS = int(os.getenv("MAX_TOKENS", "1024"))
DEFAULT_TEMPERATURE = float(os.getenv("TEMPERATURE", "0.2"))
DEFAULT_TOP_P = float(os.getenv("TOP_P", "0.95"))
DEFAULT_REASONING = os.getenv("REASONING_LEVEL", "medium")  # low|medium|high

async def chat(messages: List[Dict], max_tokens: int = DEFAULT_MAX_TOKENS,
               temperature: float = DEFAULT_TEMPERATURE, top_p: float = DEFAULT_TOP_P,
               reasoning_level: Optional[str] = None) -> str:
    preamble = {"role": "system", "content": f"Use harmony response format. Reasoning: {reasoning_level or DEFAULT_REASONING}."}
    mm = [preamble] + messages
    payload = {
        "model": MODEL_NAME,
        "messages": mm,
        "temperature": temperature,
        "top_p": top_p,
        "max_tokens": max_tokens,
        "stream": False,
    }
    async with httpx.AsyncClient(timeout=None) as client:
        r = await client.post(f"{VLLM_ENDPOINT}/chat/completions", json=payload)
        r.raise_for_status()
        data = r.json()
        return data["choices"][0]["message"]["content"]
