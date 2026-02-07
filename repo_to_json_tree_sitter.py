import os
import json
import subprocess
import ctypes
import shutil
import stat
import warnings
from tree_sitter import Language, Parser, Query, QueryCursor

# --- CONFIGURATION ---
MAX_FILE_SIZE = 64 * 1024 
IGNORE_DIRS = ['.git', 'deps', '_build', 'target', 'node_modules', '.elixir_ls', 'priv', 'assets']
IGNORE_EXTENSIONS = ['.beam', '.so', '.dll', '.o', '.a', '.rlib', '.lock', '.json', '.gz', '.zip']
BUILD_DIR = 'build'

# Suppress warnings
warnings.filterwarnings("ignore", category=DeprecationWarning)

# --- THE LOADER ---
def get_language(nix_path, lang_name):
    if not os.path.exists(BUILD_DIR):
        os.makedirs(BUILD_DIR)
    
    local_lib = os.path.join(BUILD_DIR, f"{lang_name}.so")
    if os.path.exists(local_lib):
        try: os.remove(local_lib)
        except OSError: pass
    
    nix_binary = os.path.join(nix_path, "parser")
    if os.path.exists(nix_binary):
        print(f"⚡ Using pre-compiled Nix artifact for {lang_name}")
        shutil.copy(nix_binary, local_lib)
        os.chmod(local_lib, stat.S_IWRITE | stat.S_IREAD | stat.S_IEXEC)
        return load_language_lib(local_lib, lang_name)

    src_dir = os.path.join(nix_path, "src")
    parser_c = os.path.join(src_dir, "parser.c")
    if os.path.exists(parser_c):
        print(f"🛠️  Source found. Compiling {lang_name} with Clang...")
        compile_with_clang(nix_path, local_lib)
        return load_language_lib(local_lib, lang_name)
        
    raise RuntimeError(f"Could not find binary 'parser' OR source 'parser.c' in {nix_path}")

def compile_with_clang(src_root, output_path):
    cmd = ["clang", "-shared", "-fPIC", "-O2", "-o", output_path]
    src_path = os.path.join(src_root, "src")
    cmd.extend(["-I", src_path])
    parser_c = os.path.join(src_path, "parser.c")
    scanner_c = os.path.join(src_path, "scanner.c")
    cmd.append(parser_c)
    if os.path.exists(scanner_c): cmd.append(scanner_c)
    subprocess.check_call(cmd)

def load_language_lib(lib_path, language_name):
    lib = ctypes.cdll.LoadLibrary(lib_path)
    func_name = f"tree_sitter_{language_name}"
    if not hasattr(lib, func_name):
        raise AttributeError(f"Symbol {func_name} not found in {lib_path}")
    lang_func = getattr(lib, func_name)
    lang_func.restype = ctypes.c_void_p
    return Language(lang_func())

# --- MAIN EXECUTION ---
elixir_path = os.environ.get("TS_ELIXIR_SRC")
rust_path = os.environ.get("TS_RUST_SRC")

if not elixir_path or not rust_path:
    print("❌ ERROR: Tree-Sitter paths missing. Run 'nix develop'.")
    exit(1)

try:
    ELIXIR_LANG = get_language(elixir_path, "elixir")
    RUST_LANG = get_language(rust_path, "rust")
except Exception as e:
    print(f"❌ Initialization Failed: {e}")
    exit(1)

parser = Parser()

# --- META-DATA ---
META_INSTRUCTION = """
YOU ARE THE ARCHITECT. 
This is a POLISHED COGNITIVE MAP of the Swarm.
1. 'system_map': Deduplicated Structure, Arity, Docs, and Complexity Scores.
2. 'dependency_graph': Directed Graph (No self-loops).
3. 'files': Source code with deep skeletons.
"""

def execute_query(language, tree, query_scm):
    # 1. Panic-Proof Query Compilation
    try:
        query = Query(language, query_scm)
    except Exception as e:
        # If the grammar doesn't support the node type, fail gracefully
        # print(f"⚠️  Query Syntax Error (Skipping feature): {e}")
        return {}
    
    cursor = None
    results = {}
    
    try:
        cursor = QueryCursor()
        is_bound = False
    except TypeError:
        cursor = QueryCursor(query)
        is_bound = True
        
    iterator = None
    if hasattr(cursor, 'matches'):
        iterator = cursor.matches(tree.root_node) if is_bound else cursor.matches(query, tree.root_node)
    elif hasattr(cursor, 'captures'):
        iterator = cursor.captures(tree.root_node) if is_bound else cursor.captures(query, tree.root_node)
    elif hasattr(cursor, 'execute'):
        cursor.execute(tree.root_node)
        iterator = cursor

    if iterator is None: return {}

    try:
        for item in iterator:
            if isinstance(item, tuple) and len(item) == 2 and isinstance(item[1], dict):
                _, captures_dict = item
                for name, nodes in captures_dict.items():
                    if not isinstance(nodes, list): nodes = [nodes]
                    for n in nodes:
                        if name not in results: results[name] = []
                        results[name].append(n)
            elif isinstance(item, tuple) and len(item) == 2 and hasattr(item[0], 'start_byte'):
                n, c = item
                name = query.capture_name_for_id(c) if isinstance(c, int) else str(c)
                if name not in results: results[name] = []
                results[name].append(n)
            elif hasattr(item, 'captures'):
                caps = item.captures
                if isinstance(caps, dict):
                    for name, nodes in caps.items():
                        if not isinstance(nodes, list): nodes = [nodes]
                        for n in nodes:
                            if name not in results: results[name] = []
                            results[name].append(n)
    except Exception: pass
    return results

