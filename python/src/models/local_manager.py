import sys
from typing import List, Dict, Any
from pathlib import Path
from config import MODELS_DIR

class LocalModelManager:
    """Manages local model loading and inference."""
    
    def __init__(self):
        self.embedding_model = None
        self.embedding_tokenizer = None
        self.llm_model = None
        self.llm_processor = None
        self.device = "cpu"
        
        try:
            import torch
            if torch.cuda.is_available():
                self.device = "cuda"
                print(f"[OK] Using CUDA for GPU acceleration")
            else:
                print(f"[INFO] Using CPU for inference")
        except ImportError:
            pass
    
    def load_embedding_model(self):
        from transformers import AutoTokenizer, AutoModel
        import torch
        
        model_path = MODELS_DIR / "embeddinggemma-300m-f8"
        
        if not model_path.exists():
            print(f"[ERROR] Embedding model not found at {model_path}")
            print("[INFO] Running automatic setup...")
            setup_script = Path(__file__).parent.parent.parent.parent.parent / "scripts" / "auto_setup.py"
            if setup_script.exists():
                import subprocess
                result = subprocess.run([sys.executable, str(setup_script)])
                if result.returncode != 0:
                    print("[ERROR] Automatic setup failed. Please run manually:")
                    sys.exit(1)
                if not model_path.exists():
                    print("[ERROR] Model still not found after setup.")
                    sys.exit(1)
            else:
                print("[INFO] Please run: python scripts/download_models.py")
                sys.exit(1)
        
        if self.device != "cuda":
            print("[ERROR] GPU is required for embedding model (google/embeddinggemma-300m-f8)")
            sys.exit(1)
        
        print(f"[INFO] Loading Google Embedding Gemma 300M FP8 model...")
        
        self.embedding_tokenizer = AutoTokenizer.from_pretrained(
            model_path, trust_remote_code=True, local_files_only=True
        )
        self.embedding_model = AutoModel.from_pretrained(
            model_path, trust_remote_code=True, local_files_only=True,
            torch_dtype=torch.float16,
            device_map="auto"
        )
        self.embedding_model.to(self.device)
        self.embedding_model.eval()
        
        print(f"[OK] Embedding model loaded")
    
    def load_llm_model(self):
        from transformers import AutoProcessor, AutoModelForVision2Seq
        
        model_path = MODELS_DIR / "lfm-2-vision-450m"
        
        if not model_path.exists():
            print(f"[ERROR] LLM model not found at {model_path}")
            print("[INFO] Running automatic setup...")
            setup_script = Path(__file__).parent.parent.parent.parent.parent / "scripts" / "auto_setup.py"
            if setup_script.exists():
                import subprocess
                result = subprocess.run([sys.executable, str(setup_script)])
                if result.returncode != 0:
                    print("[ERROR] Automatic setup failed. Please run manually:")
                    sys.exit(1)
                if not model_path.exists():
                    print("[ERROR] Model still not found after setup.")
                    sys.exit(1)
            else:
                print("[INFO] Please run: python scripts/download_models.py")
                sys.exit(1)
        
        print(f"[INFO] Loading LLM model...")
        
        self.llm_processor = AutoProcessor.from_pretrained(
            model_path, trust_remote_code=True, local_files_only=True
        )
        self.llm_model = AutoModelForVision2Seq.from_pretrained(
            model_path, trust_remote_code=True, local_files_only=True
        )
        self.llm_model.to(self.device)
        self.llm_model.eval()
        
        print(f"[OK] LLM model loaded")
    
    def embed(self, texts: List[str]) -> List[List[float]]:
        import torch
        if self.embedding_model is None:
            self.load_embedding_model()
            
        embeddings = []
        batch_size = 8
        
        with torch.no_grad():
            for i in range(0, len(texts), batch_size):
                batch = texts[i:i + batch_size]
                encoded = self.embedding_tokenizer(
                    batch, padding=True, truncation=True,
                    return_tensors="pt", max_length=8192
                )
                encoded = {k: v.to(self.device) for k, v in encoded.items()}
                output = self.embedding_model(**encoded)
                mask = encoded["attention_mask"].unsqueeze(-1).float()
                embeddings_batch = (output[0] * mask).sum(dim=1) / mask.sum(dim=1).clamp(min=1e-9)
                embeddings_batch = torch.nn.functional.normalize(embeddings_batch, p=2, dim=1)
                embeddings.extend(embeddings_batch.cpu().numpy().tolist())
                
        return embeddings
    
    def chat(self, messages: List[Dict[str, Any]], max_tokens: int = 512) -> str:
        if self.llm_model is None:
            self.load_llm_model()
            
        prompt_parts = []
        for msg in messages:
            role = msg.get("role", "user")
            content = msg.get("content", "")
            if isinstance(content, list):
                texts = [item.get("text", "") for item in content if item.get("type") == "text"]
                content = " ".join(texts)
            if role == "system":
                prompt_parts.append(f"System: {content}")
            elif role == "user":
                prompt_parts.append(f"User: {content}")
            elif role == "assistant":
                prompt_parts.append(f"Assistant: {content}")
        
        prompt_parts.append("Assistant:")
        prompt = "\n".join(prompt_parts)
        
        import torch
        inputs = self.llm_processor(text=prompt, return_tensors="pt")
        inputs = {k: v.to(self.device) for k, v in inputs.items()}
        
        with torch.no_grad():
            outputs = self.llm_model.generate(
                **inputs, max_new_tokens=max_tokens, do_sample=True, temperature=0.7, top_p=0.9,
            )
        
        response = self.llm_processor.decode(outputs[0], skip_special_tokens=True)
        if "Assistant:" in response:
            response = response.split("Assistant:")[-1].strip()
        return response
