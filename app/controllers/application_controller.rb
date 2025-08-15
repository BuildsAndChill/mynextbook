class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  # But be more permissive in development to allow tools like Chrome DevTools
  if Rails.env.development?
    # In development, allow all browsers to avoid issues with DevTools
    # No browser restrictions in development
  else
    # In production, strictly enforce modern browser requirements
    allow_browser versions: :modern
  end
end
