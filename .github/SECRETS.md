# GitHub Secrets Configuration

Configure these secrets in your GitHub repository settings for CI/CD workflows:

## Required Secrets

### Database Configuration
- **`DATABASE_URL`**: PostgreSQL connection string for production
  ```
  postgresql://admin@scout-prod-postgres:password@scout-prod-postgres.postgres.database.azure.com:5432/scoutdb?sslmode=require
  ```

### API Configuration  
- **`DASHBOARD_API_URL`**: Production dashboard URL
  ```
  https://scout-analytics-prod.vercel.app
  ```

### Optional Secrets (for enhanced features)
- **`SUPABASE_URL`**: Supabase project URL
- **`SUPABASE_ANON_KEY`**: Supabase anonymous key
- **`OPENAI_API_KEY`**: OpenAI API key for AI features
- **`ANTHROPIC_API_KEY`**: Anthropic API key for Claude integration

## How to Add Secrets

1. Go to your GitHub repository
2. Navigate to **Settings** > **Secrets and variables** > **Actions**
3. Click **New repository secret**
4. Add each secret with the exact name listed above

## Usage in Workflows

Secrets are automatically available in GitHub Actions workflows:

```yaml
env:
  DATABASE_URL: ${{ secrets.DATABASE_URL }}
  DASHBOARD_API_URL: ${{ secrets.DASHBOARD_API_URL }}
```

## Security Notes

- Never commit actual secret values to the repository
- Use `.env.production.example` as a template
- Secrets are encrypted and only available during workflow execution
- Only repository collaborators with write access can view/edit secrets