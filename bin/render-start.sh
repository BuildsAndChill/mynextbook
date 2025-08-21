#!/usr/bin/env bash
# exit on error
set -o errexit

bundle install
bundle exec rails assets:precompile
bundle exec rails assets:clean
bundle exec rails db:migrate

# Ensure the server binds to the PORT environment variable
echo "Starting Rails server on port $PORT with environment: ${RAILS_ENV:-production}"
bundle exec rails server -p $PORT -e ${RAILS_ENV:-production}
