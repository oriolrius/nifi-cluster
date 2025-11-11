---
id: doc-001
title: LLM Schema Assistant
type: feature
created_date: '2025-10-23 16:30'
---

# LLM Schema Assistant for Kafka UI

An AI-powered schema editing assistant integrated into the Kafka UI Schema Registry editor.

## Overview

The LLM Schema Assistant provides an AI-powered chat interface to help users create and modify AVRO schemas using OpenRouter API. This integration offers a conversational approach to schema management, making it easier to evolve schemas, add fields, and ensure compliance with AVRO best practices.

## Quick Start

### 1. Start Test Environment

```bash
# Start Kafka 4.1.0 + Schema Registry 8.1.0 (no auth)
just test-schema-registry-up

# Create a sample AVRO schema
just test-schema-registry-create-sample
```

### 2. Start Application

```bash
# Terminal 1: Backend
just test-backend

# Terminal 2: Frontend
just frontend
```

### 3. Configure & Test

1. Open http://localhost:51081
2. Navigate to: **Clusters → test-local → Schema Registry**
3. Edit the `user-events-value` schema
4. Configure your OpenRouter API key (get one at https://openrouter.ai/keys)
5. Select an LLM model
6. Start chatting with the assistant!

## Key Features

### Chat Interface
- Conversational schema editing with context awareness
- Auto-scrolling chat history
- Keyboard shortcuts (Ctrl+Enter to send)
- Automatically extracts schema proposals from LLM responses

### Schema Artifact Panel
- Canvas-style display of LLM proposals (like ChatGPT/Claude)
- One-click copy to transfer proposals directly to the editor
- Read-only JSON editor with syntax highlighting

### Validation & Safety
- AVRO validation with visual feedback
- Client-side validation before applying changes
- Proper error messaging

### Model Selection
- Choose from 100+ models via OpenRouter
- Support for OpenAI, Anthropic, Google, Meta, and more
- Model-specific capabilities

### User Experience
- Collapsible panels for clean interface
- Conditional UI (only enabled for AVRO schemas)
- Responsive three-column layout
- Integration with existing form validation

## Architecture

### Layout Structure

```
┌─────────────────────────────────────────────────────────┐
│  Schema Edit Page (Form.tsx)                            │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  ┌─────────────┐  ┌─────────────┐  ┌────────────────┐  │
│  │   Latest    │  │     New     │  │  LLM Assistant │  │
│  │   Schema    │  │   Schema    │  │                │  │
│  │ (read-only) │  │  (editable) │  │  ┌──────────┐  │  │
│  │             │  │             │  │  │ Artifact │  │  │
│  │             │  │             │  │  │  Panel   │  │  │
│  │             │  │             │  │  └──────────┘  │  │
│  │             │  │             │  │  ┌──────────┐  │  │
│  │             │  │             │  │  │   Chat   │  │  │
│  │             │  │             │  │  │  Panel   │  │  │
│  └─────────────┘  └─────────────┘  │  └──────────┘  │  │
│                                     └────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

### Component Architecture

#### Frontend Components

**LLMApiKeyConfig.tsx** (`frontend/src/components/Schemas/Edit/LLMApiKeyConfig.tsx`)
- Secure API key storage in localStorage
- Configuration banner with save/clear options
- Link to OpenRouter API key page

**LLMModelSelector.tsx** (`frontend/src/components/Schemas/Edit/LLMModelSelector.tsx`)
- Fetches and displays available OpenRouter models
- Allows users to select their preferred LLM model
- Shows loading states and error messages

**LLMChatPanel.tsx** (`frontend/src/components/Schemas/Edit/LLMChatPanel.tsx`)
- Collapsible panel for conversational interface
- Auto-scrolling chat history
- Keyboard shortcuts (Ctrl+Enter to send)
- Automatically extracts schema proposals from LLM responses
- System prompt includes current schema context

**LLMSchemaArtifact.tsx** (`frontend/src/components/Schemas/Edit/LLMSchemaArtifact.tsx`)
- Displays LLM-proposed schemas in a read-only editor
- "Copy to Editor" button to transfer schema to the main editor
- "Validate AVRO" button to check schema compliance
- Visual feedback for validation results

**Form.tsx** (`frontend/src/components/Schemas/Edit/Form.tsx`)
- Main integration point
- Three-column layout (Latest Schema | New Schema | LLM Assistant)
- Responsive design that adapts to smaller screens
- Conditional rendering based on schema type (AVRO only)
- Integration with existing form validation

**Edit.styled.ts** (`frontend/src/components/Schemas/Edit/Edit.styled.ts`)
- `LLMPanelContainer`: Container for collapsible panels
- `LLMPanelHeader`: Clickable header with collapse icon
- `ChatContainer`: Scrollable chat message area
- `ChatMessage`: Individual message bubbles (user/assistant)
- `ArtifactContainer`: Schema proposal display area
- `LLMLayoutWrapper`: Responsive grid layout

#### Services

**openrouter.ts** (`frontend/src/lib/services/openrouter.ts`)
- OpenRouter API integration
- Fetches available LLM models
- Sends chat messages with schema context
- Includes AVRO schema validation

**openrouter.ts (interfaces)** (`frontend/src/lib/interfaces/openrouter.ts`)
- TypeScript type definitions for OpenRouter API
- Model interfaces
- Chat message interfaces
- API response types

## User Flow

### For AVRO Schemas

1. **First Time Setup**
   - Navigate to schema edit page
   - See API key configuration banner
   - Enter OpenRouter API key from https://openrouter.ai/keys
   - API key is stored in localStorage

2. **Select LLM Model**
   - Choose from available OpenRouter models
   - Model list is fetched automatically

3. **Chat with Assistant**
   - Type questions or requests in the chat panel
   - Example: "Add a field for user email address"
   - System automatically includes current schema context
   - Press Ctrl+Enter to send message

4. **Review Proposed Schema**
   - LLM response appears in chat
   - Proposed schema extracted and displayed in artifact panel
   - Read-only JSON editor shows the proposed changes

5. **Validate Schema**
   - Click "Validate AVRO" button
   - See validation results (success/error)
   - Fix any issues with further chat

6. **Copy to Editor**
   - Click "Copy to Editor" button
   - Proposed schema is copied to "New Schema" editor
   - Make additional manual edits if needed
   - Submit the form to save

### For Non-AVRO Schemas (JSON, PROTOBUF)

- LLM Assistant is disabled
- Warning banner explains feature is only available for AVRO
- Standard two-column editor layout remains

## Example Prompts

Try these prompts in the chat:

**Add a field:**
```
Add a field called "email" of type string
```

**Modify field type:**
```
Change the timestamp field to use logical type "timestamp-millis"
```

**Schema evolution:**
```
Add an optional field for user preferences. Make sure it's backward compatible
```

**Documentation:**
```
Add proper documentation to all fields
```

**Complex changes:**
```
I want to add a nested record for user address with street, city, state, and zip code fields
```

## Technical Details

### API Integration

The OpenRouter service uses:
- **Endpoint**: `https://openrouter.ai/api/v1`
- **Authentication**: Bearer token from localStorage
- **Headers**: Includes referer and app title for attribution

### Schema Context

When chatting, the system prompt includes:
- Subject name
- Schema type (AVRO)
- Current schema JSON
- Instructions for best practices

Example system prompt:
```
You are an expert AVRO schema assistant. The user is working on the following schema:

Subject: user-events
Schema Type: AVRO
Current Schema:
```json
{
  "type": "record",
  "name": "UserEvent",
  "fields": [...]
}
```

When suggesting schema changes, provide the complete updated schema in a JSON code block.
Focus on AVRO best practices, proper field types, and schema evolution considerations.
```

### State Management

The Form component manages:
- `apiKeyConfigured`: Whether user has set up OpenRouter key
- `selectedModel`: Currently selected LLM model
- `proposedSchema`: Latest schema proposal from LLM
- `isAvroSchema`: Whether current schema type is AVRO
- `llmEnabled`: Combined flag (AVRO + API key configured)

### Schema Extraction

The chat panel automatically extracts schemas from LLM responses using regex:
```typescript
const schemaMatch =
  assistantMessage.content.match(/```json\s*([\s\S]*?)```/) ||
  assistantMessage.content.match(/```\s*([\s\S]*?)```/);
```

### AVRO Validation

Basic AVRO validation checks:
- Valid JSON structure
- Required "type" field
- For record types: "name" and "fields" required
- Fields must be an array

## Available Commands

### Test Environment

```bash
just test-schema-registry-up              # Start Kafka + Schema Registry
just test-schema-registry-down            # Stop and cleanup
just test-schema-registry-status          # Check service health
just test-schema-registry-logs            # View logs
just test-schema-registry-create-sample   # Create sample schema
just test-schema-registry-list            # List all schemas
just test-schema-registry-get SUBJECT     # Get schema details
```

### Application

```bash
just test-backend      # Start backend with test cluster
just frontend          # Start frontend dev server
just test-full-setup   # Show complete setup instructions
```

## Configuration

### Environment Variables (Optional)

The API key is stored in localStorage, but you could extend this to support:
- `OPENROUTER_API_KEY`: Pre-configured API key
- `OPENROUTER_DEFAULT_MODEL`: Default model selection

### OpenRouter API Key

Get your API key from: https://openrouter.ai/keys

The service supports any model available in OpenRouter's catalog, including:
- OpenAI GPT models
- Anthropic Claude models
- Google Gemini models
- Meta Llama models
- And many more

## Security Considerations

- **API Key Storage**: Keys stored in browser localStorage (client-side)
- **Validation Required**: All LLM-generated schemas should be validated before submission
- **Production Recommendation**: Consider proxying OpenRouter requests through backend
- **No New Dependencies**: Uses existing libraries only

### Security Best Practices

For production deployments:
1. Store API keys securely on the backend
2. Proxy OpenRouter requests through your backend
3. Implement rate limiting
4. Validate all LLM-generated content
5. Sanitize schema content to prevent injection attacks
6. Monitor API usage and costs

## Development

### TypeScript & Linting

```bash
# Check TypeScript types
pnpm tsc --noEmit

# Lint code
pnpm lint

# Format code
pnpm format
```

### Files Created

1. `frontend/src/lib/interfaces/openrouter.ts` - Type definitions
2. `frontend/src/lib/services/openrouter.ts` - API service
3. `frontend/src/components/Schemas/Edit/LLMModelSelector.tsx` - Model selector
4. `frontend/src/components/Schemas/Edit/LLMChatPanel.tsx` - Chat interface
5. `frontend/src/components/Schemas/Edit/LLMSchemaArtifact.tsx` - Schema artifact panel
6. `frontend/src/components/Schemas/Edit/LLMApiKeyConfig.tsx` - API key config

### Files Modified

1. `frontend/src/components/Schemas/Edit/Form.tsx` - Main integration
2. `frontend/src/components/Schemas/Edit/Edit.styled.ts` - Styled components

### Dependencies

No new dependencies were added. The implementation uses:
- Existing FontAwesome icons
- React hooks (useState, useEffect, useRef)
- Existing styled-components setup
- Existing form components (Select, Input, Textarea, Button)
- Existing Editor component

## Testing

For complete testing instructions, see: [doc-002 - LLM Schema Assistant Testing](doc-002%20-%20LLM-Schema-Assistant-Testing.md)

## Troubleshooting

### API Key Issues
- Verify key is valid at https://openrouter.ai/keys
- Check browser console for API errors
- Clear localStorage and re-enter key
- Check OpenRouter account has credit/quota

### Model Loading Issues
- Check network connectivity
- Verify API key has proper permissions
- Check OpenRouter service status
- Review browser network tab for failed requests

### Schema Validation Issues
- Ensure schema is valid JSON
- Check AVRO schema requirements
- Validate against Schema Registry if needed
- Use "Validate AVRO" button before copying

### Chat Not Working
- Ensure model is selected
- Check API key is configured
- Verify schema context is loaded
- Check browser console for errors
- Confirm AVRO schema type is selected

### Schema Not Extracted from Chat
The system looks for JSON code blocks in the LLM response:
- Preferred format: ` ```json\n{...}\n``` `
- Alternative format: ` ```\n{...}\n``` `

If extraction fails, try:
```
Please provide the complete schema in a JSON code block
```

### API Key Lost
API keys are stored in browser localStorage. To clear and re-enter:

```javascript
// Open browser DevTools Console
localStorage.removeItem('openrouter_api_key')
// Then refresh the page
```

## Tips & Best Practices

1. **Use descriptive prompts**: Be specific about what you want
2. **Iterate in chat**: Ask follow-up questions to refine the schema
3. **Validate before copying**: Always validate the proposed schema
4. **Review manually**: Check the schema before submitting
5. **Test different models**: Some models are better at structured output
6. **Include context**: Mention backward compatibility requirements
7. **Ask for explanations**: Request documentation for complex fields

## Current Limitations

- Only AVRO schemas supported (JSON/Protobuf coming later)
- Client-side API key storage (consider backend proxy for production)
- Basic AVRO validation (extend for schema compatibility checks)
- English prompts only (multilingual support possible)
- Single schema conversation (no history across edits)

## Future Enhancements

### Planned Features

1. **Support for Other Schema Types**
   - Enable for JSON schemas
   - Enable for Protobuf schemas

2. **Advanced Validation**
   - Schema compatibility checking
   - Schema evolution validation
   - Integration with Schema Registry validation

3. **Enhanced UX**
   - Diff view between current and proposed schema
   - Schema suggestion preview before applying
   - Multi-schema conversations with history
   - Undo/redo for schema changes

4. **Model Configuration**
   - Temperature and token controls
   - Model-specific settings
   - Cost estimation display
   - Usage tracking

5. **Prompt Templates**
   - Pre-built prompts for common tasks
   - Custom prompt templates
   - Prompt history and favorites

6. **Backend Integration**
   - Store API keys securely on server
   - Proxy OpenRouter requests through backend
   - Rate limiting and usage tracking
   - Team-wide API key management

## Related Documentation

- **[doc-002 - LLM Schema Assistant Testing](doc-002%20-%20LLM-Schema-Assistant-Testing.md)** - Comprehensive testing guide
- **OpenRouter API**: https://openrouter.ai/docs
- **Get API key**: https://openrouter.ai/keys
- **AVRO Specification**: https://avro.apache.org/docs/current/spec.html

## License

Same as Kafka UI project

