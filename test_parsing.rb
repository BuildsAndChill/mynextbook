#!/usr/bin/env ruby

# Test file to debug AI response parsing
# This simulates what happens in the RecommendationsController

puts "=== TESTING AI RESPONSE PARSING ==="
puts

# The exact AI response from the user
ai_response = <<~RESPONSE
BRIEF: What you tend to like: - Engaging narratives with strong character development - Unique world-building and imaginative settings - Themes of friendship and adventure What to explore next: - Fantasy novels that delve into diverse cultures - Science fiction that examines societal issues through a speculative lens - Magical realism that intertwines the ordinary with the extraordinary Pitfalls to avoid: - Overly complex plots that may detract from character engagement - Clichéd tropes that can make stories predictable TOP PICKS: 1. **The Night Circus** by Erin Morgenstern Pitch: A beautifully crafted tale about a mysterious circus that serves as a battleground for two young illusionists. Why: This novel offers rich world-building and a captivating narrative that aligns with your preference for imaginative settings and strong character development. Confidence: High 2. **The Fifth Season** by N.K. Jemisin Pitch: A groundbreaking story set in a world plagued by catastrophic climate events, where certain people possess the power to control geological forces. Why: This book explores complex societal issues and features a unique narrative style, aligning with your interest in engaging characters and diverse world-building. Confidence: High 3. **Life of Pi** by Yann Martel Pitch: A philosophical adventure about a boy stranded on a lifeboat with a Bengal tiger, blending realism and magical elements. Why: This novel offers a profound exploration of survival and spirituality, intertwining the extraordinary with the ordinary, which matches your taste for adventure and deeper themes. Confidence: Medium
RESPONSE

puts "AI Response length: #{ai_response.length}"
puts "AI Response contains 'BRIEF:': #{ai_response.include?('BRIEF:')}"
puts "AI Response contains 'TOP PICKS:': #{ai_response.include?('TOP PICKS:')}"
puts

# Simulate the parse_ai_response method
def parse_ai_response(response)
  puts "=== PARSING AI RESPONSE ==="
  puts "Response length: #{response.length}"
  puts "Response contains 'BRIEF:': #{response.include?('BRIEF:')}"
  puts "Response contains 'TOP PICKS:': #{response.include?('TOP PICKS:')}"
  
  # Try to parse the AI response into structured format
  return { brief: {}, picks: [] } unless response
  
  parsed = {
    brief: {},
    picks: []
  }
  
  # Split into sections
  if response.include?("BRIEF:")
    puts "Found 'BRIEF:' section"
    
    # Try different split approaches
    puts "Trying split('TOP PICKS:')..."
    parts = response.split("TOP PICKS:")
    puts "Split result: #{parts.length} parts"
    puts "Part 0 length: #{parts[0].length if parts[0]}"
    puts "Part 1 length: #{parts[1].length if parts[1]}"
    
    if parts.length >= 2
      brief_section = parts[0]
      picks_section = parts[1]
      
      puts "Brief section length: #{brief_section.length}"
      puts "Picks section length: #{picks_section.length}"
      
      # Parse brief sections
      parsed[:brief][:likes] = extract_bullet_points(brief_section, "What you tend to like:")
      parsed[:brief][:explore] = extract_bullet_points(brief_section, "What to explore next:")
      parsed[:brief][:avoid] = extract_bullet_points(brief_section, "Pitfalls to avoid:")
      
      # Parse picks
      parsed[:picks] = extract_book_picks_enhanced(picks_section)
    else
      puts "Split failed - not enough parts"
    end
  else
    puts "No 'BRIEF:' section found"
  end
  
  puts "Final parsed result:"
  puts "Brief keys: #{parsed[:brief].keys}"
  puts "Brief likes count: #{parsed[:brief][:likes]&.length || 0}"
  puts "Brief explore count: #{parsed[:brief][:explore]&.length || 0}"
  puts "Brief avoid count: #{parsed[:brief][:avoid]&.length || 0}"
  puts "Picks count: #{parsed[:picks]&.length || 0}"
  
  parsed
