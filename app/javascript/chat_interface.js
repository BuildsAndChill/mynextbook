// ChatUI imports removed - using native implementation instead

class ChatInterface {
  constructor(containerId) {
    this.container = document.getElementById(containerId);
    this.messages = [];
    this.currentContext = null;
    this.selectedTones = [];
    this.userFeedback = {};
    this.includeHistory = false;
    this.hasFirstResults = false;
    this.isSettingsOpen = false;
    this.isAdvancedOpen = false;
    
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
        <!-- Ultra-Simple Header -->
        <div class="chat-header">
          <div class="header-content">
            <div class="header-left">
              <div class="ai-avatar">
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
                  <path d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.246 18 16.5 18c-1.746 0-3.332.477-4.5 1.253" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                </svg>
              </div>
              <h2>Mon Libraire IA</h2>
            </div>
            <div class="header-right">
              <button class="settings-btn" id="settings-btn">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor">
                  <path d="M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6Z" stroke-width="2"/>
                  <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1Z" stroke-width="2"/>
                </svg>
              </button>
            </div>
          </div>
        </div>
        
        <!-- Messages - Scrollable Area -->
        <div class="chat-messages" id="chat-messages">
          <!-- Messages will be added here -->
        </div>
        
        <!-- Sticky Input - Ultra Simple -->
        <div class="chat-input">
          <div class="input-container">
            <textarea 
              id="chat-input" 
              placeholder="Dis-moi ce que tu veux lire..."
              rows="1"
            ></textarea>
            <button id="send-btn" class="send-btn primary-btn">
              <span class="btn-text">Get suggestions</span>
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor">
                <path d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
              </svg>
            </button>
            <button class="advanced-btn" id="advanced-btn">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor">
                <path d="M12 5v14M5 12h14" stroke-width="2"/>
              </svg>
            </button>
          </div>
        </div>
        
        <!-- Advanced Options Panel -->
        <div class="advanced-panel" id="advanced-panel">
          <div class="advanced-header">
            <h4>Options avancées</h4>
            <button class="close-advanced" id="close-advanced">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor">
                <path d="M18 6L6 18M6 6l12 12" stroke-width="2"/>
              </svg>
            </button>
          </div>
          
          <div class="advanced-section">
            <h5>Ton & Style</h5>
            <div class="tone-chips">
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
          
          <div class="advanced-section">
            <h5>Suggestions rapides</h5>
            <div class="quick-suggestions">
              <button class="suggestion-btn">Romans français contemporains</button>
              <button class="suggestion-btn">Science-fiction optimiste</button>
              <button class="suggestion-btn">Thrillers psychologiques</button>
              <button class="suggestion-btn">Philosophie accessible</button>
              <button class="suggestion-btn">Histoire passionnante</button>
            </div>
          </div>
          
          <div class="advanced-section">
            <h5>Préférences</h5>
            <div class="preference-item">
              <label>Utiliser mon historique de lecture</label>
              <label class="toggle-switch">
                <input type="checkbox" id="include-history" />
                <span class="toggle-slider"></span>
              </label>
            </div>
          </div>
        </div>
        
        <!-- Settings Side Panel -->
        <div class="settings-panel" id="settings-panel">
          <div class="settings-overlay" id="settings-overlay"></div>
          <div class="settings-content">
            <div class="settings-header">
              <h3>Paramètres</h3>
              <button class="close-settings" id="close-settings">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor">
                  <path d="M18 6L6 18M6 6l12 12" stroke-width="2"/>
                </svg>
              </button>
            </div>
            
            <div class="settings-section">
              <h4>Compte</h4>
              <div class="auth-buttons">
                <button class="auth-btn signin-btn">
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor">
                    <path d="M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4M10 17l5-5-5-5M13.8 12H3" stroke-width="2"/>
                  </svg>
                  Se connecter
                </button>
                <button class="auth-btn signup-btn">
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor">
                    <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2M12 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8Z" stroke-width="2"/>
                  </svg>
                  S'inscrire
                </button>
              </div>
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
    
    // Advanced panel
    const advancedBtn = document.getElementById('advanced-btn');
    const advancedPanel = document.getElementById('advanced-panel');
    const closeAdvanced = document.getElementById('close-advanced');
    
    advancedBtn.addEventListener('click', () => this.toggleAdvanced());
    closeAdvanced.addEventListener('click', () => this.closeAdvanced());
    
    // Settings panel
    const settingsBtn = document.getElementById('settings-btn');
    const settingsPanel = document.getElementById('settings-panel');
    const settingsOverlay = document.getElementById('settings-overlay');
    const closeSettings = document.getElementById('close-settings');
    
    settingsBtn.addEventListener('click', () => this.openSettings());
    settingsOverlay.addEventListener('click', () => this.closeSettings());
    closeSettings.addEventListener('click', () => this.closeSettings());
    
    // Quick suggestions in advanced panel
    document.querySelectorAll('.suggestion-btn').forEach(btn => {
      btn.addEventListener('click', (e) => {
        input.value = e.target.textContent;
        this.closeAdvanced();
        input.focus();
      });
    });
    
    // Tone chips in advanced panel
    document.querySelectorAll('.tone-chip').forEach(chip => {
      chip.addEventListener('click', (e) => {
        this.toggleToneChip(e.target);
      });
    });
    
    // Delegate book actions
    document.addEventListener('click', (e) => {
      if (e.target.closest('.action-btn')) {
        const btn = e.target.closest('.action-btn');
        const action = btn.dataset.action;
        const bookTitle = btn.dataset.book;
        this.handleBookAction(action, bookTitle);
      }
    });
  }
  
