from typing import List

OUTLINE_PROMPT = (
    "You are a senior scientist. Draft a rigorous outline for the manuscript titled '{title}'. "
    "Include Abstract bullets, Introduction structure, Methods (subsections), Results (figures/tables), "
    "Discussion (key arguments, limitations), and a concise Conclusion."
)

REWRITE_STYLES = {
    "concise": "Rewrite the text concisely and precisely, removing redundancy while preserving meaning.",
    "formal": "Rewrite in a formal, academic tone suitable for a high-impact journal.",
    "reviewer-response": (
        "Rewrite as a point-by-point reviewer response. Be respectful, cite evidence, and propose revisions."
    ),
    "latex": "Rewrite the text as well-structured LaTeX (no preamble), with clear sectioning and minimal packages."
}

def build_outline_messages(title: str, aims: List[str]):
    aims_bullets = "\n".join(f"- {a}" for a in aims)
    content = OUTLINE_PROMPT.format(title=title) + f"\nAims:\n{aims_bullets}"
    return [{"role": "system", "content": "You assist with scientific writing."}, {"role":"user", "content": content}]

def build_rewrite_messages(text: str, style: str):
    instruction = REWRITE_STYLES.get(style, REWRITE_STYLES["formal"])
    return [
        {"role": "system", "content": "You are an expert scientific editor."},
        {"role": "user", "content": f"Instruction: {instruction}\n\nText:\n{text}"}
    ]