def get_elixir_skeleton(source_code):
    parser.language = ELIXIR_LANG
    tree = parser.parse(bytes(source_code, "utf8"))
    
    skeleton = {
        "modules": set(), 
        "functions": set(), 
        "structs": set(),
        "dependencies": set(),
        "complexity": 0,
        "doc": None
    }
    
    # 1. Modules
    mod_scm = """(call (identifier) @c (arguments (alias) @mod_name) (#match? @c "^defmodule$"))"""
    
    # 2. Dependencies
    dep_scm = """
    [
      (alias) @alias_dep
      (call (identifier) @call_name (arguments (alias) @call_dep) (#match? @call_name "^(import|require|use)$"))
    ]
    """

    # 3. Structs
    struct_scm = """(call (identifier) @defstruct (arguments) @fields (#match? @defstruct "^defstruct$"))"""
    
    # 4. Docstrings (FIXED: Universal Unary Operator Query)
    # Replaces (attribute) with (unary_operator) to match older/standard grammars
    doc_scm = """
    (unary_operator
      (call 
        (identifier) @attr_name 
        (arguments (string (string_content) @doc_text))
      )
      (#match? @attr_name "^moduledoc$")
    )
    """

    # 5. Complexity
    complexity_scm = """[(call (identifier) @k (#match? @k "^(def|defp|case|cond|if|with)$"))]"""
    
    # 6. Functions
    func_args_scm = """(call (identifier) @def (arguments (call (identifier) @func_name (arguments) @args)) (#match? @def "^(def|defp)$"))"""
    func_no_args_scm = """(call (identifier) @def (arguments (identifier) @func_name) (#match? @def "^(def|defp)$"))"""

    # --- EXECUTION ---
    
    mod_results = execute_query(ELIXIR_LANG, tree, mod_scm)
    if "mod_name" in mod_results:
        for node in mod_results["mod_name"]:
            skeleton["modules"].add(source_code[node.start_byte:node.end_byte])

    dep_results = execute_query(ELIXIR_LANG, tree, dep_scm)
    for key in ["alias_dep", "call_dep"]:
        if key in dep_results:
            for node in dep_results[key]:
                raw_dep = source_code[node.start_byte:node.end_byte]
                clean_dep = raw_dep.replace("alias ", "").replace("import ", "").replace("require ", "").replace("use ", "").strip()
                skeleton["dependencies"].add(clean_dep)

    # Docs (Now Resilient)
    doc_results = execute_query(ELIXIR_LANG, tree, doc_scm)
    if "doc_text" in doc_results:
        node = doc_results["doc_text"][0]
        skeleton["doc"] = source_code[node.start_byte:node.end_byte]

    struct_results = execute_query(ELIXIR_LANG, tree, struct_scm)
    if "fields" in struct_results:
        for node in struct_results["fields"]:
            skeleton["structs"].add(source_code[node.start_byte:node.end_byte])

    comp_results = execute_query(ELIXIR_LANG, tree, complexity_scm)
    if "k" in comp_results:
        skeleton["complexity"] = len(comp_results["k"])

    def count_args(args_node):
        return sum(1 for c in args_node.children if c.type not in [',', '(', ')'])

    func_args_res = execute_query(ELIXIR_LANG, tree, func_args_scm)
    if "func_name" in func_args_res and "args" in func_args_res:
        names = func_args_res["func_name"]
        args_nodes = func_args_res["args"]
        limit = min(len(names), len(args_nodes))
        for i in range(limit):
            name = source_code[names[i].start_byte:names[i].end_byte]
            arity = count_args(args_nodes[i])
            skeleton["functions"].add(f"{name}/{arity}")

    func_no_args_res = execute_query(ELIXIR_LANG, tree, func_no_args_scm)
    if "func_name" in func_no_args_res:
        for node in func_no_args_res["func_name"]:
            name = source_code[node.start_byte:node.end_byte]
            skeleton["functions"].add(f"{name}/0")

    for mod in skeleton["modules"]:
        if mod in skeleton["dependencies"]:
            skeleton["dependencies"].remove(mod)

    final_skeleton = {
        "modules": sorted(list(skeleton["modules"])),
        "functions": sorted(list(skeleton["functions"])),
        "structs": sorted(list(skeleton["structs"])),
        "dependencies": sorted(list(skeleton["dependencies"])),
        "complexity": skeleton["complexity"],
        "doc": skeleton["doc"]
    }

    if not final_skeleton["modules"]: return None
    return final_skeleton

