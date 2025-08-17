#!/usr/bin/env bash
# exit on error
set -o errexit

bundle install

# Force Tailwind CSS build first and wait for completion
echo "🔨 Building Tailwind CSS..."
bundle exec rails tailwindcss:build

# Wait a moment to ensure file is written
sleep 2

# Verify Tailwind CSS was created
if [ -f "app/assets/builds/tailwind.css" ]; then
    echo "✅ Tailwind CSS built successfully"
    ls -la app/assets/builds/
    echo "📄 Tailwind CSS content preview:"
    head -5 app/assets/builds/tailwind.css
else
    echo "❌ Tailwind CSS not found, trying alternative build method"
    bundle exec rails tailwindcss:install
    bundle exec rails tailwindcss:build
    sleep 2
fi

# Ensure the builds directory exists and has content
echo "📁 Ensuring builds directory structure:"
mkdir -p app/assets/builds
ls -la app/assets/builds/

# Now precompile assets (this will also build Tailwind if needed)
echo "🔨 Precompiling assets..."
bundle exec rails assets:precompile

# Clean up
bundle exec rails assets:clean

# Final verification
echo "📁 Final assets structure:"
ls -la app/assets/builds/
ls -la public/assets/ 2>/dev/null || echo "No public/assets directory"

# Verify Tailwind is accessible
echo "🔍 Verifying Tailwind CSS accessibility:"
if [ -f "app/assets/builds/tailwind.css" ]; then
    echo "✅ Tailwind CSS exists and is accessible"
    wc -l app/assets/builds/tailwind.css
else
    echo "❌ Tailwind CSS still not accessible after all steps"
    exit 1
fi
