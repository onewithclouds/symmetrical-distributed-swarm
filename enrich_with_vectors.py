# enrich_with_vectors.py
import json
from sentence_transformers import SentenceTransformer

# 1. Load the Brain (Fast, Local model)
# "all-MiniLM-L6-v2" is a tiny, fast model perfect for code concepts.
print("🧠 Loading Neural Model...")
model = SentenceTransformer('all-MiniLM-L6-v2')

# 2. Load the Archive
with open('swarm_archive.json', 'r') as f:
    archive = json.load(f)

print(f"📂 Loaded {len(archive['files'])} files. Injecting Neural Vectors...")

# 3. Inject Intelligence
for entry in archive['files']:
    # We embed the code content. 
    # Optimization: Embed the *Skeleton* if the file is huge, or the *Module Doc* if available.
    text_to_embed = entry.get('content', '')
    
    if text_to_embed:
        # Turn text into math
        vector = model.encode(text_to_embed).tolist()
        
        # Inject into JSON
        entry['embedding_vector'] = vector
        print(f"    ✨ Vectorized: {entry['path']}")

# 4. Save the "Smart" Archive
with open('swarm_archive_neural.json', 'w') as f:
    json.dump(archive, f)

print("✅ Neural Injection Complete. The Archive can now 'think'.")