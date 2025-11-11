---
id: doc-002
title: LLM Schema Assistant Testing
type: testing
created_date: '2025-10-23 16:30'
---

# Testing the LLM Schema Assistant

This guide will help you quickly set up and test the LLM Schema Assistant feature.

## Quick Start

### 1. Start Test Environment

Start Kafka + Schema Registry (no SSL/auth required):

```bash
just test-schema-registry-up
```

This will start:
- Kafka (KRaft mode - no Zookeeper) on port 9092
- Schema Registry on port 8085

**Note**: Uses Apache Kafka 4.1.0 (latest) with KRaft mode + Confluent Schema Registry 8.1.0 (latest)
**Port 8085**: Changed from 8081 to avoid conflicts with other services

### 2. Create Sample Schema

```bash
just test-schema-registry-create-sample
```

This creates a sample AVRO schema named `user-events-value`.

### 3. Start Backend

In a new terminal:

```bash
just test-backend
```

The backend will start on port 51080 with the test cluster configured.

### 4. Start Frontend

In another terminal:

```bash
just frontend
```

The frontend will start on port 51081.

### 5. Open the UI

Open your browser to: http://localhost:51081

Navigate to: **Clusters → test-local → Schema Registry**

## Testing the LLM Assistant

### Step 1: Configure OpenRouter API Key

1. Get your API key from https://openrouter.ai/keys
2. In the schema edit page, you'll see an API key configuration banner
3. Enter your API key and click "Save"
4. The key is stored in browser localStorage

### Step 2: Select an LLM Model

1. Once the API key is configured, the model dropdown will load
2. Select a model (e.g., "claude-3.5-sonnet", "gpt-4", etc.)
3. Available models depend on your OpenRouter subscription

### Step 3: Edit a Schema

1. Click on the `user-events-value` schema
2. Click the "Edit" button
3. You'll see the three-column layout:
   - **Left**: Latest schema (read-only)
   - **Middle**: New schema (editable)
   - **Right**: LLM Assistant (chat + artifact)

### Step 4: Chat with the Assistant

Try these example prompts:

**Add a new field:**
```
Add a field called "email" of type string to store the user's email address
```

**Modify field type:**
```
Change the timestamp field to use logical type "timestamp-millis"
```

**Add documentation:**
```
Add proper documentation to all fields explaining what they represent
```

**Schema evolution:**
```
I want to add an optional field for user preferences. Make sure it's compatible with existing consumers
```

### Step 5: Review Proposed Schema

1. The LLM response appears in the chat
2. If a schema is detected, it's extracted and shown in the "Proposed Schema" panel
3. The schema appears in a read-only JSON editor with syntax highlighting

### Step 6: Validate and Copy

1. Click **"Validate AVRO"** to check the schema is valid
   - Green checkmark = valid schema
   - Red warning = validation errors

2. Click **"Copy to Editor"** to transfer the schema to the main editor
   - The schema is copied to the "New Schema" editor
   - The form is marked as "dirty" and ready to submit

3. Make any final manual adjustments if needed

4. Click **"Submit"** to save the new schema version

## Testing Non-AVRO Schemas

The LLM Assistant is currently only available for AVRO schemas. To test this:

1. Create a JSON or PROTOBUF schema
2. Try to edit it
3. You should see a warning: "LLM Schema Assistant is currently only available for AVRO schemas"
4. The LLM panels will not be shown

## Useful Commands

### Check Environment Status

```bash
just test-schema-registry-status
```

### View Logs

All services:
```bash
just test-schema-registry-logs
```

Specific service:
```bash
just test-schema-registry-logs kafka
just test-schema-registry-logs schema-registry
```

### List All Schemas

```bash
just test-schema-registry-list
```

### Get Schema Details

```bash
just test-schema-registry-get user-events-value
```

### Delete a Schema

```bash
just test-schema-registry-delete user-events-value
```

### Stop Everything

