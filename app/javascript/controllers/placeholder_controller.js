import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.rotatePlaceholder()
  }
  
  rotatePlaceholder() {
    const placeholders = [
      // English examples only
      "After Sapiens, I want something about technology and society",
      "A contemporary novel that makes me think about modern life",
      "Science fiction that's original and captivating",
      "I'm looking for a book about modern art",
      "A philosophical essay that's accessible yet profound",
      "After Dune, I want something about power dynamics and human nature",
      "A contemporary novel that explores identity and belonging in modern cities",
      "Non-fiction about climate change solutions, optimistic but realistic",
      "A mystery thriller with complex characters and unexpected plot twists",
      "Something that challenges my worldview, maybe about economics or psychology",
      "A book about space exploration or quantum physics, but accessible",
      "Something about ancient civilizations or lost knowledge",
      "A book about nature and ecology, maybe a travel memoir",
      "I want to explore a new genre, something engaging and well-written",
      "A book that combines history with personal storytelling"
    ]
    
    const randomPlaceholder = placeholders[Math.floor(Math.random() * placeholders.length)]
    this.element.placeholder = randomPlaceholder
    
    console.log('🎲 Placeholder rotated to:', randomPlaceholder)
  }
}
