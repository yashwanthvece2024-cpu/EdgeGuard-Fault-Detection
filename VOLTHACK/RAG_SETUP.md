# RAG setup

## 1. Put knowledge files in

data/knowledge/

Useful sources:
- motor maintenance manuals
- bearing fault references
- vibration-analysis references
- ACS712 / ADXL345 / DS18B20 datasheets
- motor-controller documentation
- your own maintenance SOP
- your own labeled incident reports

## 2. Configure the API key

Copy `.env.example` to `.env` and set:

GEMINI_API_KEY=...

## 3. Create the File Search store

python -c "from src.rag import upload_knowledge_directory; print(upload_knowledge_directory())"

Copy the returned store name into:

GEMINI_FILE_SEARCH_STORE=...

## 4. Test retrieval

Use `query_rag()` with a maintenance question.

## 5. Integration later

The supervisor should call:

build_diagnostic_question(diagnosis, features)
        ↓
query_rag(question)
        ↓
dashboard explanation + retrieved sources

Do not let RAG silently change the numerical classifier result.
