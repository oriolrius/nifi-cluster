---
id: doc-003
title: UI Customization
type: configuration
created_date: '2025-10-23 16:30'
---

# Kafka UI Customization Guide

This document provides comprehensive technical documentation for customizing Kafka UI, including implementation details and configuration options.

## Overview

Kafka UI supports extensive customization through configuration properties that can be set via YAML files or environment variables. The customization system covers:

1. **Application Branding** - Custom titles and logos
2. **User Menu** - Account and logout links in the sidebar
3. **Social Links** - GitHub, Discord, and ProductHunt icons in the navbar
4. **Custom Menu Items** - Add custom links to external tools in the sidebar

## Implementation Architecture

### Backend Components

**Configuration Class**: `io.kafbat.ui.config.UiProperties`

```java
@Configuration
@ConfigurationProperties("ui")
@Data
public class UiProperties {
  private String title = "Kafka Console";
  private UserMenu userMenu = new UserMenu();
  private SocialLinks socialLinks = new SocialLinks();
}
```

**Service Layer**: `io.kafbat.ui.service.ApplicationInfoService`

- Exposes UI settings via `/api/info` endpoint
- Maps configuration properties to API response

**API Contract**: `contract-typespec/api/config.tsp`

- TypeSpec definition for UI configuration model
- Generates TypeScript interfaces for frontend

### Frontend Components

**Navigation Bar**: `frontend/src/components/NavBar/NavBar.tsx`

- Consumes UI settings from API
- Displays configurable title and social links

**Sidebar Navigation**: `frontend/src/components/Nav/Nav.tsx`

- Renders configurable user menu
- Conditionally shows account/logout links
- Displays custom menu items linking to external tools

**Logo Component**: `frontend/src/components/common/Logo/Logo.tsx`

- Logo removed (returns null)
- Original SVG bat logo and custom lightning bolt emoji both removed

## Configuration Reference

### Application Title

| Environment Variable | YAML Path | Default | Description |
|---------------------|-----------|---------|-------------|
| `UI_TITLE` | `ui.title` | `"Kafka Console"` | Application title in navigation bar |

**Example:**

```yaml
ui:
  title: "Production Kafka Console"
```

### User Menu Configuration

| Environment Variable | YAML Path | Default | Description |
|---------------------|-----------|---------|-------------|
| `UI_USERMENU_ENABLED` | `ui.userMenu.enabled` | `false` | Show/hide user menu in sidebar |
| `UI_USERMENU_ACCOUNTURL` | `ui.userMenu.accountUrl` | `null` | URL for account management page |
| `UI_USERMENU_LOGOUTURL` | `ui.userMenu.logoutUrl` | `null` | Custom logout URL |

**Example:**

```yaml
ui:
  userMenu:
    enabled: true
    accountUrl: "https://iam.example.com/account"
    logoutUrl: "https://console.example.com/logout"
```

### Social Links Configuration

| Environment Variable | YAML Path | Default | Description |
|---------------------|-----------|---------|-------------|
| `UI_SOCIALLINKS_ENABLED` | `ui.socialLinks.enabled` | `true` | Show/hide all social links |
| `UI_SOCIALLINKS_GITHUBURL` | `ui.socialLinks.githubUrl` | `"https://github.com/kafbat/kafka-ui"` | GitHub repository link |
| `UI_SOCIALLINKS_DISCORDURL` | `ui.socialLinks.discordUrl` | `"https://discord.com/invite/4DWzD7pGE5"` | Discord server invitation |
| `UI_SOCIALLINKS_PRODUCTHUNTURL` | `ui.socialLinks.productHuntUrl` | `"https://producthunt.com/products/ui-for-apache-kafka"` | Product Hunt page |

**Example:**

```yaml
ui:
  socialLinks:
    enabled: true
    githubUrl: "https://github.com/your-org/kafka-ui"
    discordUrl: "https://discord.gg/your-server"
    # ProductHunt omitted - won't be displayed
```

