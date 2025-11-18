# Vision Support Scripts

These scripts enable AZMI to process images attached to Jira tickets.

## Scripts

### 1. `fetch-jira-attachments.sh`

Fetches and processes image attachments from Jira issues.

**Usage:**
```bash
./fetch-jira-attachments.sh <JIRA_BASE> <ISSUE_KEY> <JIRA_EMAIL> <JIRA_API_TOKEN>
```

**What it does:**
1. Fetches issue metadata from Jira REST API v3
2. Filters for image/PDF attachments
3. Downloads each attachment
4. Converts PDFs to PNG (first page only)
5. Resizes large images to max 1024x1024 (preserves aspect ratio)
6. Encodes to base64
7. Outputs `.artifacts/images.json`

**Supported formats:**
- ✅ PNG
- ✅ JPG/JPEG
- ✅ GIF
- ✅ WebP
- ✅ PDF (converts to PNG)

**Output format (`images.json`):**
```json
{
  "images": [
    {
      "filename": "screenshot.png",
      "mime_type": "image/png",
      "size": 125483,
      "base64": "iVBORw0KGgoAAAANSUhEUg...",
      "data_uri": "data:image/png;base64,iVBORw0KGg..."
    }
  ],
  "count": 1,
  "total_size": 125483
}
```

**Limits:**
- Max 10MB per image
- Resizes to 1024x1024 if larger
- Skips if base64 > 8MB

**Requirements:**
- `curl`
- `jq`
- `base64`
- `imagemagick` (for PDF conversion and resizing)

### 2. `build-image-context.sh`

Converts `images.json` to markdown-formatted context for AI prompts.

**Usage:**
```bash
./build-image-context.sh [max_images]
```

**Parameters:**
- `max_images`: Maximum images to include (default: 5)

**What it does:**
1. Reads `.artifacts/images.json`
2. Builds markdown with embedded base64 images
3. Adds AI instructions
4. Outputs `.artifacts/image-context.md`

**Output format (`image-context.md`):**
```markdown
## 🖼️ Visual Context

You have been provided with **2 image(s)** attached to this Jira ticket:

### Image 1: `screenshot.png` (image/png, 122 KB)

![screenshot.png](data:image/png;base64,iVBORw0KGgoAAAANSUhEUg...)

### Image 2: `wireframe.jpg` (image/jpeg, 89 KB)

![wireframe.jpg](data:image/jpeg;base64,/9j/4AAQSkZJRgABAQAA...)

---

**Instructions for AI:**
- Carefully analyze the image(s) above as part of your task context
- For UI/UX tasks: match the visual design shown in screenshots/wireframes
- For bug reports: identify issues visible in error screenshots
- For architecture: follow the structure shown in diagrams
```

**GitHub Actions Integration:**

Both scripts set output variables when run in GitHub Actions:

```yaml
- name: Fetch attachments
  id: attachments
  run: ./fetch-jira-attachments.sh ...

# Outputs:
# - has_images: "true" or "false"
# - image_count: number of processed images
# - total_size: total size in bytes

- name: Build context
  id: context
  run: ./build-image-context.sh

# Outputs:
# - image_context: full markdown content (multi-line)
# - has_images: "true" or "false"
# - processed_count: number of images included
```

## Usage in Workflows

### Router Repository (Quality Gate)

```yaml
- name: Fetch and encode Jira attachments
  id: attachments
  run: |
    bash .github/scripts/fetch-jira-attachments.sh \
      "$JIRA_BASE" \
      "${{ steps.payload.outputs.issue_key }}" \
      "$JIRA_EMAIL" \
      "$JIRA_API_TOKEN"

- name: Build image context
  id: image-context
  run: |
    bash .github/scripts/build-image-context.sh

- name: AI Quality Check (with vision)
  run: |
    # Load image context
    IMAGE_CONTEXT=$(cat .artifacts/image-context.md)

    # Include in prompt
    PROMPT="${IMAGE_CONTEXT}\n\nEvaluate this ticket..."
```

### Target Repository (Implementation)

```yaml
- name: Fetch images
  run: |
    # Re-fetch from Jira for security
    bash .github/scripts/fetch-jira-attachments.sh ...
    bash .github/scripts/build-image-context.sh

- name: Codex planning (with vision)
  uses: openai/codex-action@v1
  with:
    prompt: |
      ${{ steps.image-context.outputs.image_context }}

      Create implementation plan matching the UI shown above...

- name: Claude Code (with vision)
  uses: anthropics/claude-code-action@v1
  with:
    prompt: |
      VISUAL CONTEXT:
      ${{ steps.image-context.outputs.image_context }}

      Implement the UI exactly as shown in the screenshots...
```

## Testing

### Manual Test

