#!/bin/bash
set -euo pipefail

##############################################################################
# Fetch Jira Attachments and Encode as Base64
#
# Usage: fetch-jira-attachments.sh <JIRA_BASE> <ISSUE_KEY> <JIRA_EMAIL> <JIRA_API_TOKEN>
#
# This script:
# 1. Fetches issue metadata from Jira REST API
# 2. Filters for image attachments (png, jpg, jpeg, gif, webp, pdf)
# 3. Downloads each image
# 4. Converts PDFs to PNG (first page only)
# 5. Resizes large images to max 1024x1024
# 6. Encodes to base64
# 7. Outputs images.json with all image data
##############################################################################

# Helper function for human-readable file sizes (macOS compatible)
format_size() {
  local size=$1
  if command -v numfmt &> /dev/null; then
    numfmt --to=iec-i --suffix=B "$size"
  else
    # Fallback for macOS (no numfmt)
    if [ "$size" -lt 1024 ]; then
      echo "${size}B"
    elif [ "$size" -lt 1048576 ]; then
      echo "$((size / 1024))KB"
    else
      echo "$((size / 1048576))MB"
    fi
  fi
}

JIRA_BASE="${1:-}"
ISSUE_KEY="${2:-}"
JIRA_EMAIL="${3:-}"
JIRA_API_TOKEN="${4:-}"

if [ -z "$JIRA_BASE" ] || [ -z "$ISSUE_KEY" ] || [ -z "$JIRA_EMAIL" ] || [ -z "$JIRA_API_TOKEN" ]; then
  echo "ERROR: Missing required arguments"
  echo "Usage: $0 <JIRA_BASE> <ISSUE_KEY> <JIRA_EMAIL> <JIRA_API_TOKEN>"
  exit 1
fi

# Create artifacts directory
mkdir -p .artifacts/images
cd .artifacts

# Generate auth header
AUTH=$(printf "%s:%s" "$JIRA_EMAIL" "$JIRA_API_TOKEN" | base64 | tr -d '\n')

echo "🔍 Fetching issue $ISSUE_KEY from Jira..."

# Fetch issue with attachments
curl -sS -H "Authorization: Basic $AUTH" \
  -H "Accept: application/json" \
  "$JIRA_BASE/rest/api/3/issue/$ISSUE_KEY" \
  -o issue-full.json

# Check if attachments exist
ATTACHMENT_COUNT=$(jq -r '.fields.attachment | length' issue-full.json)

if [ "$ATTACHMENT_COUNT" -eq 0 ]; then
  echo "📎 No attachments found on issue $ISSUE_KEY"
  echo '{"images":[],"count":0,"total_size":0}' > images.json
  exit 0
fi

echo "📎 Found $ATTACHMENT_COUNT attachment(s)"

# Extract image attachments (filter by mime type)
jq -r '.fields.attachment[] | select(.mimeType | test("image/|application/pdf")) | @json' issue-full.json > attachments.jsonl

IMAGE_COUNT=$(wc -l < attachments.jsonl | tr -d ' ')

if [ "$IMAGE_COUNT" -eq 0 ]; then
  echo "🖼️  No image attachments found"
  echo '{"images":[],"count":0,"total_size":0}' > images.json
  exit 0
fi

echo "🖼️  Found $IMAGE_COUNT image/PDF attachment(s)"

# Initialize images array
echo '{"images":[],"count":0,"total_size":0}' > images.json

TOTAL_SIZE=0
PROCESSED_COUNT=0

