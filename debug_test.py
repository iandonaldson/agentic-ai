#!/usr/bin/env python3

# Simple debug test to see what's failing
import sys
sys.path.append('/workspaces/agentic-ai')

try:
    from src.planning_agent import planner_agent
    print("✅ Successfully imported planner_agent")

    # Test with a simple prompt
    print("🧪 Testing planner_agent with simple prompt...")
    result = planner_agent("Write a short summary about Python programming")
    print(f"✅ planner_agent returned: {result}")

except Exception as e:
    print(f"❌ Error: {e}")
    import traceback
    traceback.print_exc()
