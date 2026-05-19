## Debugging

- [Important] When debugging deployment/runtime issues, enumerate the top 3-5 most likely root causes ranked by probability BEFORE making any changes. Verify the simplest causes first (missing imports, typos, wrong env vars) before assuming library-level incompatibilities or making widespread config changes.
- [Important] Fix the root cause in source code — never apply workarounds to symptoms (e.g., manually editing a config file that a broken installer should have written). If a tool or installer failed, fix the tool.
