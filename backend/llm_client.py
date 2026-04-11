import os, httpx
from typing import List, Dict, Optional

# Multiple llama.cpp endpoints according to our NUMA architecture
AGENT_ENDPOINTS = {
    "drafter": os.getenv("DRAFTER_ENDPOINT", "http://127.0.0.1:8001/v1"),
    "reviewer": os.getenv("REVIEWER_ENDPOINT", "http://127.0.0.1:8002/v1"),
    "router": os.getenv("ROUTER_ENDPOINT", "http://127.0.0.1:8003/v1"),
    "vision": os.getenv("VISION_ENDPOINT", "http://127.0.0.1:8004/v1"),
}

NANOBANA_API_KEY = os.getenv("NANOBANA_API_KEY")
DEFAULT_MAX_TOKENS = int(os.getenv("MAX_TOKENS", "20000"))
DEFAULT_TEMPERATURE = float(os.getenv("TEMPERATURE", "0.2"))

async def chat_agent(role: str, messages: List[Dict], max_tokens: int = DEFAULT_MAX_TOKENS,
               temperature: float = DEFAULT_TEMPERATURE, model_override: str = "default") -> str:
    
    endpoint = AGENT_ENDPOINTS.get(role, AGENT_ENDPOINTS["router"])
    
    # Handle Nanobana fallback for vision tasks if the local vision model isn't active/supplied
    if role == "vision" and NANOBANA_API_KEY and "127.0.0.1" in endpoint:
        try:
            # Check if local vision is active, otherwise hit nanobana
            async with httpx.AsyncClient(timeout=2) as check_client:
                await check_client.get(f"{endpoint}/models")
        except httpx.ConnectError:
            endpoint = "https://api.nanobana.dev/v1" # example API structure
            
    headers = {}
    if "nanobana" in endpoint:
        headers["Authorization"] = f"Bearer {NANOBANA_API_KEY}"
        
    payload = {
        "model": model_override, # llama.cpp uses the loaded model automatically if 'default'
        "messages": messages,
        "temperature": temperature,
        "max_tokens": max_tokens,
        "stream": False,
    }
    
    async with httpx.AsyncClient(timeout=None) as client:
        r = await client.post(f"{endpoint}/chat/completions", json=payload, headers=headers)
        r.raise_for_status()
        data = r.json()
        return data["choices"][0]["message"]["content"]
