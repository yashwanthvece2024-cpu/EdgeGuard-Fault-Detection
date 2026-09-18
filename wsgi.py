import os
import sys
import importlib.util

# Get absolute path to main.py
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MAIN_PATH = os.path.join(BASE_DIR, "src", "api", "main.py")

# Ensure 'src' is in Python's system path for internal imports
SRC_DIR = os.path.join(BASE_DIR, "src")
if SRC_DIR not in sys.path:
    sys.path.insert(0, SRC_DIR)

# Directly load main.py bypassing package structural requirements
spec = importlib.util.spec_from_file_location("main", MAIN_PATH)
main_module = importlib.util.module_from_spec(spec)
sys.modules["main"] = main_module
spec.loader.exec_module(main_module)

# Expose the FastAPI app instance to Uvicorn
app = main_module.app