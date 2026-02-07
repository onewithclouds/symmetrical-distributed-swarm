import os
import json
import fnmatch
import re
import hashlib

# --- CONFIGURATION ---
MAX_FILE_SIZE = 64 * 1024  
IGNORE_DIRS = [
    '.git', '__pycache__', 'deps', '_build', 'node_modules', 
    '.elixir_ls', '.idea', '.vscode','target',
    'Mnesia.*', 'mnesia.*', 'priv', 'assets'
]
IGNORE_EXTENSIONS = [
    '.beam', '.ez', '.dll', '.so', '.o', '.a',
    '.DCD', '.DAT', '.LOG', '.dcd', '.dat', '.log',
    '.jpg', '.jpeg', '.png', '.gif', '.mp3', '.wav',
    '.zip', '.tar', '.gz', '.lock'
]

# --- THE SOUL GEM (Meta-Instructions) ---
META_INSTRUCTION = """
YOU ARE THE ARCHITECT. 
This JSON file represents the complete nervous system of an Elixir Drone Swarm.
1. 'system_map': High-level overview of modules and their capabilities.
2. 'dependency_graph': A Mermaid diagram showing how modules connect.
3. 'runtime_config': The wiring that connects these modules at boot time.
4. 'files': The raw code bones and skeletons.
"""


# --- THE X-RAY SCANNER (v8.0 - HOLOGRAPHIC) ---

def extract_config_skeleton(content):
    configs = []
    matches = re.findall(r'^\s*config\s+:([a-zA-Z0-9_]+),\s*:([a-zA-Z0-9_]+),\s*(.+)', content, re.MULTILINE)
    for app, key, val in matches:
        configs.append(f":{app} | :{key} => {val.strip()}")
    return configs

def extract_elixir_skeleton(content):
    skeleton = {
        "doc": None,
        "modules": [],
        "dependencies": [], 
        "behaviors": [],   
        "structs": [],     
        "functions": [],    
        "types": [],
        "attributes": [],   
        "todos": []         
    }
    
    doc_match = re.search(r'@moduledoc\s+"""(.*?)"""', content, re.DOTALL)
    if doc_match:
        skeleton["doc"] = doc_match.group(1).strip()[:200].replace("\n", " ") + "..."

    modules = re.findall(r'defmodule\s+([A-Z][a-zA-Z0-9\._]*)', content)
    skeleton["modules"] = modules
    
    # Capture raw alias names for the Graph
    raw_aliases = re.findall(r'^\s*alias\s+([A-Z][a-zA-Z0-9\._]*)', content, re.MULTILINE)
    skeleton["dependencies"].extend([f"alias {a}" for a in raw_aliases])
    
    imports = re.findall(r'^\s*import\s+([A-Z][a-zA-Z0-9\._]*)', content, re.MULTILINE)
    skeleton["dependencies"].extend([f"import {i}" for i in imports])

    uses = re.findall(r'^\s*use\s+([A-Z][a-zA-Z0-9\._]*)', content, re.MULTILINE)
    skeleton["behaviors"].extend([f"use {u}" for u in uses])
    
    behaviours = re.findall(r'^\s*@behaviour\s+([A-Z][a-zA-Z0-9\._]*)', content, re.MULTILINE)
    skeleton["behaviors"].extend([f"implements {b}" for b in behaviours])

    struct_match = re.search(r'defstruct\s+\[(.*?)\]', content, re.DOTALL)
    if struct_match:
        raw_keys = struct_match.group(1)
        keys = re.findall(r':([a-z_][a-zA-Z0-9_]*)', raw_keys)
        skeleton["structs"] = keys

    specs = re.findall(r'^\s*@spec\s+(.+)', content, re.MULTILINE)
    skeleton["types"].extend([f"@spec {s.strip()}" for s in specs])

    def_matches = re.finditer(r'^\s*(def|defp)\s+([a-z_][a-zA-Z0-9_]*[\?!]?)\s*(\(.*\))?\s*(do|,)', content, re.MULTILINE)
    for m in def_matches:
        kind = m.group(1)
        name = m.group(2)
        args_str = m.group(3)
        arity = 0
        if args_str:
            arity = args_str.count(',') + 1
        skeleton["functions"].append(f"{kind} {name}/{arity}")

    attrs = re.findall(r'^\s*(@[a-z_]+)\s+(.+)', content, re.MULTILINE)
    skeleton["attributes"] = [f"{k} = {v}" for k, v in attrs if k not in ['@moduledoc', '@doc', '@behaviour', '@spec', '@type']]

    todos = re.findall(r'#\s*(TODO|FIXME|HACK|NOTE):?\s*(.*)', content, re.IGNORECASE)
    skeleton["todos"] = [f"{tag.upper()}: {msg.strip()}" for tag, msg in todos]

    return skeleton, raw_aliases