def get_rust_skeleton(source_code):
    parser.language = RUST_LANG
    tree = parser.parse(bytes(source_code, "utf8"))
    
    skeleton = {"structs": set(), "functions": set(), "complexity": 0}
    
    scm = """
    (struct_item (type_identifier) @struct)
    (function_item (identifier) @fn)
    """
    
    results = execute_query(RUST_LANG, tree, scm)
    
    if "struct" in results:
        for node in results["struct"]:
            skeleton["structs"].add(source_code[node.start_byte:node.end_byte])
    if "fn" in results:
        for node in results["fn"]:
            skeleton["functions"].add(source_code[node.start_byte:node.end_byte])
            
    comp_scm = """[(if_expression) (match_expression) (loop_expression) (for_expression)] @c"""
    comp_res = execute_query(RUST_LANG, tree, comp_scm)
    if "c" in comp_res:
        skeleton["complexity"] = len(comp_res["c"])
        
    if not skeleton["structs"] and not skeleton["functions"]: return None
    
    return {
        "structs": sorted(list(skeleton["structs"])),
        "functions": sorted(list(skeleton["functions"])),
        "complexity": skeleton["complexity"]
    }

def generate_mermaid_graph(system_map):
    graph = ["graph TD", "  subgraph Swarm"]
    
    for module in system_map.keys():
        safe_name = module.replace(".", "_")
        complexity = system_map[module].get("complexity", 0)
        if complexity > 10:
            graph.append(f"    {safe_name}[{module} (C:{complexity})]:::complex")
        else:
            graph.append(f"    {safe_name}[{module}]")
            
    for module, skeleton in system_map.items():
        safe_origin = module.replace(".", "_")
        if "dependencies" in skeleton:
            for dep in skeleton["dependencies"]:
                if dep in system_map:
                    safe_target = dep.replace(".", "_")
                    graph.append(f"    {safe_origin} --> {safe_target}")

    graph.append("  end")
    graph.append("  classDef complex fill:#f96,stroke:#333,stroke-width:2px;")
    return "\n".join(graph)

def pack_repo(root_dir, output_file):
    repo_data = {
        "project_name": os.path.basename(os.path.abspath(root_dir)),
        "meta_instruction": META_INSTRUCTION,
        "system_map": {},
        "dependency_graph": "",
        "files": []
    }
    
    system_map = {}

    print(f"🔮 Tree-sitter Polished Scan (Mark XXIII) in: {root_dir}")

    for dirpath, dirnames, filenames in os.walk(root_dir):
        dirnames[:] = [d for d in dirnames if d not in IGNORE_DIRS]
        
        for filename in filenames:
            if any(filename.endswith(ext) for ext in IGNORE_EXTENSIONS): continue
            if filename in ['repo_to_json_tree_sitter.py', output_file]: continue

            file_path = os.path.join(dirpath, filename)
            rel_path = os.path.relpath(file_path, root_dir)
            if filename.startswith('.'): continue
            
            file_size = os.path.getsize(file_path)

            if file_size <= MAX_FILE_SIZE:
                try:
                    with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                        content = f.read()
                        entry = {"path": rel_path, "content": content}
                        
                        skel = None
                        if filename.endswith('.ex') or filename.endswith('.exs'):
                            skel = get_elixir_skeleton(content)
                        elif filename.endswith('.rs'):
                            skel = get_rust_skeleton(content)
                            
                        if skel:
                            entry["skeleton"] = skel
                            for mod in skel.get("modules", []):
                                system_map[mod] = skel
                        
                        repo_data["files"].append(entry)
                except Exception as e:
                    print(f"❌ Error: {rel_path} - {e}")
            else:
                repo_data["files"].append({
                    "path": rel_path, 
                    "size": file_size, 
                    "note": "Content Omitted (Too Large)"
                })

    repo_data["system_map"] = system_map
    repo_data["dependency_graph"] = generate_mermaid_graph(system_map)

    print(f"💾 Encoded: {output_file}")
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(repo_data, f, indent=2)
    
    print(f"✅ Total Files: {len(repo_data['files'])}")

if __name__ == "__main__":
    pack_repo(".", "swarm_archive.json")