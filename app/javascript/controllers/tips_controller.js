import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.rotateTips()
  }
  
  rotateTips() {
    const examples = [
      // English examples with French equivalents
      "I want a French novel" + " → " + "Je veux un roman français",
      "A book about philosophy in French" + " → " + "Un livre sur la philosophie en français",
      "French science fiction" + " → " + "De la science-fiction française",
      "A contemporary French essay" + " → " + "Un essai français contemporain",
      "French mystery novels" + " → " + "Des romans policiers français",
      "French history books" + " → " + "Des livres d'histoire français",
      "French poetry" + " → " + "De la poésie française",
      "French travel literature" + " → " + "De la littérature de voyage française",
      "French romance novels" + " → " + "Des romans d'amour français",
      "French children's books" + " → " + "Des livres pour enfants en français",
      "French cookbooks" + " → " + "Des livres de cuisine français",
      "French art books" + " → " + "Des livres d'art français"
    ]
    
    const randomExample = examples[Math.floor(Math.random() * examples.length)]
    const exampleElement = document.getElementById('random-example')
    
    if (exampleElement) {
      exampleElement.innerHTML = `• Examples: "${randomExample}"`
    }
    
    console.log('🎲 Tips example rotated to:', randomExample)
  }
}