def generate_mermaid_graph(system_map):
    """Generates a visual dependency graph for the LLM."""
    graph = ["graph TD;"]
    for module, data in system_map.items():
        # Shorten module names for cleaner graph (SwarmBrain.Radio -> Radio)
        short_mod = module.split(".")[-1]
        
        for dep in data.get("raw_aliases", []):
            short_dep = dep.split(".")[-1]
            # Avoid self-loops and common libs
            if short_mod != short_dep and short_dep not in ["Logger", "GenServer", "Application"]:
                graph.append(f"    {short_mod} --> {short_dep};")
    
    return "\n".join(graph)

def generate_tree(path, prefix=""):
    tree_str = ""
    try:
        items = os.listdir(path)
    except PermissionError:
        return ""
    items.sort(key=lambda x: (not os.path.isdir(os.path.join(path, x)), x))
    filtered_items = []
    for item in items:
        if not any(fnmatch.fnmatch(item, pattern) for pattern in IGNORE_DIRS):
            filtered_items.append(item)
    pointers = [("├── " if i < len(filtered_items) - 1 else "└── ") for i in range(len(filtered_items))]
    for pointer, item in zip(pointers, filtered_items):
        full_path = os.path.join(path, item)
        tree_str += prefix + pointer + item + "\n"
        if os.path.isdir(full_path):
            extension = "│   " if pointer == "├── " else "    "
            tree_str += generate_tree(full_path, prefix + extension)
    return tree_str

def is_binary(file_path):
    try:
        with open(file_path, 'rb') as f:
            chunk = f.read(1024)
            if b'\0' in chunk:
                return True
            try:
                chunk.decode('utf-8')
            except UnicodeDecodeError:
                return True
    except Exception:
        return True
    return False

def get_file_hash(file_path):
    h = hashlib.md5()
    try:
        with open(file_path, 'rb') as f:
            for chunk in iter(lambda: f.read(4096), b""):
                h.update(chunk)
        return h.hexdigest()[:8]
    except:
        return "error"

def pack_repo(repo_path, output_file):
    system_map = {} 
    runtime_config = []

    repo_data = {
        "meta_instruction": META_INSTRUCTION.strip(), # <--- The Soul Gem
        "project_name": os.path.basename(os.path.abspath(repo_path)),
        "tree_view": generate_tree(repo_path),
        "dependency_graph": "", # <--- The Visual Cortex
        "system_map": {}, 
        "runtime_config": [], 
        "files": []
    }

    print(f"💀 X-Raying Architecture: {repo_path}")

    for root, dirs, files in os.walk(repo_path):
        for i in range(len(dirs) - 1, -1, -1):
            d = dirs[i]
            if any(fnmatch.fnmatch(d, pattern) for pattern in IGNORE_DIRS):
                dirs.pop(i)

        for file in files:
            file_path = os.path.join(root, file)
            rel_path = os.path.relpath(file_path, repo_path)
            
            _, ext = os.path.splitext(file)
            if ext in IGNORE_EXTENSIONS:
                continue

            file_size = os.path.getsize(file_path)
            file_type = "binary" if is_binary(file_path) else "text"
            
            if file_type == "text":
                try:
                    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                        full_content = f.read() 
                        
                        skeleton = None
                        if ext in ['.ex', '.exs']:
                            # Extract Skeleton AND raw aliases for the graph
                            skeleton, raw_aliases = extract_elixir_skeleton(full_content)
                            
                            if skeleton["modules"]:
                                mod_name = skeleton["modules"][0]
                                system_map[mod_name] = {
                                    "doc": skeleton["doc"], 
                                    "functions": skeleton["functions"],
                                    "types": skeleton["types"],
                                    "dependencies": skeleton["dependencies"],
                                    "raw_aliases": raw_aliases # Stored for graph gen
                                }
                                
                            if "config" in rel_path and ext == ".exs":
                                config_lines = extract_config_skeleton(full_content)
                                runtime_config.extend(config_lines)

                        if file_size > MAX_FILE_SIZE:
                            head = full_content[:2000]
                            display_content = head + f"\n\n[... ✂️ VOID CUT: File too large ({file_size} bytes). Skeleton extracted below. ...]"
                            print(f"⚠️ Truncating content for: {rel_path}")
                        else:
                            display_content = full_content
                        
                        file_entry = {
                            "path": rel_path,
                            "content": display_content
                        }

                        if skeleton:
                            file_entry["skeleton"] = skeleton
                        
                        repo_data["files"].append(file_entry)

                except Exception as e:
                    print(f"❌ Error: {rel_path} - {e}")
            else:
                repo_data["files"].append({
                    "path": rel_path,
                    "size": file_size,
                    "type": "binary",
                    "hash": get_file_hash(file_path)
                })

    # Inject Maps and Graphs
    repo_data["system_map"] = system_map
    repo_data["runtime_config"] = runtime_config
    
    # REVOLUTIONARY: Generate the Mermaid Graph
    repo_data["dependency_graph"] = generate_mermaid_graph(system_map)

    print(f"💾 Compressing into the Void: {output_file}")
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(repo_data, f, indent=2)
    print("✅ Analysis Complete.")

if __name__ == "__main__":
    pack_repo(".", "swarm_archive.json")