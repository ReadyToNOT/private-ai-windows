# Patches

`windows-fixes.diff` contains my four code changes to [PrivateGPT](https://github.com/zylon-ai/private-gpt), made so it runs natively on Windows (plus one general tool-calling bug fix).

Each change is explained in [`../docs/09-windows-code-patches.md`](../docs/09-windows-code-patches.md).

To apply to a fresh PrivateGPT clone:
```powershell
cd <path-to>\privateGPT
git apply <path-to>\windows-fixes.diff
```
The diff is against the PrivateGPT version I installed in Aug 2026, so it may need adjusting for newer versions.
