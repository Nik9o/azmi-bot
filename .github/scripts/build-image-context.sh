#!/bin/bash
set -euo pipefail

##############################################################################
# Build Image Context for AI Prompts
#
# Usage: build-image-context.sh [max_images]
#
# This script:
# 1. Reads images.json
# 2. Builds markdown-formatted context with embedded base64 images
# 3. Outputs to image-context.md
# 4. Sets GitHub Actions output variables
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

MAX_IMAGES="${1:-5}"  # Default: include max 5 images

# Check if images.json exists
if [ ! -f .artifacts/images.json ]; then
  echo "⚠️  No images.json found, creating empty context"
  echo "" > .artifacts/image-context.md

  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "image_context=" >> "$GITHUB_OUTPUT"
    echo "has_images=false" >> "$GITHUB_OUTPUT"
  fi

  exit 0
fi

cd .artifacts

IMAGE_COUNT=$(jq -r '.count' images.json)

if [ "$IMAGE_COUNT" -eq 0 ]; then
  echo "📭 No images to process"
  echo "" > image-context.md

  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    echo "image_context=" >> "$GITHUB_OUTPUT"
    echo "has_images=false" >> "$GITHUB_OUTPUT"
  fi

  exit 0
fi

# Limit to MAX_IMAGES
IMAGES_TO_PROCESS=$IMAGE_COUNT
if [ "$IMAGE_COUNT" -gt "$MAX_IMAGES" ]; then
  IMAGES_TO_PROCESS=$MAX_IMAGES
  echo "🖼️  Building image context for $IMAGES_TO_PROCESS image(s) (out of $IMAGE_COUNT total, limited to last $MAX_IMAGES)..."
else
  echo "🖼️  Building image context for $IMAGES_TO_PROCESS image(s)..."
fi

# Start building markdown context
{
  echo "## 🖼️ Visual Context"
  echo ""
  echo "You have been provided with **$IMAGES_TO_PROCESS image(s)** attached to this Jira ticket:"
  echo ""
} > image-context.md

# If limiting images, update images.json to only include last N images
if [ "$IMAGE_COUNT" -gt "$MAX_IMAGES" ]; then
  echo "📦 Limiting images.json to last $MAX_IMAGES image(s)..."

  # Create limited version of images.json
  jq --argjson max "$MAX_IMAGES" '
    .images = (.images | .[-$max:]) |
    .count = ($max)
  ' images.json > images-limited.json

  mv images-limited.json images.json

  # Update count for processing
  IMAGE_COUNT=$MAX_IMAGES
  IMAGES_TO_PROCESS=$MAX_IMAGES
fi

# Process each image (up to MAX_IMAGES) - use tail to get last N images
PROCESSED=0

jq -c '.images[]' images.json | while IFS= read -r image; do
  FILENAME=$(echo "$image" | jq -r '.filename')
  MIME_TYPE=$(echo "$image" | jq -r '.mime_type')
  SIZE=$(echo "$image" | jq -r '.size')
  DATA_URI=$(echo "$image" | jq -r '.data_uri')

  # Format size for display
  SIZE_HUMAN=$(format_size "$SIZE")

  PROCESSED=$((PROCESSED + 1))

  echo "   Processing $PROCESSED/$IMAGES_TO_PROCESS: $FILENAME"

  {
    echo "### Image $PROCESSED: \`$FILENAME\` ($MIME_TYPE, $SIZE_HUMAN)"
    echo ""
    echo "![${FILENAME}](${DATA_URI})"
    echo ""
  } >> image-context.md
done

# Add footer instructions
{
  echo ""
  echo "---"
  echo ""
  echo "**Instructions for AI:**"
  echo "- Carefully analyze the image(s) above as part of your task context"
  echo "- For UI/UX tasks: match the visual design shown in screenshots/wireframes"
  echo "- For bug reports: identify issues visible in error screenshots"
  echo "- For architecture: follow the structure shown in diagrams"
  echo ""
} >> image-context.md

echo "✅ Image context built successfully"
echo "📄 Output: .artifacts/image-context.md"

# Output for GitHub Actions
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  # Read full context for output
  CONTEXT=$(cat image-context.md)

  # Use EOF delimiter for multi-line output
  {
    echo "image_context<<EOF"
    echo "$CONTEXT"
    echo "EOF"
  } >> "$GITHUB_OUTPUT"

  echo "has_images=true" >> "$GITHUB_OUTPUT"
  echo "processed_count=$PROCESSED" >> "$GITHUB_OUTPUT"
fi

echo ""
echo "🎉 Context ready for AI consumption!"
