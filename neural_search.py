import json
import numpy as np
from sentence_transformers import SentenceTransformer

# --- CONFIGURATION ---
ARCHIVE_FILE = "swarm_archive_neural.json"
MODEL_NAME = 'all-MiniLM-L6-v2'

def cosine_similarity(a, b):
    return np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b))

def load_archive():
    print(f"📂 Loading the Neural Archive: {ARCHIVE_FILE}...")
    try:
        with open(ARCHIVE_FILE, 'r') as f:
            return json.load(f)
    except FileNotFoundError:
        print("❌ Error: Archive not found. Did you run enrich_with_vectors.py?")
        exit(1)

def main():
    # 1. Load Data & Model
    archive = load_archive()
    print(f"🧠 Loading Neural Model ({MODEL_NAME})...")
    model = SentenceTransformer(MODEL_NAME)
    
    files = archive.get('files', [])
    # Filter only files that have vectors
    vectorized_files = [f for f in files if 'embedding_vector' in f]
    print(f"✨ Index active. {len(vectorized_files)} neural nodes ready.")

    print("\n🔮 THE VOID ARCHITECT LISTENS. (Type 'exit' to quit)")
    
    while True:
        query = input("\n❓ Query: ")
        if query.lower() in ['exit', 'quit']:
            break
            
        # 2. Vectorize the User's Query
        query_vector = model.encode(query)
        
        # 3. Search (Compare Query Vector to Code Vectors)
        results = []
        for entry in vectorized_files:
            code_vector = entry['embedding_vector']
            score = cosine_similarity(query_vector, code_vector)
            results.append((score, entry))
            
        # 4. Sort by Similarity
        results.sort(key=lambda x: x[0], reverse=True)
        
        # 5. Display Top 3 Matches
        print(f"\n🔹 Top Matches for '{query}':")
        for i in range(min(3, len(results))):
            score, entry = results[i]
            print(f"   {i+1}. [{score:.4f}] {entry['path']}")
            # Optional: Show a snippet of why it matched
            # print(f"      Context: {entry['content'][:100]}...")

if __name__ == "__main__":
    main()