end

def extract_bullet_points(text, section_name)
  puts "Extracting bullet points for: #{section_name}"
  
  # Find the section
  if text.include?(section_name)
    puts "Found section: #{section_name}"
    
    # Extract content after the section name
    start_index = text.index(section_name) + section_name.length
    end_index = text.index("What to explore next:") || text.index("Pitfalls to avoid:") || text.length
    
    section_text = text[start_index...end_index].strip
    puts "Section text: '#{section_text}'"
    
    # Extract bullet points
    points = section_text.scan(/- (.+?)(?=\n-|\n\n|$)/).flatten.map(&:strip)
    puts "Extracted points: #{points.inspect}"
    
    points
  else
    puts "Section not found: #{section_name}"
    []
  end
end

def extract_book_picks_enhanced(text)
  puts "Extracting book picks from text: #{text.length} characters"
  puts "Text preview: '#{text[0..100]}...'"
  
  picks = []
  
  return picks unless text
  
  # Find numbered book entries with better pattern matching
  # Handle both formats: "1. **Title** by Author" and "1. Title by Author"
  book_entries = text.scan(/(\d+)\.\s*\*\*(.+?)\*\*\s*by\s*(.+?)(?=\n\d+\.|$)/m)
  
  if book_entries.empty?
    puts "No matches with markdown format, trying without markdown..."
    book_entries = text.scan(/(\d+)\.\s*(.+?)\s*by\s*(.+?)(?=\n\d+\.|$)/m)
  end
  
  puts "Found #{book_entries.length} book entries: #{book_entries.inspect}"
  
  book_entries.each do |match|
    number, title, author = match
    
    puts "Processing book #{number}: '#{title}' by '#{author}'"
    
    # Extract additional information if available
    pitch = extract_field(text, number, "Pitch:")
    why = extract_field(text, number, "Why:")
    confidence = extract_field(text, number, "Confidence:")
    
    pick = {
      title: title.strip,
      author: author.strip,
      pitch: pitch,
      why: why,
      confidence: confidence
    }
    
    puts "Created pick: #{pick.inspect}"
    picks << pick
  end
  
  puts "Final picks: #{picks.inspect}"
  picks
end

def extract_field(text, book_number, field_name)
  puts "Extracting #{field_name} for book #{book_number}"
  
  # Look for the field after the book entry
  pattern = /#{book_number}\.\s*\*\*(.+?)\*\*\s*by\s*(.+?)(?=\n\d+\.|$)/m
  match = text.match(pattern)
  
  if match
    book_section = match[0]
    puts "Book section: '#{book_section}'"
    
    # Find the field in this section
    field_pattern = /#{Regexp.escape(field_name)}\s*(.+?)(?=\n(?:Why:|Confidence:|$))/m
    field_match = book_section.match(field_pattern)
    
    if field_match
      value = field_match[1].strip
      puts "Found #{field_name}: '#{value}'"
      return value
    else
      puts "#{field_name} not found in book section"
    end
  else
    puts "Book #{book_number} not found"
  end
  
  nil
end

# Test the parsing
puts "Testing with AI response..."
result = parse_ai_response(ai_response)

puts
puts "=== FINAL RESULT ==="
puts "Result class: #{result.class}"
puts "Result keys: #{result.keys}"
puts "Brief: #{result[:brief].inspect}"
puts "Picks: #{result[:picks].inspect}"
puts "Picks count: #{result[:picks]&.length || 0}"

if result[:picks]&.any?
  puts
  puts "=== BOOK DETAILS ==="
  result[:picks].each_with_index do |pick, index|
    puts "Book #{index + 1}:"
    puts "  Title: #{pick[:title]}"
    puts "  Author: #{pick[:author]}"
    puts "  Pitch: #{pick[:pitch]}"
    puts "  Why: #{pick[:why]}"
    puts "  Confidence: #{pick[:confidence]}"
    puts
  end
end
