// ChatUI imports removed - using native implementation instead

class ChatInterface {
  constructor(containerId) {
    this.container = document.getElementById(containerId);
    this.messages = [];
    this.currentContext = null;
    this.selectedTones = [];
    this.userFeedback = {};
    this.includeHistory = false;
    
    this.init();
  }
  
  init() {
    this.render();
    this.bindEvents();
    this.addWelcomeMessage();
  }
  
  render() {
    this.container.innerHTML = `
      <div class="chat-container">
        <!-- Header -->
        <div class="chat-header">
          <div class="header-content">
            <div class="header-left">
              <div class="ai-avatar">
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
                  <path d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.246 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                </svg>
              </div>
              <div class="header-info">
                <h2>Mon Libraire IA</h2>
                <div class="status">
                  <span class="status-dot"></span>
                  En conversation...
                </div>
              </div>
            </div>
                         <div class="header-right">
               <button class="new-chat-btn" onclick="window.location.reload()">
                 <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor">
                   <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4v16m8-8H4"/>
                 </svg>
                 Nouveau Chat
               </button>
             </div>
          </div>
        </div>
        
        <!-- Messages -->
        <div class="chat-messages" id="chat-messages">
          <!-- Messages will be added here -->
        </div>
        
        <!-- Input -->
        <div class="chat-input">
          <div class="input-container">
            <textarea 
              id="chat-input" 
              placeholder="Dis-moi ce que tu veux lire..."
              rows="1"
            ></textarea>
            <button id="send-btn" class="send-btn">
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
                <path d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
              </svg>
            </button>
          </div>
          
          <!-- Quick Suggestions -->
          <div class="quick-suggestions">
            <button class="suggestion-btn">Romans français contemporains</button>
            <button class="suggestion-btn">Science-fiction optimiste</button>
            <button class="suggestion-btn">Thrillers psychologiques</button>
          </div>
          
          <!-- Tone & Mood Chips -->
          <div class="tone-chips-section">
            <p class="text-xs text-gray-500 mb-2">Ton & Style :</p>
            <div class="flex flex-wrap gap-2">
              <button class="tone-chip" data-tone="Deep dive">Deep dive</button>
              <button class="tone-chip" data-tone="Fast-paced">Fast-paced</button>
              <button class="tone-chip" data-tone="Optimistic">Optimistic</button>
              <button class="tone-chip" data-tone="Thoughtful">Thoughtful</button>
              <button class="tone-chip" data-tone="Adventure">Adventure</button>
              <button class="tone-chip" data-tone="Cozy">Cozy</button>
              <button class="tone-chip" data-tone="Challenging">Challenging</button>
              <button class="tone-chip" data-tone="Light">Light</button>
            </div>
          </div>
          
          <!-- Reading History Toggle -->
          <div class="history-toggle-section">
            <div class="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
              <div>
                <label class="text-sm font-medium text-gray-700">Utiliser mon historique de lecture</label>
                <p class="text-xs text-gray-500">Pour des recommandations personnalisées</p>
              </div>
              <label class="relative inline-flex items-center cursor-pointer">
                <input type="checkbox" id="include-history" class="sr-only" />
                <div class="w-11 h-6 bg-gray-200 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-0.5 after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-indigo-600"></div>
              </label>
            </div>
          </div>
        </div>
      </div>
    `;
  }
  
  bindEvents() {
    // Send message
    const sendBtn = document.getElementById('send-btn');
    const input = document.getElementById('chat-input');
    
    sendBtn.addEventListener('click', () => this.sendMessage());
    
    input.addEventListener('keypress', (e) => {
      if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        this.sendMessage();
      }
    });
    
    // Auto-resize textarea
    input.addEventListener('input', () => {
      input.style.height = 'auto';
      input.style.height = Math.min(input.scrollHeight, 120) + 'px';
    });
    
