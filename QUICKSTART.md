# 🚀 Quick Start Guide - Setup Azmi Bot in 30 Minutes

This is a simplified guide for setting up Azmi Bot from scratch. If you get stuck, refer to the [full README](README.md) for detailed explanations.

## Prerequisites Checklist

Before you start, make sure you have:

- [ ] Jira Cloud account with admin access
- [ ] GitHub organization or personal account
- [ ] OpenAI API key ([Get it here](https://platform.openai.com/api-keys))
- [ ] Anthropic API key ([Get it here](https://console.anthropic.com))
- [ ] 30 minutes of focused time

## Setup Steps Overview

```
Step 1: Fork Router Repo          (5 min)
Step 2: Setup Jira Custom Fields   (5 min)
Step 3: Configure GitHub Secrets   (5 min)
Step 4: Create Jira Automation     (10 min)
Step 5: Setup Target Repo          (5 min)
Step 6: Test the Flow              (5 min)
```

---

## Step 1: Fork and Setup Router Repository (5 min)

### 1.1 Fork This Repository

```bash
# Click "Fork" button on GitHub, then clone
git clone https://github.com/YOUR_USERNAME/router.git
cd router
```

### 1.2 Add GitHub Secrets

Go to your forked repo → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

Add these 5 secrets:

| Secret Name | Value | Where to Get It |
|-------------|-------|-----------------|
| `OPENAI_API_KEY` | `sk-...` | https://platform.openai.com/api-keys |
| `JIRA_BASE` | `https://yourcompany.atlassian.net` | Your Jira URL (no trailing slash) |
| `JIRA_EMAIL` | `bot@yourcompany.com` | Create a service account in Jira |
| `JIRA_API_TOKEN` | `ATATT3...` | https://id.atlassian.com/manage-profile/security/api-tokens |
| `DISPATCH_PAT` | `github_pat_...` | See Step 1.3 below |

### 1.3 Create DISPATCH_PAT Token

This token allows the router to trigger workflows in other repos.

1. Go to GitHub → Your profile photo → **Settings**
2. **Developer settings** → **Personal access tokens** → **Fine-grained tokens**
3. Click **Generate new token**
4. Fill in:
   - **Token name**: `azmi-bot-router`
   - **Expiration**: 90 days
   - **Repository access**: Only select repositories → Choose your target repos (e.g., `win-room`, `api-service`)
   - **Repository permissions**:
     - Contents: **Read and write** ✅
     - Pull requests: **Read and write** ✅
     - Metadata: Read-only (automatic) ✅
5. Click **Generate token** → Copy it immediately
6. Add as `DISPATCH_PAT` secret in router repo

**✅ Step 1 Complete!** Router repo is configured.

---

## Step 2: Setup Jira Custom Fields (5 min)

### 2.1 Create Three Custom Fields

In Jira → **Settings (⚙️)** → **Issues** → **Custom fields** → **Create custom field**

Create these 3 fields:

#### Field 1: AI Quality Score
- Type: **Number**
- Name: `AI Quality Score`
- Description: `Score from 0-100 assigned by AI quality gate`
- Add to all relevant screens

#### Field 2: AI Quality Verdict
- Type: **Select List (single choice)**
- Name: `AI Quality Verdict`
- Options:
  - `pass`
  - `fail`
- Add to all relevant screens

#### Field 3: AI Target Repo
- Type: **Select List (single choice)**
- Name: `AI Target Repo`
- Options (add your repos):
  - `YOUR_ORG/win-room`
  - `YOUR_ORG/api-service`
  - `YOUR_ORG/mobile-app`
- Add to all relevant screens

### 2.2 Find Custom Field IDs (IMPORTANT!)

You'll need these IDs for Step 4.

**Method 1: Via Browser Inspector**
1. Go to any Jira issue → Click **Edit**
2. Right-click on each custom field → **Inspect**
3. Find `customfield_XXXXX` in the HTML
4. Write down the IDs:
   - AI Quality Score: `customfield_______`
   - AI Quality Verdict: `customfield_______`
   - AI Target Repo: `customfield_______`

**Method 2: Via API**
```bash
curl -u "YOUR_EMAIL:YOUR_API_TOKEN" \
  "https://yourcompany.atlassian.net/rest/api/3/field" \
  | jq '.[] | select(.name | contains("AI")) | {name: .name, id: .id}'
```

**📝 Write down your field IDs - you'll need them in Step 4!**

**✅ Step 2 Complete!** Jira fields are ready.

---

## Step 3: Update Router Workflow with Field IDs (5 min)

### 3.1 Edit router.yml

Open `.github/workflows/router.yml` in your forked repo.

**Find this section (around line 135):**

```yaml
curl -sS -X PUT "$JIRA_BASE/rest/api/3/issue/$ISSUE" \
  -H "Authorization: Basic $AUTH" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  --data '{"fields":{"customfield_12345":'"$SCORE"',"customfield_12346":"'"$VERDICT"'"}}'
```

**Replace `customfield_12345` and `customfield_12346` with YOUR field IDs:**

```yaml
# Replace with your actual IDs from Step 2.2
--data '{"fields":{"customfield_YOUR_SCORE_ID":'"$SCORE"',"customfield_YOUR_VERDICT_ID":"'"$VERDICT"'"}}'
```

Example:
```yaml
--data '{"fields":{"customfield_10037":'"$SCORE"',"customfield_10038":"'"$VERDICT"'"}}'
```

### 3.2 Commit and Push

```bash
git add .github/workflows/router.yml
git commit -m "Update Jira custom field IDs"
git push origin main
```

**✅ Step 3 Complete!** Router workflow configured.

---

## Step 4: Create Jira Automation (10 min)

This automation triggers the router when you assign a ticket to "Azmi Bot".

### 4.1 Create Service Account in Jira

1. Go to Jira → **Settings** → **User management**
2. Click **Create user**
3. Fill in:
   - Email: `azmi-bot@yourcompany.com`
   - Full name: `Azmi Bot`
   - Grant project access
4. Login as this user and generate API token (if not done already)

### 4.2 Create Automation Rule

1. Go to your Jira project → **Project settings** → **Automation**
2. Click **Create rule**
3. Configure:

**Trigger:**
- When: **Issue transitioned**
- From any status: ✅
- To status: *(leave empty for any)*
- **Add condition**: Assignee → equals → `Azmi Bot`

**Action:** Send web request
- URL: `https://api.github.com/repos/YOUR_ORG/router/dispatches`
  - Replace `YOUR_ORG` with your GitHub username or org
- HTTP method: `POST`
- Headers:
  ```
  Accept: application/vnd.github+json
  Authorization: Bearer YOUR_GITHUB_PAT
  Content-Type: application/json
  ```
  - Replace `YOUR_GITHUB_PAT` with a GitHub PAT (you can reuse `DISPATCH_PAT`)

- Body (Custom data):
  ```json
  {
    "event_type": "ai-coding-request",
    "client_payload": {
      "issue_key": "{{issue.key}}",
      "title": "{{issue.summary}}",
      "description": "{{issue.description}}",
      "target_repo": "{{issue.AI Target Repo}}",
      "url": "{{issue.url}}"
    }
  }
  ```

4. **Name the rule**: `Azmi Bot Trigger`
5. Click **Turn it on**

### 4.3 Test the Automation

1. Create a test Jira ticket:
   - Title: `Test Azmi Bot Integration`
   - Description: `This is a test ticket to verify the automation works`
   - AI Target Repo: Select one of your repos
2. Assign to **Azmi Bot**
3. Go to GitHub → Your router repo → **Actions**
4. You should see a workflow run starting!

**✅ Step 4 Complete!** Jira automation is working.

---

## Step 5: Setup Target Repository (5 min)

Now setup one of your target repos to receive tasks from the router.

### 5.1 Add Secrets to Target Repo

Go to your target repo (e.g., `win-room`) → **Settings** → **Secrets and variables** → **Actions**

Add these 5 secrets:

| Secret | Value | Same as Router? |
|--------|-------|-----------------|
| `OPENAI_API_KEY` | Your OpenAI key | ✅ Yes |
| `ANTHROPIC_API_KEY` | Your Anthropic key | ➕ New |
| `JIRA_BASE` | Your Jira URL | ✅ Yes |
| `JIRA_EMAIL` | Bot email | ✅ Yes |
| `JIRA_API_TOKEN` | Jira token | ✅ Yes |
| `GH_PAT` | GitHub PAT | ➕ New (see below) |

### 5.2 Create GH_PAT Token

Similar to DISPATCH_PAT, but for this specific repo:

1. GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens
2. Generate new token:
   - Name: `azmi-bot-target-repo`
   - Repository access: Only select repositories → Select THIS target repo
   - Permissions:
     - Contents: Read and write
     - Pull requests: Read and write
     - Workflows: Read and write
3. Generate → Copy → Add as `GH_PAT` secret

### 5.3 Copy Workflow Files

Copy the workflow files from `router/target_repo/` to your target repo:

```bash
cd /path/to/your/target-repo
mkdir -p .github/workflows

# Copy from router repo
cp /path/to/router/target_repo/ai-coding.yml .github/workflows/
cp /path/to/router/target_repo/ai-revision.yml .github/workflows/
cp /path/to/router/target_repo/codex-review.yml .github/workflows/

git add .github/workflows/
git commit -m "Add Azmi Bot workflows"
git push origin main
```

### 5.4 Enable Workflow Permissions

In target repo: **Settings** → **Actions** → **General** → **Workflow permissions**

- ✅ **Read and write permissions**
- ✅ **Allow GitHub Actions to create and approve pull requests**

Click **Save**

**✅ Step 5 Complete!** Target repo is ready.

---

## Step 6: Test End-to-End Flow (5 min)

Let's test the entire pipeline!

### 6.1 Create a Real Test Ticket

Create a Jira ticket:

**Title:** `Add hello world endpoint`

**Description:**
```
Create a new API endpoint /api/hello that returns:
{
  "message": "Hello World",
  "timestamp": "2025-01-16T12:00:00Z"
}

The endpoint should:
- Accept GET requests
- Return JSON response
- Include current timestamp
- Add unit test

File: src/api/hello.ts (or appropriate path for your repo)
```

**AI Target Repo:** Select your target repo

**Assign to:** Azmi Bot

### 6.2 Watch the Magic Happen

1. **Router runs** (30 seconds - 1 min):
   - Go to router repo → Actions → You should see `router-ai-quality-gate` running
   - AI scores the ticket
   - Posts result to Jira as comment
   - If score ≥ 80, dispatches to target repo

2. **Check Jira** (refresh your ticket):
   - You should see AI Quality Score: 85 (or similar)
   - Comment from Azmi Bot with analysis

3. **Target repo runs** (2-5 min):
   - Go to target repo → Actions → You should see `AI Coding` workflow
   - Job 1: Codex creates TSD
   - Job 2: Claude Code implements

4. **PR is created** (3-5 min):
   - Go to target repo → Pull requests
   - You should see a new PR: `AI Coding - YOUR-TICKET-123`
   - Review the code!

5. **Review workflow runs** (1-2 min):
   - Codex reviews the PR
   - Claude Code adds secondary review
   - If approved, PR auto-merges

**✅ If you see a PR, congratulations! 🎉 Azmi Bot is working!**

---

## Troubleshooting

### Router not triggering?

**Check:**
- Jira automation rule is enabled
- GitHub PAT in Jira automation is valid
- Webhook payload format matches

**Debug:**
```bash
# Manually trigger router
curl -X POST \
  -H "Authorization: Bearer YOUR_PAT" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/YOUR_ORG/router/dispatches \
  -d '{"event_type":"ai-coding-request","client_payload":{"issue_key":"TEST-1","title":"Test","description":"Test task","target_repo":"YOUR_ORG/YOUR_REPO"}}'
```

### Target repo not receiving dispatch?

**Check:**
- `DISPATCH_PAT` has access to target repo
- Ticket score ≥ 80 (check router logs)
- Target repo has `ai-coding.yml` workflow

### PR not created?

**Check:**
- `GH_PAT` secret exists in target repo
- Workflow permissions allow PR creation
- Check workflow logs for errors

### Jira fields not updating?

**Check:**
- Custom field IDs are correct in `router.yml`
- JIRA_API_TOKEN has permission to edit issues

---

## Next Steps

Now that Azmi Bot is working:

1. **Try image support**: Attach a screenshot to a Jira ticket
2. **Test revision flow**: Comment `#AZMI fix the button color` on a merged ticket
3. **Customize prompts**: Edit AI prompts in workflow files
4. **Add more repos**: Expand to other repositories
5. **Read full docs**: Check [README.md](README.md) for advanced features

---

## Need Help?

- 📖 [Full Documentation](README.md)
- 🐛 [Report Issues](https://github.com/htuzel/router/issues)
- 💬 [Discussions](https://github.com/htuzel/router/discussions)
- 🔒 [Security Policy](SECURITY.md)

---

**Happy Automating! 🤖**
