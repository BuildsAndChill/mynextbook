# Migration Guide: Render to Fly.io

This guide will help you migrate your Rails application from Render to Fly.io. Fly.io offers pay-per-use pricing which is ideal for prototypes with limited usage.

## Why Fly.io?

- **Pay-per-use pricing**: Only pay for what you use
- **Global edge deployment**: Deploy closer to your users
- **Auto-scaling**: Automatically scale to zero when not in use
- **PostgreSQL included**: Managed database service
- **Volume storage**: Persistent file storage
- **Custom domains**: Easy SSL certificate management

## Prerequisites

1. **Install Fly CLI**:
   ```bash
   curl -L https://fly.io/install.sh | sh
   ```

2. **Login to Fly.io**:
   ```bash
   fly auth login
   ```

3. **Verify installation**:
   ```bash
   fly version
   ```

## Migration Steps

### Step 1: Initial Setup

Run the setup script to create your Fly.io app and database:

```bash
chmod +x bin/fly-setup.sh
./bin/fly-setup.sh
```

This script will:
- Create your Fly.io app
- Set up a PostgreSQL database
- Create storage volumes
- Configure environment variables
- Set up secrets

### Step 2: Update Environment Variables

Copy your existing environment variables from Render to Fly.io:

```bash
# Set your Rails master key
fly secrets set RAILS_MASTER_KEY="your_rails_master_key"

# Set your database URL (Fly.io will provide this)
fly secrets set DATABASE_URL_PROD="postgresql://..."

# Set other environment variables
fly secrets set MAILGUN_API_KEY="your_mailgun_api_key"
fly secrets set MAILGUN_DOMAIN="your_mailgun_domain"
fly secrets set MAILGUN_REGION="eu"
```

### Step 3: Deploy Your Application

Deploy your application to Fly.io:

```bash
chmod +x bin/fly-deploy.sh
./bin/fly-deploy.sh
```

### Step 4: Verify Deployment

Check your application status:

```bash
fly status
fly logs
```

Your app should be available at: `https://mynextbook.fly.dev`

## Configuration Files

### fly.toml
The main configuration file for your Fly.io app. Key features:
- **Auto-scaling**: `min_machines_running = 0` (scales to zero when not in use)
- **Health checks**: Automatic health monitoring
- **Volume mounts**: Persistent storage for uploaded files
- **Database migrations**: Automatic migration on deployment

### .dockerignore
Optimizes your Docker build by excluding unnecessary files.

## Cost Optimization

### Auto-scaling
- **Scale to zero**: Set `min_machines_running = 0` in `fly.toml`
- **Auto-start**: Machines start automatically when traffic arrives
- **Auto-stop**: Machines stop when no traffic for 15 minutes

### Resource Limits
- **Shared CPU**: Use `shared-cpu-1x` for development/prototypes
- **Minimal memory**: Start with 512MB RAM
- **Small volumes**: Start with 1GB storage

### Database
- **Shared CPU**: Use `shared-cpu-1x` for PostgreSQL
- **Minimal cluster**: Start with 1 node
- **Auto-scaling**: Database scales based on usage

## Monitoring and Management

### View Logs
```bash
fly logs
fly logs -f  # Follow logs in real-time
```

### Scale Resources
```bash
fly scale count 1    # Start 1 machine
fly scale count 0    # Stop all machines (scale to zero)
fly scale memory 1024 # Increase memory to 1GB
```

### Database Management
```bash
fly postgres connect -a mynextbook-db  # Connect to database
fly postgres list                       # List databases
```

### Volume Management
```bash
fly volumes list                        # List volumes
fly volumes destroy mynextbook_data     # Destroy volume (⚠️ data loss)
```

## Custom Domain Setup

1. **Add your domain**:
   ```bash
   fly certs add yourdomain.com
   ```

2. **Update DNS**: Point your domain to Fly.io nameservers

3. **Update environment**:
   ```bash
   fly secrets set CUSTOM_DOMAIN=yourdomain.com
   fly secrets set APP_HOST=https://yourdomain.com
   ```

## Troubleshooting

### Common Issues

1. **Build failures**: Check Dockerfile and .dockerignore
2. **Database connection**: Verify DATABASE_URL_PROD secret
3. **Asset compilation**: Ensure Tailwind CSS builds correctly
4. **Memory issues**: Increase memory allocation if needed

### Debug Commands

```bash
fly ssh console -C "/bin/bash"  # SSH into running machine
fly status                       # Check app status
fly logs                        # View application logs
fly postgres status             # Check database status
```

### Performance Monitoring

```bash
fly dashboard                   # Open web dashboard
fly metrics                     # View performance metrics
```

## Rollback Plan

If you need to rollback to Render:

1. **Keep your Render app running** during migration
2. **Test thoroughly** on Fly.io before switching DNS
3. **Maintain database backups** on both platforms
4. **Use feature flags** for gradual rollout

## Cost Comparison

### Render (Fixed Pricing)
- **Free tier**: $0/month (limited resources)
- **Starter**: $7/month (fixed cost)
- **Standard**: $25/month (fixed cost)

### Fly.io (Pay-per-use)
- **Shared CPU**: ~$1.94/month for 1 machine running 24/7
- **Database**: ~$7/month for shared PostgreSQL
- **Storage**: ~$0.15/month per GB
- **Bandwidth**: ~$0.15/GB

**For prototypes with limited usage**: Fly.io can be significantly cheaper as you only pay when your app is actually used.

## Next Steps

1. **Test thoroughly** on Fly.io
2. **Update DNS** when ready to switch
3. **Monitor costs** and adjust resources as needed
4. **Set up alerts** for cost thresholds
5. **Document** your deployment process

## Support

- **Fly.io Docs**: https://fly.io/docs/
- **Community**: https://community.fly.io/
- **Discord**: https://fly.io/discord/

---

**Note**: This migration maintains your existing Rails application structure and only changes the deployment platform. All your models, controllers, and views remain unchanged.