    // Quick suggestions
    document.querySelectorAll('.suggestion-btn').forEach(btn => {
      btn.addEventListener('click', (e) => {
        input.value = e.target.textContent;
        input.focus();
      });
    });
    
    // Tone chips
    document.querySelectorAll('.tone-chip').forEach(chip => {
      chip.addEventListener('click', (e) => {
        this.toggleToneChip(e.target);
      });
    });
    
    // Delegate book actions (for dynamically added content)
    document.addEventListener('click', (e) => {
      if (e.target.closest('.action-btn')) {
        const btn = e.target.closest('.action-btn');
        const action = btn.dataset.action;
        const bookTitle = btn.dataset.book;
        this.handleBookAction(action, bookTitle);
      }
    });
  }
  

  
  toggleToneChip(chip) {
    const isActive = chip.classList.contains('active');
    
    if (isActive) {
      chip.classList.remove('active', 'bg-indigo-100', 'border-indigo-300', 'text-indigo-700');
      chip.classList.add('bg-gray-50', 'border-gray-200', 'text-gray-600');
    } else {
      chip.classList.remove('bg-gray-50', 'border-gray-200', 'text-gray-600');
      chip.classList.add('active', 'bg-indigo-100', 'border-indigo-300', 'text-indigo-700');
    }
    
    // Update selected tones
    this.updateSelectedTones();
  }
  
  updateSelectedTones() {
    const activeChips = document.querySelectorAll('.tone-chip.active');
    this.selectedTones = Array.from(activeChips).map(chip => chip.dataset.tone);
    console.log('Selected tones:', this.selectedTones);
  }
  
  getSelectedTones() {
    return this.selectedTones || [];
  }
  
  addWelcomeMessage() {
    this.addMessage({
      type: 'ai',
      content: "Salut ! 👋 Dis-moi ce que tu veux lire aujourd'hui. Tu peux être aussi spécifique que tu veux : genre, ton, longueur, ou juste ton humeur du moment !",
      timestamp: new Date()
    });
  }
  
  addMessage(message) {
    this.messages.push(message);
    this.renderMessages();
    this.scrollToBottom();
  }
  
  renderMessages() {
    const container = document.getElementById('chat-messages');
    container.innerHTML = this.messages.map(msg => this.renderMessage(msg)).join('');
  }
  
  renderMessage(message) {
    if (message.type === 'user') {
      return `
        <div class="message user-message">
          <div class="message-content">
            <p>${message.content}</p>
            <span class="timestamp">${this.formatTime(message.timestamp)}</span>
          </div>
          <div class="message-avatar">
            <div class="user-avatar">Vous</div>
          </div>
        </div>
      `;
    } else {
      let content = `<p>${message.content}</p>`;
      
      // Add book suggestions if available
      if (message.suggestions && message.suggestions.length > 0) {
        content += this.renderBookSuggestions(message.suggestions);
      }
      
      return `
        <div class="message ai-message">
          <div class="message-avatar">
            <div class="ai-avatar">
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
                <path d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
              </svg>
            </div>
          </div>
          <div class="message-content">
            ${content}
            <span class="timestamp">IA • ${this.formatTime(message.timestamp)}</span>
          </div>
        </div>
      `;
    }
  }
  
  renderBookSuggestions(books) {
    return `
      <div class="book-suggestions">
        ${books.map(book => `
          <div class="book-card">
            <div class="book-cover">
              <svg width="48" height="64" viewBox="0 0 24 24" fill="none">
                <path d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.246 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
              </svg>
            </div>
            <div class="book-info">
              <h4 class="book-title">${book.title}</h4>
              <p class="book-author">par ${book.author}</p>
              <p class="book-pitch">${book.pitch}</p>
              <div class="book-actions">
                <button class="action-btn like-btn" data-action="like" data-book="${book.title}">
                  <svg width="16" height="16" viewBox="0 0 20 20" fill="currentColor">
                    <path fill-rule="evenodd" d="M3.172 5.172a4 4 0 015.656 0L10 6.343l1.172-1.171a4 4 0 115.656 5.656L10 17.657l-6.828-6.829a4 4 0 010-5.656z" clip-rule="evenodd"/>
                  </svg>
                </button>
                <button class="action-btn dislike-btn" data-action="dislike" data-book="${book.title}">
                  <svg width="16" height="16" viewBox="0 0 20 20" fill="currentColor">
                    <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"/>
                  </svg>
                </button>
                <button class="action-btn save-btn" data-action="save" data-book="${book.title}">
                  <svg width="16" height="16" viewBox="0 0 20 20" fill="currentColor">
                    <path d="M5 4a2 2 0 012-2h6a2 2 0 012 2v14l-5-2.5L5 18V4z"/>
                  </svg>
                </button>
              </div>
            </div>
          </div>
        `).join('')}
      </div>
    `;
  }
  
  async sendMessage() {
    const input = document.getElementById('chat-input');
    const message = input.value.trim();
    
    if (!message) return;
    
    // Add user message
    this.addMessage({
      type: 'user',
      content: message,
      timestamp: new Date()
    });
    
    // Clear input
    input.value = '';
    input.style.height = 'auto';
    
    // Show typing indicator
    this.showTypingIndicator();
    
    // Simulate AI thinking time
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    // Generate mock response based on message content
    const mockResponse = this.generateMockResponse(message);
    
    // Add AI response
    this.addMessage({
      type: 'ai',
      content: mockResponse.message,
      suggestions: mockResponse.suggestions,
      timestamp: new Date()
    });
    
    // Update context
    this.currentContext = message;
    
    this.hideTypingIndicator();
  }
  
  generateMockResponse(userMessage) {
    const lowerMessage = userMessage.toLowerCase();
    const selectedTones = this.getSelectedTones();
    
    // Check if this is a refinement request (based on user feedback)
    if (this.userFeedback && Object.keys(this.userFeedback).length > 0) {
      return this.generateRefinedResponse();
    }
    
    // Include selected tones in the response
    let toneContext = '';
    if (selectedTones.length > 0) {
      toneContext = ` (avec un ton ${selectedTones.join(', ')})`;
    }
    
    // Generate different responses based on keywords
    if (lowerMessage.includes('roman') || lowerMessage.includes('fiction')) {
      return {
        message: `Parfait ! Voici mes suggestions de romans basées sur ta demande${toneContext} :`,
        suggestions: [
          {
            title: "Le Petit Prince",
            author: "Antoine de Saint-Exupéry",
            pitch: "Un conte poétique et philosophique sur l'amitié et l'amour, parfait pour tous les âges."
          },
          {
            title: "L'Étranger",
            author: "Albert Camus",
            pitch: "Une réflexion profonde sur l'absurdité de l'existence et la condition humaine."
          },
          {
            title: "Madame Bovary",
            author: "Gustave Flaubert",
            pitch: "Un chef-d'œuvre du réalisme français, l'histoire d'Emma Bovary et ses rêves romantiques."
          }
        ]
      };
    } else if (lowerMessage.includes('science') || lowerMessage.includes('sf') || lowerMessage.includes('futur')) {
      return {
        message: "Excellent choix ! Voici mes suggestions de science-fiction :",
        suggestions: [
          {
            title: "1984",
            author: "George Orwell",
            pitch: "Une dystopie visionnaire sur la surveillance et le contrôle totalitaire."
          },
          {
            title: "Le Meilleur des mondes",
            author: "Aldous Huxley",
            pitch: "Une société futuriste où le bonheur est contrôlé par la technologie."
          },
          {
            title: "Fondation",
            author: "Isaac Asimov",
            pitch: "Une saga épique sur la chute et la reconstruction d'un empire galactique."
          }
        ]
      };
    } else if (lowerMessage.includes('thriller') || lowerMessage.includes('policier') || lowerMessage.includes('suspense')) {
      return {
        message: "Parfait pour un bon moment de tension ! Voici mes suggestions :",
        suggestions: [
          {
            title: "Le Parrain",
            author: "Mario Puzo",
            pitch: "L'histoire de la famille Corleone, un chef-d'œuvre du roman noir."
          },
          {
            title: "Gone Girl",
            author: "Gillian Flynn",
            pitch: "Un thriller psychologique haletant sur la disparition d'une femme."
          },
          {
            title: "Le Silence des agneaux",
            author: "Thomas Harris",
            pitch: "Un thriller horrifique avec le célèbre Dr. Hannibal Lecter."
          }
        ]
      };
    } else if (lowerMessage.includes('philosophie') || lowerMessage.includes('réflexion') || lowerMessage.includes('pensée')) {
      return {
        message: "Des lectures qui font réfléchir ! Voici mes suggestions :",
        suggestions: [
          {
            title: "Ainsi parlait Zarathoustra",
            author: "Friedrich Nietzsche",
            pitch: "Une œuvre philosophique majeure sur la volonté de puissance et l'éternel retour."
          },
          {
            title: "L'Existentialisme est un humanisme",
            author: "Jean-Paul Sartre",
            pitch: "Une introduction accessible à la philosophie existentialiste."
          },
          {
            title: "Le Mythe de Sisyphe",
            author: "Albert Camus",
            pitch: "Une réflexion sur l'absurdité de la vie et la révolte."
          }
        ]
      };
    } else if (lowerMessage.includes('mood') || lowerMessage.includes('humeur') || lowerMessage.includes('sentiment')) {
      return {
        message: "Je vois que tu veux partager ton humeur ! Voici des suggestions qui pourraient correspondre :",
        suggestions: [
          {
            title: "Le Petit Prince",
            author: "Antoine de Saint-Exupéry",
            pitch: "Un livre réconfortant qui réchauffe le cœur et l'âme."
          },
          {
            title: "L'Alchimiste",
            author: "Paulo Coelho",
            pitch: "Une histoire inspirante qui donne de l'espoir et de la motivation."
          },
          {
            title: "Le Seigneur des Anneaux",
            author: "J.R.R. Tolkien",
            pitch: "Une épopée qui transporte dans un monde merveilleux et échappe au quotidien."
          }
        ]
      };
    } else {
      // Default response for any other message
      return {
        message: "Merci pour ta demande ! Voici quelques suggestions variées qui pourraient t'intéresser :",
        suggestions: [
          {
            title: "Le Petit Prince",
            author: "Antoine de Saint-Exupéry",
            pitch: "Un conte universel sur l'amour et l'amitié, à lire et relire."
          },
          {
            title: "1984",
            author: "George Orwell",
            pitch: "Une dystopie classique qui reste d'actualité."
          },
          {
            title: "L'Alchimiste",
            author: "Paulo Coelho",
            pitch: "Un roman initiatique sur la quête de soi et la réalisation de ses rêves."
          }
        ]
      };
    }
  }
  
  generateRefinedResponse() {
    const likedBooks = Object.keys(this.userFeedback).filter(book => 
      this.userFeedback[book].like
    );
    const dislikedBooks = Object.keys(this.userFeedback).filter(book => 
      this.userFeedback[book].dislike
    );
    
    let message = "Parfait ! En me basant sur tes préférences, voici des suggestions raffinées :";
    
    if (likedBooks.length > 0) {
      message += ` J'ai noté que tu aimes ${likedBooks.join(', ')}. `;
    }
    if (dislikedBooks.length > 0) {
      message += `Je vais éviter les styles similaires à ${dislikedBooks.join(', ')}. `;
    }
    
    // Suggestions basées sur les préférences
    const refinedSuggestions = [
      {
        title: "Le Château",
        author: "Franz Kafka",
        pitch: "Un roman métaphorique sur la bureaucratie et la quête de sens, dans la lignée de tes lectures philosophiques."
      },
      {
        title: "Les Fleurs du Mal",
        author: "Charles Baudelaire",
        pitch: "Une œuvre poétique majeure qui explore les thèmes de la beauté et de la mélancolie."
      },
      {
        title: "Le Procès",
        author: "Franz Kafka",
        pitch: "Une réflexion sur la justice et l'absurdité de la vie, dans la tradition existentialiste."
      }
    ];
    
    return {
      message: message,
      suggestions: refinedSuggestions
    };
  }
  
  showTypingIndicator() {
    const container = document.getElementById('chat-messages');
    const typing = document.createElement('div');
    typing.id = 'typing-indicator';
    typing.className = 'message ai-message typing';
    typing.innerHTML = `
      <div class="message-avatar">
        <div class="ai-avatar">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none">
            <path d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
          </svg>
        </div>
      </div>
      <div class="message-content">
        <div class="typing-dots">
          <span></span>
          <span></span>
          <span></span>
        </div>
      </div>
    `;
    container.appendChild(typing);
    this.scrollToBottom();
  }
  
  hideTypingIndicator() {
    const typing = document.getElementById('typing-indicator');
    if (typing) {
      typing.remove();
    }
  }
  
  scrollToBottom() {
    const container = document.getElementById('chat-messages');
    container.scrollTop = container.scrollHeight;
  }
  
  formatTime(date) {
    return date.toLocaleTimeString('fr-FR', { 
      hour: '2-digit', 
      minute: '2-digit' 
    });
  }
  
  handleBookAction(action, bookTitle) {
    console.log(`Action ${action} sur le livre: ${bookTitle}`);
    
    // Feedback visuel immédiat
    const btn = document.querySelector(`[data-action="${action}"][data-book="${bookTitle}"]`);
    if (btn) {
      const originalHTML = btn.innerHTML;
      
      // Animation de feedback
      if (action === 'like') {
        btn.style.background = '#dcfce7';
        btn.style.color = '#16a34a';
        btn.innerHTML = '<svg width="16" height="16" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M3.172 5.172a4 4 0 015.656 0L10 6.343l1.172-1.171a4 4 0 115.656 5.656L10 17.657l-6.828-6.829a4 4 0 010-5.656z" clip-rule="evenodd"/></svg>';
      } else if (action === 'dislike') {
        btn.style.background = '#fee2e2';
        btn.style.color = '#dc2626';
        btn.innerHTML = '<svg width="16" height="16" viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"/></svg>';
      } else if (action === 'save') {
        btn.style.background = '#dbeafe';
        btn.style.color = '#2563eb';
        btn.innerHTML = '<svg width="16" height="16" viewBox="0 0 20 20" fill="currentColor"><path d="M5 4a2 2 0 012-2h6a2 2 0 012 2v14l-5-2.5L5 18V4z"/></svg>';
      }
      
      // Reset après 2 secondes
      setTimeout(() => {
        btn.style.background = '';
        btn.style.color = '';
        btn.innerHTML = originalHTML;
      }, 2000);
    }
    
    // Stocker l'action en session pour les futures recommandations
    if (!this.userFeedback) this.userFeedback = {};
    if (!this.userFeedback[bookTitle]) this.userFeedback[bookTitle] = {};
    this.userFeedback[bookTitle][action] = true;
    
    // Message de confirmation
    const messages = {
      like: `J'ai noté que tu aimes "${bookTitle}" !`,
      dislike: `J'ai noté que "${bookTitle}" ne t'intéresse pas.`,
      save: `"${bookTitle}" a été ajouté à ta liste de lecture !`
    };
    
    this.addMessage({
      type: 'ai',
      content: messages[action],
      timestamp: new Date()
    });
  }
}

// Export for use in other files
window.ChatInterface = ChatInterface;
