# app/services/temporary_recommendation_storage.rb
class TemporaryRecommendationStorage
  STORAGE_DIR = Rails.root.join('tmp', 'recommendations')
  EXPIRY_TIME = 1.hour

  def self.store(ai_response, parsed_response, user_prompt, context, tone_chips)
    # Generate unique session ID
    session_id = SecureRandom.uuid
    
    # Prepare data structure
    ai_data = {
      ai_response: ai_response,
      parsed_response: parsed_response,
      user_prompt: user_prompt,
      context: context,
      tone_chips: tone_chips,
      created_at: Time.current.iso8601
    }
    
    # Ensure storage directory exists
    FileUtils.mkdir_p(STORAGE_DIR)
    
    # Save to JSON file
    file_path = STORAGE_DIR.join("#{session_id}.json")
    File.write(file_path, ai_data.to_json)
    
    # Clean up old files
    cleanup_expired_files
    
    Rails.logger.info "AI recommendation data stored in file: #{file_path}"
    session_id
  end

  def self.retrieve(session_id)
    return nil unless session_id.present?
    
    file_path = STORAGE_DIR.join("#{session_id}.json")
    return nil unless File.exist?(file_path)
    
    # Check if file is expired
    file_data = JSON.parse(File.read(file_path))
    created_at = Time.parse(file_data['created_at'])
    
    if created_at < EXPIRY_TIME.ago
      # File expired, remove it
      File.delete(file_path)
      Rails.logger.info "Expired recommendation file removed: #{file_path}"
      return nil
    end
    
    # Return the data
    file_data.symbolize_keys
  end

  def self.delete(session_id)
    return unless session_id.present?
    
    file_path = STORAGE_DIR.join("#{session_id}.json")
    if File.exist?(file_path)
      File.delete(file_path)
      Rails.logger.info "Recommendation file deleted: #{file_path}"
    end
  end

  private

  def self.cleanup_expired_files
    return unless Dir.exist?(STORAGE_DIR)
    
    Dir.glob(STORAGE_DIR.join('*.json')).each do |file_path|
      begin
        file_data = JSON.parse(File.read(file_path))
        created_at = Time.parse(file_data['created_at'])
        
        if created_at < EXPIRY_TIME.ago
          File.delete(file_path)
          Rails.logger.info "Cleaned up expired file: #{file_path}"
        end
      rescue => e
        Rails.logger.error "Error cleaning up file #{file_path}: #{e.message}"
        # Remove corrupted files
        File.delete(file_path) if File.exist?(file_path)
      end
    end
  end
end
