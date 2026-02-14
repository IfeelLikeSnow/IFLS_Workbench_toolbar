# V63 GitHub Actions notes (PR-based index updates)

These workflows use `peter-evans/create-pull-request` to open a PR with updated index files.

Enable in GitHub repo settings:
- Settings → Actions → General → Workflow permissions: **Read and write permissions**
- Enable: **Allow GitHub Actions to create and approve pull requests**

Stable vs Nightly:
- Nightly workflow rebuilds `index-nightly.xml` daily and on pushes.
- Stable workflow rebuilds `index.xml` on version tags (v*).
