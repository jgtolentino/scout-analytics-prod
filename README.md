# Scout Analytics Production Repository

## Project Structure
```mermaid
graph TD
    A[scout-analytics-prod] --> B[apps/]
    A --> C[packages/]
    A --> D[infrastructure/]
    A --> E[specs/]
    
    B --> B1[dashboard]
    B --> B2[retailbot-api]
    B --> B3[data-pipeline]
    
    C --> C1[design-system]
    C --> C2[ai-core]
    C --> C3[data-models]
    
    D --> D1[terraform]
    D --> D2[docker]
    D --> D3[monitoring]
```

## Getting Started
```bash
# Install dependencies
npm install

# Build all packages
npm run build

# Run tests
npm test

# Deploy to production
npm run deploy
```

## Key Configuration Files
- `specs/dashboard_end_state.yaml`: Main dashboard configuration
- `.github/workflows/ci.yml`: CI/CD pipeline
- `infrastructure/monitoring/dashboard.json`: Monitoring config