### Custom Menu Items Configuration

Add custom links to external tools in the left sidebar navigation. Items appear above the user menu.

| Configuration | Type | Description |
|--------------|------|-------------|
| `ui.customMenuItems[].label` | String | Display text for the menu item |
| `ui.customMenuItems[].url` | String | Target URL (opens in new tab) |
| `ui.customMenuItems[].icon` | String (optional) | Emoji or icon to display |

**YAML Example:**

```yaml
ui:
  customMenuItems:
    - label: "Scheduler"
      url: "https://wsl.ymbihq.local:3012"
      icon: "⏰"
    - label: "Monitoring"
      url: "https://grafana.example.com"
      icon: "📊"
    - label: "Documentation"
      url: "https://docs.example.com"
      icon: "📚"
```

**Environment Variables:**

For environment variables, use indexed notation:

```bash
UI_CUSTOMMENU ITEMS_0_LABEL="Scheduler"
UI_CUSTOMMENUITEMS_0_URL="https://wsl.ymbihq.local:3012"
UI_CUSTOMMENUITEMS_0_ICON="⏰"
UI_CUSTOMMENUITEMS_1_LABEL="Monitoring"
UI_CUSTOMMENUITEMS_1_URL="https://grafana.example.com"
UI_CUSTOMMENUITEMS_1_ICON="📊"
```

**Behavior:**

- All links open in a new tab with `target="_blank"`
- Icon is optional - if omitted, only the label is shown
- Items are displayed in the order they are defined
- Menu section only appears if at least one item is configured

## Docker Deployment

### Environment Variables Example

```bash
# Application Branding
UI_TITLE="Corporate Kafka Dashboard"

# User Menu
UI_USERMENU_ENABLED=true
UI_USERMENU_ACCOUNTURL="https://iam.company.com/account"
UI_USERMENU_LOGOUTURL="https://console.company.com/logout"

# Social Links
UI_SOCIALLINKS_ENABLED=true
UI_SOCIALLINKS_GITHUBURL="https://github.com/company/kafka-ui"
UI_SOCIALLINKS_DISCORDURL="https://discord.gg/company"
```

### Docker Compose Example

```yaml
version: '3.8'
services:
  kafka-ui:
    image: kafbat/kafka-ui:latest
    environment:
      UI_TITLE: "Production Kafka Console"
      UI_USERMENU_ENABLED: true
      UI_USERMENU_ACCOUNTURL: "https://iam.example.com/account"
      UI_SOCIALLINKS_GITHUBURL: "https://github.com/company/kafka-ui"
      KAFKA_CLUSTERS_0_NAME: production
      KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS: kafka:9092
    ports:
      - "8080:8080"
```

## API Response Structure

The `/api/info` endpoint returns UI configuration:

```json
{
  "ui": {
    "title": "Custom Title",
    "userMenu": {
      "enabled": true,
      "accountUrl": "https://iam.example.com/account",
      "logoutUrl": "https://console.example.com/logout"
    },
    "socialLinks": {
      "enabled": true,
      "githubUrl": "https://github.com/company/kafka-ui",
      "discordUrl": "https://discord.gg/company",
      "productHuntUrl": "https://producthunt.com/products/kafka-ui"
    }
  }
}
```

## Technical Implementation Details

### Files Modified

#### Backend Changes

1. **`UiProperties.java`** - Configuration properties class
   - Added `title` field with default "Kafka Console"
   - Existing `userMenu` and `socialLinks` nested classes

2. **`ApplicationInfoService.java`** - Service layer
   - Modified `getUiSettings()` to include title in API response
   - Maps configuration to DTOs for API serialization

3. **`config.tsp`** - TypeSpec API contract
   - Added `title?: string` to ApplicationInfo UI model
   - Generates TypeScript interfaces for frontend consumption

#### Frontend Changes

