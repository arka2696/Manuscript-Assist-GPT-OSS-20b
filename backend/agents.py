from typing import TypedDict, List, Dict, Annotated, Any
import operator
from langgraph.graph import StateGraph, END
from .llm_client import chat_agent

class AgentState(TypedDict):
    messages: Annotated[List[Dict[str, Any]], operator.add]
    revision_count: int
    feedback: str
    vision_analysis: str
    status: str

async def vision_node(state: AgentState):
    """Placeholder node to intercept vision requests and process images."""
    # Process any attached image in the messages using the Vision Agent
    # For now, if no image is present, we pass through
    messages = state["messages"]
    has_image = False
    
    # In a real implementation, we'd look for an image embedded in the messages here,
    # send it to `chat_agent(role="vision", ...)`, and inject the analysis.
    
    analysis = "No vision payload detected in this iteration."
    if has_image:
        analysis = await chat_agent(role="vision", messages=messages)
        
    return {"vision_analysis": analysis}

async def drafter_node(state: AgentState):
    """The Drafter Agent takes instructions (and feedback) and generates scientific text."""
    sys_msg = {"role": "system", "content": "You are a professional scientific writer. Write accurately."}
    
    # Flatten the user history to prevent Gemma-4 multi-turn template errors
    user_history = "\\n".join([m["content"] for m in state["messages"] if m["role"] == "user"])
    if state.get("feedback"):
        user_history += f"\\n\\nReviewer Feedback: Please revise the draft based strictly on this critique: {state['feedback']}"
        
    response = await chat_agent(role="drafter", messages=[sys_msg, {"role": "user", "content": user_history}])
    
    # Strip <think> tags from the final saved message if present to keep the UI clean
    clean_response = response.split("</think>")[-1].strip() if "</think>" in response else response
    
    return {"messages": [{"role": "assistant", "content": clean_response, "name": "drafter"}], 
            "revision_count": state.get("revision_count", 0) + 1}

async def reviewer_node(state: AgentState):
    """The Reviewer Agent analyzes the Drafter's output for quality/citations."""
    latest_draft = state["messages"][-1]["content"] if state["messages"] else ""
    
    prompt = f"Critique this scientific draft. If it is excellent, reply 'APPROVE'. If it needs changes, list the changes. Draft: {latest_draft}"
    response = await chat_agent(role="reviewer", messages=[{"role": "user", "content": prompt}])
    
    status = "approved" if "APPROVE" in response else "revise"
    return {"feedback": response, "status": status}

def router_logic(state: AgentState) -> str:
    if state["status"] == "approved" or state["revision_count"] >= 3:
        return END
    return "drafter"
    
def build_manuscript_graph():
    builder = StateGraph(AgentState)
    builder.add_node("vision", vision_node)
    builder.add_node("drafter", drafter_node)
    builder.add_node("reviewer", reviewer_node)
    
    builder.set_entry_point("vision")
    builder.add_edge("vision", "drafter")
    builder.add_edge("drafter", "reviewer")
    builder.add_conditional_edges("reviewer", router_logic, {END: END, "drafter": "drafter"})
    
    return builder.compile()

# Initialize the global graph
manuscript_graph = build_manuscript_graph()
