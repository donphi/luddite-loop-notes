# 1. Activity Log (Experiment) - Overview

Total Entries: 24

| # | Hours | Date | Category | Key Achievement | Cite | Related Experiments | Learning | Nr | Phase | Libraries | Challenges | Entry |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 2 | 2025-05-16 | 📘 Data Collection |  |  | PDF Download Pipeline | DOI and Journal title is the source of truth. | 1 | Phase 1: Data Collection & Setup | https://biobank.ndph.ox.ac.uk/showcase/download... |  | UK Biobank DOI Extraction |
| 2 | 6 | 2025-05-19 | 📘 Data Collection |  |  | PDF Download Pipeline | Messy and Unrepeatable Process | 2 | Phase 1: Data Collection & Setup | Core.ac.uk, OpenAlex.org, Unpaidwall.org, ncbi.... |  | PDF Retrieval |
| 3 | 10 | 2025-05-21 | 📘 Data Collection |  |  | PDF Download Pipeline | Needed multiple accounts for Opensource access | 3 | Phase 1: Data Collection & Setup | Zotero.org |  | PDF Retrieval (Continue) |
| 4 | 5 | 2025-08-05 | 📘 Data Collection |  |  | PDF Download Pipeline | Retrieval Bias: Ensuring the 'long tail' of non... | 4 | Phase 1: Data Collection & Setup |  |  | Final PDF Collection |
| 5 | 4 | 2025-08-07 | 🧹 Data Preprocessing |  | Lopez, P. (2009). GROBID: Combining automatic b... | PDF to Markdown/JSON Conversion | GROBID is incredibly useful for extracting meta... | 5 | Phase 2: PDF Processing Pipeline | GROBID, Marker, Surya, Docling, PaddlePaddle |  | PDF Metadata Matching |
| 6 | 35 | 2025-08-07 | 🧹 Data Preprocessing |  |  | PDF to Markdown/JSON Conversion | The Most important part of the pipeline, is ens... | 6 | Phase 2: PDF Processing Pipeline | ENV: Ubuntu 24.04 with CUDA 12.8 development to... |  | PDF to Markdown/JSON Conversion |
| 7 | 2 | 2025-08-08 | 🧹 Data Preprocessing |  |  |  | Data Validation will need to be ingegrated with... | 8 |  | Orchastration NB, Research Pipeline organisers |  | Data Validation - Duplicate Rem |
| 8 | 1 | 2025-08-17 | 🧹 Data Preprocessing |  |  |  | Marker is a messy extractor, pipeline needs som... | 9 |  | PyMuPDF, Tessaract, |  | Marker Header Validation |
| 9 | 5 | 2025-08-17 | 🧹 Data Preprocessing |  |  |  | Yaml config files are very useful for centralis... | 10 |  | Yaml, MD, JSON |  | Document Chunk Evolution |
| 10 | 16 | 2025-08-18 | 🧬 Feature Selection |  |  |  | Never, ever use Regex, brittle and breaks at sc... | 11 |  |  |  | Section-Aware Biomedical Tagging |
| 11 | 4 | 2025-08-19 | 🧹 Data Preprocessing |  |  |  | Use monitor for output progress with large pipe... | 12 |  | rich better than tqdm, |  | HanFlair (Output) |
| 12 | 1 | 2025-08-18 | 🧹 Data Preprocessing |  |  |  |  | 12 |  |  |  | Tagging Prep (Note) |
| 13 | 12 | 2025-08-20 | 🧹 Data Preprocessing |  |  |  | Chunking is important to reduce context window ... | 13 |  | SPECTER2, BioMedBERT, SapBERT |  | Section-Aware Chunking Plan and Model Evaluation |
| 14 | 6 | 2025-08-20 | 🧹 Data Preprocessing |  |  |  | LLMs set with deterministic settings continue t... | 14 |  |  |  | Redo Chunk Pipeline |
| 15 | 9 | 2025-08-21 | 🧹 Data Preprocessing |  |  |  | Normalisation needs tuning. Witnesses are impor... | 15 |  |  |  | Normalise Categories |
| 16 | 6 | 2025-08-22 | 🧹 Data Preprocessing |  |  |  |  | 16 |  |  |  | Topic Reclassification Report |
| 17 | 16 | 2025-08-22 | 📊 Knowledge Graph |  |  |  | Onotologies useful for normalisation, downloade... | 17 |  | MONDO, ICD-9, ICD-10, SNOMED, UMLS, MeSH, HPO, ... |  | Reflecting on Feature Extraction |
| 18 | 5 | 2025-08-23 | 🧪 Testing |  |  |  | Sentence Level Tagging. Useful for chuking over... | 18 |  |  |  | SLATE: Massive revelation |
| 19 | 8 | 2025-08-25 | 🧪 Testing |  |  |  | Basic NER models fine-tuned on disease are perf... | 19 |  | BERN2, PubTator3, HunFlair2, SciSpacy (Allen AI... |  | SLATE & Tagging Change |
| 20 | 7 | 2025-08-26 | 🧹 Data Preprocessing |  |  |  |  | 20 |  |  |  | Recleaning PDF to MD Artifacts |
| 21 | 11 | 2025-08-27 | 🧹 Data Preprocessing |  |  |  | Scaling is incredibly hard and needs throughful... | 21 |  |  |  | Sentence Chunk |
| 22 | 4 | 2025-08-28 | 🧪 Testing |  |  |  | JSON structure needs to be cleaner to extract d... | 22 |  | ALTO XML |  | Original JSON Tags |
| 23 | 8 | 2025-08-31 | 📘 Data Collection |  |  |  | OLAP vs OLTP Architecture: Row-oriented databas... | 23 |  | duckdb |  | UKB Field Category Link |
| 24 | 5 | 2025-08-13 | 🧬 Feature Selection |  |  |  | Elasticsearch, reverse index lookup, effective ... | 24 |  | elasticsearch, elasticsearch-dsl |  | UK Biobank Feature Synonym Generation |