1. **`NavBar.tsx`** - Navigation component
   - Uses `appInfo.data?.response.ui?.title` for dynamic title
   - Conditionally renders social links based on configuration

2. **`Nav.tsx`** - Sidebar navigation
   - Conditionally renders user menu based on `userMenu.enabled`
   - Uses configured URLs for account/logout links

3. **`Logo.tsx` & `Logo.styled.ts`** - Logo component
   - Logo component removed (returns null)
   - Cleaned up unused CSS animations and styled components

4. **`Version.tsx`** - Version display component
   - Changed from warning icon to neutral tag emoji (🏷️) for version indicator
   - Tag emoji is universally recognized for versions/releases without error connotation
   - Updated tooltip text from "outdated" to "New version available"
   - Inline TagIcon component using emoji for simplicity

### Property Mapping

Spring Boot automatically maps environment variables to Java properties:

- `UI_TITLE` → `ui.title`
- `UI_USERMENU_ENABLED` → `ui.userMenu.enabled`
- `UI_SOCIALLINKS_GITHUBURL` → `ui.socialLinks.githubUrl`

### Build Process

Changes require rebuilding both backend and frontend:

1. **Backend**: `./gradlew :api:build`
2. **Contract Generation**: `./gradlew :contract-typespec:build`
3. **Frontend**: `pnpm build` (or `pnpm dev` for development)

## Testing & Verification

### API Testing

```bash
# Check current configuration
curl http://localhost:8080/api/info | jq '.ui'

# Test with custom title
export UI_TITLE="Test Console"
# Restart application
curl http://localhost:8080/api/info | jq '.ui.title'
```

### Frontend Testing

1. Open application in browser
2. Verify custom title appears in top-left navigation
3. Check lightning bolt logo animation
4. Confirm user menu appears/disappears based on configuration
5. Validate social links render correctly

## Configuration Examples

### Minimal Setup

```yaml
ui:
  title: "My Kafka Console"
```

### OAuth Integration

```yaml
ui:
  title: "Corporate Kafka Dashboard"
  userMenu:
    enabled: true
    accountUrl: "https://iam.company.com/account"
    logoutUrl: "https://iam.company.com/logout"
```

### Corporate Branding

```yaml
ui:
  title: "Enterprise Kafka Management"
  userMenu:
    enabled: true
    accountUrl: "https://auth.company.com/profile"
    logoutUrl: "https://auth.company.com/logout"
  socialLinks:
    enabled: true
    githubUrl: "https://github.com/company/kafka-tools"
    # Discord and ProductHunt disabled by omission
```

### Disable All Social Features

```yaml
ui:
  title: "Internal Kafka Console"
  userMenu:
    enabled: false
  socialLinks:
    enabled: false
```

## Migration Notes

- **Default Behavior**: User menu disabled by default, social links enabled with kafbat defaults
- **Backward Compatibility**: No breaking changes, existing installations continue working
- **Environment Variables**: Override YAML configuration values
- **Fallback**: UI remains functional even without custom configuration

## Troubleshooting

### Common Issues

**Title not updating:**

- Verify `UI_TITLE` environment variable or `ui.title` YAML property
- Check `/api/info` endpoint response
- Restart application after configuration changes

**User menu not appearing:**

- Ensure `ui.userMenu.enabled` is `true`
- Provide at least one URL (`accountUrl` or `logoutUrl`)
- Check browser console for API errors

**Social links missing:**

- Verify `ui.socialLinks.enabled` is `true`
- Ensure specific URLs are provided for desired icons
- Check network tab for failed API requests

### Debug Commands

```bash
# Check configuration loading
curl http://localhost:8080/api/info | jq '.ui'

# Verify environment variables
env | grep UI_

# Check application logs
docker logs kafka-ui | grep -i "ui\|config"
```

This customization system provides complete control over Kafka UI branding while maintaining clean separation between configuration, API, and presentation layers.
