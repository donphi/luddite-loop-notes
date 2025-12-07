# 8. System Architecture & Infrastructure - Overview

Total Entries: 15

| # | Active | Configuration | Specifications | Purpose | References | Category | Name | Why Chosen | Cost | Version | License | Dependencies | Component |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | ✓ |  | Container management in VS Code | Containerization and deployment |  | IDE & Extensions | Docker | Ensures reproducibility across environments |  | Latest |  |  | Docker Extension |
| 2 | ✓ |  | Facebook AI Similarity Search | Local vector similarity search | https://github.com/facebookresearch/faiss | Python Package | faiss-gpu | Extremely fast, GPU accelerated |  | 1.7.4 |  |  | FAISS |
| 3 | ✓ |  | 96GB VRAM, 18,176 CUDA cores, Ada Lovelace arch... | Large model training, RAG embedding generation,... | https://www.nvidia.com/en-us/design-visualizati... | Hardware | NVIDIA RTX 6000 Ada | Professional GPU with massive 96GB VRAM for lar... |  | Driver 550.x |  |  | GPU - Workstation 1 |
| 4 | ✓ |  | RAG framework with chain abstractions | RAG pipeline implementation | https://python.langchain.com/ | Python Package | langchain | Industry standard for RAG applications |  | Latest |  |  | LangChain |
| 5 | ✓ |  | Data framework for LLM applications | Alternative RAG implementation | https://docs.llamaindex.ai/ | Python Package | llama-index | Better for certain indexing strategies |  | Latest |  |  | LlamaIndex |
| 6 | ✓ |  | Vector database for similarity search | Storing and retrieving embeddings | https://milvus.io/ | Database System | Milvus | Scalable, supports multiple index types, produc... |  | 2.4.x |  |  | Milvus |
| 7 | ✓ |  | Core programming language | All development and scripting | https://www.python.org/ | Python Package | Python | Latest stable version with performance improvem... |  | 3.11 |  |  | Python Runtime |
| 8 | ✓ |  | Deep learning framework with CUDA support | Model training and inference | https://pytorch.org/ | ML Framework | torch | CUDA acceleration, extensive ecosystem |  | 2.3.0+cu121 |  |  | PyTorch |
| 9 | ✓ |  | AI-powered coding assistant for VS Code - provi... | AI-assisted development and code generation | Note: All code is AI-assisted and reviewed | AI Assistant | RooCode AI | Accelerates development with AI code suggestion... |  | Latest |  |  | RooCode Extension |
| 10 | ✓ |  | Hugging Face transformers library | PubMedBERT and other models | https://huggingface.co/docs/transformers | Python Package | transformers | Access to pre-trained biomedical models |  | 4.40+ |  |  | Transformers |
| 11 | ✓ |  | Long-term support release, CUDA 12.4 compatible | Stable Linux environment for ML development | https://ubuntu.com/download/desktop | Operating System | Ubuntu | Best NVIDIA driver support, extensive ML librar... |  | 24.04.02 LTS |  |  | Ubuntu Desktop |
| 12 | ✓ |  | Primary IDE with extensions | Code development and debugging |  | IDE & Extensions | Visual Studio Code | Excellent Python support, integrated terminal, ... |  | Latest |  |  | VS Code |
| 13 | ✓ |  | Vector database with semantic search | Alternative vector storage | https://weaviate.io/ | Database System | Weaviate | Built-in vectorization, GraphQL API |  | 1.25.x |  |  | Weaviate |
| 14 | ✓ |  | Specs: 24-core Threadripper 7965 Pro, 128GB RAM... | Primary development and training workstation | https://www.amd.com/en/products/processors/work... | Hardware | AMD Threadripper 7965 Pro | High core count for parallel processing, extens... |  | 24-core/48-thread |  |  | Workstation 1 - Development |
| 15 | ✓ |  | Intel/AMD CPU, 32GB RAM, RTX 3070 8GB, Ubuntu 2... | Testing and validation workstation |  | Hardware | Custom Build | Cost-effective testing environment, ensures cod... |  | RTX 3070 System |  |  | Workstation 2 - Testing |
