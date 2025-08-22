import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.rotatePlaceholder()
  }
  
  rotatePlaceholder() {
    const placeholders = [
      // Français - Inspirants et variés
      "Après Sapiens, je veux tech & société, ton optimiste, 250-350 pages",
      "Un roman français contemporain qui me fasse réfléchir sur la vie moderne",
      "De la science-fiction en français, quelque chose d'original et captivant",
      "Un essai philosophique accessible, peut-être sur la conscience ou l'IA",
      "Un livre qui me fasse voyager, peut-être sur l'Asie ou l'Afrique",
      "Un roman historique qui me transporte dans une autre époque",
      
      // English - Diverse and inspiring
      "After reading Dune, I want something about power dynamics and human nature",
      "A contemporary novel that explores identity and belonging in modern cities",
      "Non-fiction about climate change solutions, optimistic but realistic",
      "A mystery thriller with complex characters and unexpected plot twists",
      "Something that challenges my worldview, maybe about economics or psychology",
      "A book about creativity and innovation, maybe biographies or case studies",
      
      // Mixed language examples
      "Un livre sur l'art moderne ou la musique, quelque chose qui m'émeuve",
      "A book about space exploration or quantum physics, but accessible",
      "Un roman policier scandinave, atmosphérique et psychologique",
      "Something about ancient civilizations or lost knowledge",
      "Un livre sur la nature et l'écologie, peut-être un récit de voyage",
      "A book about human psychology and behavior, maybe case studies"
    ]
    
    const randomPlaceholder = placeholders[Math.floor(Math.random() * placeholders.length)]
    this.element.placeholder = randomPlaceholder
    
    console.log('🎲 Placeholder rotated to:', randomPlaceholder)
  }
}
