#!/usr/bin/env bash
# exit on error
set -o errexit

bundle install

# Build Tailwind CSS for production
bundle exec rails tailwindcss:build

# Precompile all assets
bundle exec rails assets:precompile
bundle exec rails assets:clean
