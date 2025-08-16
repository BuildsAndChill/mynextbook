module ApplicationHelper
  def debug_mode?
    ENV['debug_mode'] == 'true'
  end
end
