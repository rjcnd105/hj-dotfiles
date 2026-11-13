---
name: find-docs
description: Verify version-sensitive library, framework, SDK, or CLI behavior against current documentation. Use when the API or installed version is uncertain, a migration changes behavior, or the user requests documentation. Reuse documentation already verified for the task.
---

# Documentation lookup

Identify the API or behavior that needs verification and read the installed
version from the project. Fetch enough documentation to resolve that question.

Choose the first available route:

1. Use the connected Context7 MCP tools to resolve the library and retrieve the
   relevant documentation. Reuse a verified library ID within the task.
2. If Context7 MCP is unavailable, use the installed `ctx7` CLI:

   ```sh
   ctx7 library <name> "<question>"
   ctx7 docs <libraryId> "<question>"
   ```

3. If neither route is available or the product is not indexed, read installed
   documentation or the relevant official documentation page. For OpenAI
   products, use the available OpenAI documentation tools.

Keep queries free of credentials, private code, and personal data. Verify that
the selected library and version match the project; an approximate name match
is not enough. Cite the page supporting a non-trivial external claim and state
any remaining version uncertainty.

Follow the user's search restrictions. A documentation request does not require
installing a CLI, changing MCP settings, or installing other skills. Once the
question is answered, continue the original task without repeating retrieval.