# Process each attachment
while IFS= read -r attachment; do
  FILENAME=$(echo "$attachment" | jq -r '.filename')
  MIME_TYPE=$(echo "$attachment" | jq -r '.mimeType')
  SIZE=$(echo "$attachment" | jq -r '.size')
  CONTENT_URL=$(echo "$attachment" | jq -r '.content')
  ATTACHMENT_ID=$(echo "$attachment" | jq -r '.id')

  # Sanitize filename (remove special chars)
  SAFE_FILENAME=$(basename "$FILENAME" | tr -cd '[:alnum:]._-')

  # Get file extension
  EXT="${SAFE_FILENAME##*.}"
  EXT_LOWER=$(echo "$EXT" | tr '[:upper:]' '[:lower:]')

  echo ""
  echo "📥 Downloading: $FILENAME ($MIME_TYPE, $(format_size $SIZE))"

  # Download attachment with retry
  for i in {1..3}; do
    if curl -f -L -sS -H "Authorization: Basic $AUTH" \
         "$CONTENT_URL" \
         -o "images/$SAFE_FILENAME"; then
      echo "✅ Downloaded successfully"
      break
    else
      if [ $i -eq 3 ]; then
        echo "❌ Failed to download after 3 attempts, skipping..."
        continue 2
      fi
      echo "⚠️  Retry $i/3..."
      sleep $((2**i))
    fi
  done

  # Verify download
  if [ ! -f "images/$SAFE_FILENAME" ]; then
    echo "❌ File not found after download, skipping..."
    continue
  fi

  ACTUAL_SIZE=$(stat -f%z "images/$SAFE_FILENAME" 2>/dev/null || stat -c%s "images/$SAFE_FILENAME" 2>/dev/null)

  # Skip if empty
  if [ "$ACTUAL_SIZE" -eq 0 ]; then
    echo "❌ Downloaded file is empty (0 bytes), skipping..."
    rm "images/$SAFE_FILENAME"
    continue
  fi

  # Skip if too large (> 10MB)
  if [ "$ACTUAL_SIZE" -gt 10485760 ]; then
    echo "⚠️  File too large ($(format_size $ACTUAL_SIZE)), skipping..."
    rm "images/$SAFE_FILENAME"
    continue
  fi

  # Process PDF: convert first page to PNG
  if [ "$MIME_TYPE" = "application/pdf" ]; then
    echo "📄 Converting PDF to PNG (first page)..."

    # Check if imagemagick is available
    if ! command -v convert &> /dev/null; then
      echo "⚠️  ImageMagick not installed, skipping PDF conversion"
      rm "images/$SAFE_FILENAME"
      continue
    fi

    PNG_FILENAME="${SAFE_FILENAME%.*}.png"

    if convert -density 200 "images/$SAFE_FILENAME[0]" "images/$PNG_FILENAME" 2>/dev/null; then
      echo "✅ Converted to $PNG_FILENAME"
      rm "images/$SAFE_FILENAME"
      SAFE_FILENAME="$PNG_FILENAME"
      MIME_TYPE="image/png"
      ACTUAL_SIZE=$(stat -f%z "images/$SAFE_FILENAME" 2>/dev/null || stat -c%s "images/$SAFE_FILENAME" 2>/dev/null)
    else
      echo "❌ PDF conversion failed, skipping..."
      rm "images/$SAFE_FILENAME"
      continue
    fi
  fi

  # Optimize all images for AI consumption (reduce base64 size)
  if [ "$EXT_LOWER" = "png" ] || [ "$EXT_LOWER" = "jpg" ] || [ "$EXT_LOWER" = "jpeg" ]; then
    echo "🔄 Optimizing image for AI (resize + compress)..."

    if command -v convert &> /dev/null; then
      ORIGINAL_SIZE=$ACTUAL_SIZE

      # Target: 800x600 max, JPEG quality 75, strip metadata
      # This reduces 2-3MB PNGs to 50-100KB JPEGs while keeping good quality for AI
      OPTIMIZED_FILENAME="${SAFE_FILENAME%.*}.jpg"

      if convert "images/$SAFE_FILENAME" \
           -resize 800x600\> \
           -quality 75 \
           -strip \
           "images/$OPTIMIZED_FILENAME" 2>/dev/null; then

        # Replace original with optimized version
        if [ "$SAFE_FILENAME" != "$OPTIMIZED_FILENAME" ]; then
          rm "images/$SAFE_FILENAME"
          SAFE_FILENAME="$OPTIMIZED_FILENAME"
          MIME_TYPE="image/jpeg"
        fi

        ACTUAL_SIZE=$(stat -f%z "images/$SAFE_FILENAME" 2>/dev/null || stat -c%s "images/$SAFE_FILENAME" 2>/dev/null)
        REDUCTION=$((100 - (ACTUAL_SIZE * 100 / ORIGINAL_SIZE)))

        echo "✅ Optimized: $(format_size $ORIGINAL_SIZE) → $(format_size $ACTUAL_SIZE) (-${REDUCTION}%)"
      else
        echo "⚠️  Optimization failed, using original"
      fi
    fi
  fi

  # Encode to base64 (macOS compatible)
  echo "🔐 Encoding to base64..."
  if base64 --help 2>&1 | grep -q "\-w"; then
    # GNU base64 (Linux)
    BASE64_DATA=$(base64 -w 0 "images/$SAFE_FILENAME")
  else
    # BSD base64 (macOS) - remove newlines
    BASE64_DATA=$(base64 -i "images/$SAFE_FILENAME" | tr -d '\n')
  fi

  # Check base64 size (should be ~33% larger than original)
  BASE64_SIZE=${#BASE64_DATA}

  if [ "$BASE64_SIZE" -gt 8388608 ]; then  # 8MB limit for base64
    echo "⚠️  Base64 too large ($(format_size $BASE64_SIZE)), skipping..."
    rm "images/$SAFE_FILENAME"
    continue
  fi

  # Create data URI
  DATA_URI="data:${MIME_TYPE};base64,${BASE64_DATA}"

  # Add to images.json
  TMP_JSON=$(mktemp)
  jq --arg filename "$SAFE_FILENAME" \
     --arg mime "$MIME_TYPE" \
     --arg size "$ACTUAL_SIZE" \
     --arg base64 "$BASE64_DATA" \
     --arg data_uri "$DATA_URI" \
     '.images += [{
       filename: $filename,
       mime_type: $mime,
       size: ($size | tonumber),
       base64: $base64,
       data_uri: $data_uri
     }]' images.json > "$TMP_JSON"

  mv "$TMP_JSON" images.json

  TOTAL_SIZE=$((TOTAL_SIZE + ACTUAL_SIZE))
  PROCESSED_COUNT=$((PROCESSED_COUNT + 1))

  echo "✅ Processed successfully (base64 size: $(format_size $BASE64_SIZE))"

done < attachments.jsonl

# Update count and total_size
TMP_JSON=$(mktemp)
jq --arg count "$PROCESSED_COUNT" \
   --arg total "$TOTAL_SIZE" \
   '.count = ($count | tonumber) | .total_size = ($total | tonumber)' images.json > "$TMP_JSON"
mv "$TMP_JSON" images.json

echo ""
echo "🎉 Summary:"
echo "   Total attachments: $ATTACHMENT_COUNT"
echo "   Image/PDF attachments: $IMAGE_COUNT"
echo "   Successfully processed: $PROCESSED_COUNT"
echo "   Total size: $(format_size $TOTAL_SIZE)"
echo ""
echo "📄 Output: .artifacts/images.json"

# Output to GitHub Actions if running in CI
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "has_images=$([[ $PROCESSED_COUNT -gt 0 ]] && echo 'true' || echo 'false')" >> "$GITHUB_OUTPUT"
  echo "image_count=$PROCESSED_COUNT" >> "$GITHUB_OUTPUT"
  echo "total_size=$TOTAL_SIZE" >> "$GITHUB_OUTPUT"
fi
