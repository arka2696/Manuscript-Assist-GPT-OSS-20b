import asyncio
import httpx
import os
import glob
from datetime import datetime

# URLs and Config
LLAMA_SERVER_URL = "http://127.0.0.1:8001/chat/completions"
WORKSPACE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "batch_workspace"))
INPUT_DRAFT_DIR = os.path.join(WORKSPACE_DIR, "input", "draft")
INPUT_FIGURES_DIR = os.path.join(WORKSPACE_DIR, "input", "figures")
INSTRUCTIONS_FILE = os.path.join(WORKSPACE_DIR, "input", "instructions.txt")
OUTPUT_DIR = os.path.join(WORKSPACE_DIR, "output")

# We use an extreme timeout for Batch Mode (30 minutes) 
# because writing 10,000 words on an A100/H200 takes significant time.
TIMEOUT_SECONDS = 1800.0  

def read_text_files(directory):
    """Concatenate all .txt files in a given directory."""
    content = ""
    if not os.path.exists(directory):
        return content
        
    for filepath in sorted(glob.glob(os.path.join(directory, "*.txt"))):
        with open(filepath, 'r', encoding='utf-8') as f:
            content += f"\n\n--- Content from {os.path.basename(filepath)} ---\n"
            content += f.read()
    return content

async def run_batch():
    print(f"[*] Starting Headless Batch Generator")
    print(f"[*] Scanning workspace: {WORKSPACE_DIR}")
    
    # 1. Gather Inputs
    draft_content = read_text_files(INPUT_DRAFT_DIR)
    figure_content = read_text_files(INPUT_FIGURES_DIR)
    
    instructions = ""
    if os.path.exists(INSTRUCTIONS_FILE):
        with open(INSTRUCTIONS_FILE, 'r', encoding='utf-8') as f:
            instructions = f.read()
            
    if not draft_content and not figure_content:
        print("[!] Error: No draft or figure text files found in the input directories.")
        return

    print("[*] Successfully read inputs. Assembling prompt matrix...")

    # 2. Assemble Master Prompt
    system_prompt = (
        "You are a world-class scientific researcher and author. "
        "Your task is to extract information from the provided manuscript draft and figure descriptions, "
        "and meticulously execute the user's instructions to generate publication-quality scientific writing."
    )
    
    user_prompt = f"""
[SOURCE DRAFT]
{draft_content}

[FIGURE DESCRIPTIONS]
{figure_content}

[USER INSTRUCTIONS]
{instructions}
"""

    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_prompt}
    ]
    
    payload = {
        "model": "default",
        "messages": messages,
        "temperature": 0.3, # Low temperature for scientific accuracy
        "max_tokens": 100000,
        "stream": False,
    }

    print(f"[*] Sending payload to GLM-5 Engine (Timeout set to 30 mins)...")
    
    try:
        async with httpx.AsyncClient(timeout=TIMEOUT_SECONDS) as client:
            response = await client.post(LLAMA_SERVER_URL, json=payload)
            response.raise_for_status()
            
            data = response.json()
            generated_text = data["choices"][0]["message"]["content"]
            
            # 3. Save Output
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            output_filename = os.path.join(OUTPUT_DIR, f"GLM5_Manuscript_{timestamp}.md")
            
            with open(output_filename, "w", encoding="utf-8") as f:
                f.write("# Generated Output\n\n")
                f.write(generated_text)
                
            print(f"[SUCCESS] Manuscript successfully generated and saved to:")
            print(f"    -> {output_filename}")

    except httpx.ConnectError:
        print("[!] Error: Could not connect to the llama-server. Is it running on port 8001?")
    except httpx.TimeoutException:
        print("[!] Error: The server took too long to respond. The generation might be too massive.")
    except Exception as e:
        print(f"[!] An unexpected error occurred: {e}")

if __name__ == "__main__":
    asyncio.run(run_batch())