```bash
just test-schema-registry-down
```

This stops all containers and removes volumes.

## Troubleshooting

### Schema Registry Not Starting

Check the logs:
```bash
just test-schema-registry-logs schema-registry
```

Common issues:
- Port 8081 already in use
- Kafka not fully started yet (wait a bit longer)

### Models Not Loading

1. Check browser console for errors
2. Verify your OpenRouter API key is valid
3. Test the API key manually:
   ```bash
   curl https://openrouter.ai/api/v1/models \
     -H "Authorization: Bearer YOUR_API_KEY"
   ```

### Chat Not Working

1. Ensure you've selected a model
2. Check the browser console for errors
3. Verify the OpenRouter service is accessible
4. Check your API key has credit/quota

### Schema Not Extracted from Chat

The system looks for JSON code blocks in the LLM response:
- Preferred format: ` ```json\n{...}\n``` `
- Alternative format: ` ```\n{...}\n``` `

If extraction fails, the LLM response might not be formatted correctly. Try:
```
Please provide the complete schema in a JSON code block
```

### API Key Lost

API keys are stored in browser localStorage. To clear and re-enter:

1. Open browser DevTools
2. Application → Local Storage → http://localhost:51081
3. Delete the `openrouter_api_key` entry
4. Refresh the page and re-enter your key

Or programmatically:
```javascript
localStorage.removeItem('openrouter_api_key')
```

## Example Testing Workflow

Complete end-to-end test:

```bash
# Terminal 1: Start services
just test-schema-registry-up
sleep 15  # Wait for services to be ready
just test-schema-registry-create-sample

# Terminal 2: Start backend
just test-backend

# Terminal 3: Start frontend
just frontend

# In browser:
# 1. Go to http://localhost:51081
# 2. Navigate to Schema Registry
# 3. Edit user-events-value schema
# 4. Configure OpenRouter API key
# 5. Select a model
# 6. Chat: "Add an email field of type string"
# 7. Validate the proposed schema
# 8. Copy to editor
# 9. Submit the form

# Verify the new schema version
curl -s http://localhost:8081/subjects/user-events-value/versions/2 | jq -r '.schema' | jq '.'

# Cleanup
just test-schema-registry-down
```

## Advanced Testing

### Testing with Multiple Schemas

Create additional test schemas:

```bash
curl -X POST http://localhost:8081/subjects/product-catalog-value/versions \
  -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  -d '{
    "schema": "{\"type\":\"record\",\"name\":\"Product\",\"namespace\":\"com.example\",\"fields\":[{\"name\":\"productId\",\"type\":\"string\"},{\"name\":\"name\",\"type\":\"string\"},{\"name\":\"price\",\"type\":\"double\"}]}"
  }' | jq '.'
```

### Testing Schema Evolution

1. Create a base schema
2. Use LLM to add optional fields
3. Use LLM to modify field types (test compatibility)
4. Verify backward/forward compatibility

### Testing Different LLM Models

Compare responses from different models:
- Claude models (better at structured output)
- GPT models (good general understanding)
- Open source models (may vary in quality)

## Performance Notes

- First model fetch: ~2-5 seconds
- Chat response: ~3-10 seconds (depends on model)
- Schema extraction: < 100ms
- Validation: < 50ms

## Security Reminders

- **Never commit API keys** to git
- API keys are stored in browser localStorage (client-side only)
- For production, consider proxying OpenRouter requests through your backend
- Validate all LLM-generated schemas before applying them
- Review changes before submitting to Schema Registry

## Next Steps

Once you've verified the basic functionality:

1. Test with your production OpenRouter models
2. Test with complex schema requirements
3. Test schema evolution scenarios
4. Provide feedback on UX improvements
5. Test with different browsers

## Feedback

If you encounter issues or have suggestions:

1. Check browser console for errors
2. Check backend logs for API errors
3. Document the reproduction steps
4. Note the LLM model used
5. Include example prompts and responses