  toggleAdvanced() {
    if (this.isAdvancedOpen) {
      this.closeAdvanced();
    } else {
      this.openAdvanced();
    }
  }
  
  openAdvanced() {
    this.isAdvancedOpen = true;
    document.getElementById('advanced-panel').classList.add('open');
    document.getElementById('advanced-btn').innerHTML = `
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor">
        <path d="M18 6L6 18M6 6l12 12" stroke-width="2"/>
      </svg>
    `;
  }
  
  closeAdvanced() {
    this.isAdvancedOpen = false;
    document.getElementById('advanced-panel').classList.remove('open');
    document.getElementById('advanced-btn').innerHTML = `
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor">
        <path d="M12 5v14M5 12h14" stroke-width="2"/>
      </svg>
    `;
  }
  
  openSettings() {
    this.isSettingsOpen = true;
    document.getElementById('settings-panel').classList.add('open');
    document.body.style.overflow = 'hidden';
  }
  
  closeSettings() {
    this.isSettingsOpen = false;
    document.getElementById('settings-panel').classList.remove('open');
    document.body.style.overflow = '';
  }
  
  toggleToneChip(chip) {
    chip.classList.toggle('active');
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
      content: "Salut ! 👋 Dis-moi ce que tu veux lire aujourd'hui.",
      timestamp: new Date()
    });
    
    this.updateButtonText();
  }
  
  addMessage(message) {
    this.messages.push(message);
    this.renderMessages();
    this.scrollToBottom();
    
    if (message.type === 'ai' && message.suggestions && message.suggestions.length > 0 && !this.hasFirstResults) {
      this.hasFirstResults = true;
      this.updateButtonText();
    }
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
    
    this.addMessage({
      type: 'user',
      content: message,
      timestamp: new Date()
    });
    
    input.value = '';
    input.style.height = 'auto';
    
    this.showTypingIndicator();
    
    try {
      const selectedTones = this.getSelectedTones();
      const includeHistory = document.getElementById('include-history')?.checked || false;
      
      const requestData = {
        context: message,
        tone_chips: selectedTones,
        include_history: includeHistory,
        user_feedback: this.userFeedback
      };
      
      const response = await fetch('/recommendations/chat_message', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || ''
        },
        body: JSON.stringify(requestData)
      });
      
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      
      const data = await response.json();
      
      this.addMessage({
        type: 'ai',
        content: data.message || data.ai_response || "Voici mes suggestions basées sur ta demande :",
        suggestions: data.suggestions || data.parsed_response?.picks || [],
        timestamp: new Date()
      });
      
      this.currentContext = message;
      
    } catch (error) {
      console.error('Error calling AI API:', error);
      
      const mockResponse = this.generateMockResponse(message);
      this.addMessage({
        type: 'ai',
        content: `Erreur de connexion à l'IA. Voici des suggestions basées sur ta demande : ${mockResponse.message}`,
        suggestions: mockResponse.suggestions,
        timestamp: new Date()
      });
    }
    
    this.hideTypingIndicator();
  }
  
  generateMockResponse(userMessage) {
    const lowerMessage = userMessage.toLowerCase();
    const selectedTones = this.getSelectedTones();
    
    if (this.userFeedback && Object.keys(this.userFeedback).length > 0) {
      return this.generateRefinedResponse();
    }
    
    let toneContext = '';
    if (selectedTones.length > 0) {
      toneContext = ` (avec un ton ${selectedTones.join(', ')})`;
    }
    
    if (lowerMessage.includes('roman') || lowerMessage.includes('fiction')) {
      return {
        message: `Parfait ! Voici mes suggestions de romans basées sur ta demande${toneContext} :`,
        suggestions: [
          {
            title: "Le Petit Prince",
            author: "Antoine de Saint-Exupéry",
            pitch: "Un conte poétique et philosophique sur l'amour et l'amitié, parfait pour tous les âges."
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
    } else {
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
  
  updateButtonText() {
    const btn = document.getElementById('send-btn');
    const btnText = btn.querySelector('.btn-text');
    
    if (!this.hasFirstResults) {
      btnText.textContent = 'Get suggestions';
      btn.classList.remove('refine-btn');
      btn.classList.add('primary-btn');
    } else {
      btnText.textContent = 'More like this';
      btn.classList.remove('primary-btn');
      btn.classList.add('refine-btn');
    }
  }

  handleBookAction(action, bookTitle) {
    console.log(`Action ${action} sur le livre: ${bookTitle}`);
    
    const btn = document.querySelector(`[data-action="${action}"][data-book="${bookTitle}"]`);
    if (btn) {
      const originalHTML = btn.innerHTML;
      
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
      
      setTimeout(() => {
        btn.style.background = '';
        btn.style.color = '';
        btn.innerHTML = originalHTML;
      }, 2000);
    }
    
    if (!this.userFeedback) this.userFeedback = {};
    if (!this.userFeedback[bookTitle]) this.userFeedback[bookTitle] = {};
    this.userFeedback[bookTitle][action] = true;
    
    const messages = {
      like: `J'ai noté que tu aimes "${bookTitle}" !`,
      dislike: `J'ai noté que "${bookTitle}" ne t'intéresse pas.`,
      message: `"${bookTitle}" a été ajouté à ta liste de lecture !`
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
