#!/usr/bin/env python3
"""Mock Mem0 Server for UI Demo"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
import uvicorn

app = FastAPI(title="Aura Mock Server")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mock data
MOCK_MEMORIES = [
    {
        "id": "1",
        "content": "The key insight from today's meeting is that we need to pivot our approach to focus on the enterprise market rather than SMBs. The data shows that enterprise customers have a 3x higher LTV and significantly lower churn rates.",
        "timestamp": "2026-02-19T14:34:00",
        "metadata": {"context": "Product Strategy Notes", "category": "work"}
    },
    {
        "id": "2", 
        "content": "Good design is actually a lot harder to notice than poor design, in part because good designs fit our needs so well that the design is invisible. Three key principles: Visibility, Feedback, and Constraints.",
        "timestamp": "2026-02-19T10:15:00",
        "metadata": {"context": "Design of Everyday Things", "category": "reading"}
    },
    {
        "id": "3",
        "content": "const useAsync = (asyncFunction, immediate = true) => { const [status, setStatus] = useState('idle'); const [value, setValue] = useState(null); const [error, setError] = useState(null); // ... }",
        "timestamp": "2026-02-19T08:42:00",
        "metadata": {"context": "React Hook Pattern", "category": "code"}
    },
    {
        "id": "4",
        "content": "Meeting with the team about Q4 planning. Key decisions: 1) Launch new feature by Nov 15, 2) Increase marketing budget by 40%, 3) Hire 3 new engineers.",
        "timestamp": "2026-02-18T16:30:00",
        "metadata": {"context": "Q4 Planning", "category": "meeting"}
    }
]

class ChatRequest(BaseModel):
    message: str

class Config(BaseModel):
    capture_enabled: bool = True
    capture_interval: int = 30

@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/memories")
def get_memories(limit: int = 20):
    return MOCK_MEMORIES[:limit]

@app.post("/chat")
def chat(request: ChatRequest):
    responses = [
        "Based on your recent activity, you've been working on product strategy and design research. Would you like me to summarize your key insights?",
        "I see you've captured several code snippets related to React hooks. These might be useful for your current project.",
        "Your meeting notes show you're planning a pivot to enterprise. I've identified 3 key action items from your recent notes."
    ]
    import random
    return {"response": random.choice(responses)}

@app.get("/config")
def get_config():
    return {
        "capture": {
            "enabled": True,
            "interval_seconds": 30,
            "quality": 60
        },
        "app": {
            "memory_window": 10
        }
    }

@app.post("/config")
def update_config(config: Config):
    return {"status": "updated"}

@app.post("/capture/toggle")
def toggle_capture(enabled: bool):
    return {"enabled": enabled}

if __name__ == "__main__":
    print("=" * 60)
    print(" Aura Mock Server Starting...")
    print("=" * 60)
    print("\nServer running at: http://localhost:8000")
    print("The UI should now connect successfully!\n")
    uvicorn.run(app, host="0.0.0.0", port=8000)