```bash
# Set environment variables
export JIRA_BASE="https://yourcompany.atlassian.net"
export JIRA_EMAIL="your-email@company.com"
export JIRA_API_TOKEN="your-api-token"
export ISSUE_KEY="TEST-123"

# Test fetch
./fetch-jira-attachments.sh "$JIRA_BASE" "$ISSUE_KEY" "$JIRA_EMAIL" "$JIRA_API_TOKEN"

# Check output
ls -lh .artifacts/images/
cat .artifacts/images.json | jq

# Test build
./build-image-context.sh

# Check output
cat .artifacts/image-context.md
```

### Expected Output

```
🔍 Fetching issue TEST-123 from Jira...
📎 Found 3 attachment(s)
🖼️  Found 2 image/PDF attachment(s)

📥 Downloading: screenshot.png (image/png, 245 KB)
✅ Downloaded successfully
🔄 Resizing to max 1024x1024 (preserving aspect ratio)...
✅ Resized from 245 KB to 89 KB
🔐 Encoding to base64...
✅ Processed successfully (base64 size: 119 KB)

📥 Downloading: wireframe.pdf (application/pdf, 1.2 MB)
✅ Downloaded successfully
📄 Converting PDF to PNG (first page)...
✅ Converted to wireframe.png
🔐 Encoding to base64...
✅ Processed successfully (base64 size: 156 KB)

🎉 Summary:
   Total attachments: 3
   Image/PDF attachments: 2
   Successfully processed: 2
   Total size: 245 KB

📄 Output: .artifacts/images.json
```

## Security Considerations

### 1. Re-fetch in Target Repos

**Never trust base64 data passed through repository_dispatch payloads.** Always re-fetch attachments directly from Jira API in target repositories.

**Why?** The router payload could be tampered with. Re-fetching ensures authenticity.

```yaml
# ❌ BAD - trusting payload
image_context: ${{ github.event.client_payload.images }}

# ✅ GOOD - re-fetching
- name: Fetch images securely
  run: |
    bash .github/scripts/fetch-jira-attachments.sh ...
```

### 2. MIME Type Validation

The script validates actual MIME types, not just file extensions:

```bash
# Verify actual image type
file --mime-type screenshot.png
# Output: screenshot.png: image/png ✅
```

### 3. Size Limits

- Per image: 10MB max (Jira limit)
- Base64 encoded: 8MB max
- Total per issue: 20MB recommended

### 4. Filename Sanitization

All filenames are sanitized to prevent path traversal:

```bash
# Remove path traversal attacks
filename=$(basename "$filename")
filename="${filename//[^a-zA-Z0-9._-]/}"
```

## Error Handling

### No Images Attached

```bash
# Script creates empty images.json
{"images":[],"count":0,"total_size":0}

# Workflow continues without image context
```

### Image Download Fails

```bash
# Retries 3 times with exponential backoff
⚠️  Retry 1/3...
⚠️  Retry 2/3...
❌ Failed to download after 3 attempts, skipping...

# Continues with remaining images
```

### PDF Conversion Fails

```bash
# Checks if ImageMagick is installed
⚠️  ImageMagick not installed, skipping PDF conversion

# Or if conversion fails:
❌ PDF conversion failed, skipping...
```

### Image Too Large

```bash
# Resizes automatically
🔄 Resizing to max 1024x1024...
✅ Resized from 5.2 MB to 1.8 MB

# Or skips if still too large
⚠️  Base64 too large (9.5 MB), skipping...
```

## Troubleshooting

### "ImageMagick not installed"

**Fix:**
```bash
# Ubuntu/Debian
sudo apt-get update && sudo apt-get install -y imagemagick

# macOS
brew install imagemagick
```

### "curl: Failed to connect"

Check Jira API connectivity:
```bash
curl -v "$JIRA_BASE/rest/api/3/myself" \
  -u "$JIRA_EMAIL:$JIRA_API_TOKEN"
```

### "jq: command not found"

Install jq:
```bash
# Ubuntu/Debian
sudo apt-get install -y jq

# macOS
brew install jq
```

### "Base64 output truncated"

GitHub Actions has a 100KB output variable limit. For large images:

**Option A:** Use artifacts instead
```yaml
- uses: actions/upload-artifact@v4
  with:
    name: images
    path: .artifacts/images/
```

**Option B:** Reduce max_images
```bash
./build-image-context.sh 3  # Only include 3 images
```

## Performance Tips

1. **Limit images**: Use `max_images` parameter
2. **Resize early**: Script auto-resizes to 1024x1024
3. **Skip large PDFs**: Multi-page PDFs only convert first page
4. **Parallel downloads**: Script downloads sequentially (future: parallel)

## Future Enhancements

- [ ] Parallel image downloads
- [ ] Multi-page PDF support
- [ ] OCR for text extraction
- [ ] Image hash for caching
- [ ] CDN upload for URL references (instead of base64)
