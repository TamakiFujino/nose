# iOS CI/CD Pipeline

This repository uses GitHub Actions to automatically build and upload iOS apps to TestFlight.

## Workflow Triggers

The CI/CD pipeline is triggered in the following scenarios:

### 1. Direct Push to Staging Branch
- **Trigger**: Any push to the `staging` branch
- **Action**: Builds and uploads to TestFlight using the staging scheme
- **Use Case**: Quick testing of features in development

### 2. Pull Request Merge to Main/Production
- **Trigger**: When a pull request is merged to `main` or `production` branches
- **Action**: Builds and uploads to TestFlight using the production scheme
- **Use Case**: Production releases after code review

### 3. Manual Trigger
- **Trigger**: Manual workflow dispatch from GitHub Actions tab
- **Action**: Allows you to choose between staging or production deployment
- **Use Case**: Emergency deployments or testing

## Environment Configuration

### Staging Environment
- **Scheme**: `nose-staging`
- **Configuration**: Staging
- **Purpose**: Development and testing

### Production Environment
- **Scheme**: `nose-production`
- **Configuration**: Production
- **Purpose**: Production releases

## Required Secrets

Make sure the following secrets are configured in your GitHub repository settings:

- `APP_STORE_CONNECT_API_KEY`: App Store Connect API Key (JSON content)
- `FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD`: App-specific password for Apple ID
- `FASTLANE_PASSWORD`: Apple ID password
- `FASTLANE_USER`: Apple ID email

## Branch Strategy

### Recommended Workflow

1. **Development**: Work on feature branches
2. **Staging**: Merge feature branches to `staging` for testing
3. **Production**: Create pull requests from `staging` to `main` or `production`

### Branch Protection Rules

Consider setting up branch protection rules for:
- `main` and `production` branches
- Require pull request reviews
- Require status checks to pass

## Fastlane Lanes

### `beta` Lane
- Builds using `nose-staging` scheme
- Uploads to TestFlight
- Used for staging deployments

### `production` Lane
- Builds using `nose-production` scheme
- Uploads to TestFlight
- Used for production deployments

### `build` Lane
- Builds the app only (no upload)
- Useful for local testing

## Troubleshooting

### Common Issues

1. **Build Failures**
   - Check Xcode scheme configuration
   - Verify signing certificates
   - Ensure all dependencies are properly installed

2. **Upload Failures**
   - Verify App Store Connect API key
   - Check Apple ID credentials
   - Ensure app is properly configured in App Store Connect

3. **Version Conflicts**
   - Fastlane automatically increments build numbers
   - Check for duplicate build numbers in App Store Connect

### Debugging

- Check GitHub Actions logs for detailed error messages
- Use the manual trigger to test specific environments
- Verify secrets are properly configured

## Local Development

To test the build process locally:

```bash
# Install dependencies
bundle install

# Run staging build
bundle exec fastlane beta

# Run production build
bundle exec fastlane production

# Build only (no upload)
bundle exec fastlane build
```

## Security Notes

- Never commit API keys or passwords to the repository
- Use GitHub Secrets for all sensitive information
- Regularly rotate App Store Connect API keys
- Use app-specific passwords for Apple ID authentication 